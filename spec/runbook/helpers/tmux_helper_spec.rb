require 'spec_helper'

RSpec.describe Runbook::Helpers::TmuxHelper do
  let(:helper) { Class.new { include Runbook::Helpers::TmuxHelper }.new }

  describe '#_runbook_pane' do
    it 'returns the current pane id' do
      # Setup
      allow(helper).to receive(:`).with('tmux display-message -p \'#D\'').and_return("1\n")

      # Exercise
      result = helper._runbook_pane

      # Verify
      expect(result).to eq('1')
    end

    it 'memoizes the result' do
      # Setup
      allow(helper).to receive(:`).with('tmux display-message -p \'#D\'').and_return("1\n")

      # Exercise
      first_call = helper._runbook_pane
      second_call = helper._runbook_pane

      # Verify
      expect(helper).to have_received(:`).once
      expect(first_call).to eq(second_call)
    end
  end

  describe '#_rename_window' do
    it 'renames the current window' do
      # Setup
      window_name = 'test_window'
      allow(helper).to receive(:`)

      # Exercise
      helper._rename_window(window_name)

      # Verify
      expect(helper).to have_received(:`).with("tmux rename-window \"#{window_name}\"")
    end

    it 'handles window names with spaces' do
      # Setup
      window_name = 'test window with spaces'
      allow(helper).to receive(:`)

      # Exercise
      helper._rename_window(window_name)

      # Verify
      expect(helper).to have_received(:`).with("tmux rename-window \"#{window_name}\"")
    end
  end

  describe '#_split' do
    let(:current_pane) { '1' }
    let(:size) { 50 }

    it 'splits horizontally on even depth' do
      # Setup
      depth = 0
      expected_command = "tmux split-window -h -t #{current_pane} -p #{size} -P -F '#D' -d"
      allow(helper).to receive(:`).with(expected_command).and_return("2\n")

      # Exercise
      result = helper._split(current_pane, depth, size)

      # Verify
      expect(result).to eq('2')
      expect(helper).to have_received(:`).with(expected_command)
    end

    it 'splits vertically on odd depth' do
      # Setup
      depth = 1
      expected_command = "tmux split-window -v -t #{current_pane} -p #{size} -P -F '#D' -d"
      allow(helper).to receive(:`).with(expected_command).and_return("3\n")

      # Exercise
      result = helper._split(current_pane, depth, size)

      # Verify
      expect(result).to eq('3')
      expect(helper).to have_received(:`).with(expected_command)
    end
  end

  describe '#_swap_panes' do
    it 'swaps two panes' do
      # Setup
      source = '1'
      target = '2'
      expected_command = "tmux swap-pane -d -t #{source} -s #{target}"
      allow(helper).to receive(:`)

      # Exercise
      helper._swap_panes(source, target)

      # Verify
      expect(helper).to have_received(:`).with(expected_command)
    end

    it 'handles pane ids with special characters' do
      # Setup
      source = '%1'
      target = '%2'
      expected_command = "tmux swap-pane -d -t #{source} -s #{target}"
      allow(helper).to receive(:`)

      # Exercise
      helper._swap_panes(source, target)

      # Verify
      expect(helper).to have_received(:`).with(expected_command)
    end
  end

  describe '#_set_directory' do
    it 'sends cd command to the specified pane' do
      # Setup
      pane = '1'
      directory = '/tmp/test'
      allow(helper).to receive(:send_keys)

      # Exercise
      helper._set_directory(directory, pane)

      # Verify
      expect(helper).to have_received(:send_keys).with("cd #{directory}; clear", pane)
    end

    it 'handles directories with spaces' do
      # Setup
      pane = '1'
      directory = '/tmp/test dir'
      allow(helper).to receive(:send_keys)

      # Exercise
      helper._set_directory(directory, pane)

      # Verify
      expect(helper).to have_received(:send_keys).with("cd #{directory}; clear", pane)
    end
  end

  describe '#_new_window' do
    it 'creates a new window and returns its id' do
      # Setup
      window_name = 'test_window'
      expected_command = "tmux new-window -n \"#{window_name}\" -P -F '#D' -d"
      allow(helper).to receive(:`).with(expected_command).and_return("2\n")

      # Exercise
      result = helper._new_window(window_name)

      # Verify
      expect(result).to eq('2')
    end

    it 'handles window names with spaces' do
      # Setup
      window_name = 'test window with spaces'
      expected_command = "tmux new-window -n \"#{window_name}\" -P -F '#D' -d"
      allow(helper).to receive(:`).with(expected_command).and_return("2\n")

      # Exercise
      result = helper._new_window(window_name)

      # Verify
      expect(result).to eq('2')
    end
  end

  describe '#_pager_escape_sequence' do
    it 'returns the correct escape sequence' do
      # Exercise
      result = helper._pager_escape_sequence

      # Verify
      expect(result).to eq('q C-u')
    end
  end

  describe '#_kill_pane' do
    it 'kills the specified pane' do
      # Setup
      pane = '1'
      expected_command = "tmux kill-pane -t #{pane}"
      allow(helper).to receive(:`)

      # Exercise
      helper._kill_pane(pane)

      # Verify
      expect(helper).to have_received(:`).with(expected_command)
    end

    it 'handles pane ids with special characters' do
      # Setup
      pane = '%1'
      expected_command = "tmux kill-pane -t #{pane}"
      allow(helper).to receive(:`)

      # Exercise
      helper._kill_pane(pane)

      # Verify
      expect(helper).to have_received(:`).with(expected_command)
    end
  end

  describe '#_slug' do
    it 'converts spaces to hyphens' do
      # Exercise
      result = helper._slug('Hello World')

      # Verify
      expect(result).to eq('hello-world')
    end

    it 'preserves special characters' do
      # Exercise
      result = helper._slug('Test!@#$%^&*()File')

      # Verify
      expect(result).to eq('test!@#$%^&*()file')
    end

    it 'converts multiple spaces to single hyphen' do
      # Exercise
      result = helper._slug('  Test    File  ')

      # Verify
      expect(result).to eq('test-file')
    end

    it 'downcases and adds hyphens between words' do
      # Exercise
      result = helper._slug('TestFILE')

      # Verify
      expect(result).to eq('test-file')
    end
  end

  describe '#_layout_file' do
    let(:runbook_title) { 'My Test Runbook' }
    let(:tmpdir) { '/tmp' }
    let(:expected_file) { "#{tmpdir}/runbook_layout_12345_test-session_67890_%1_#{runbook_title}.yml" }

    before do
      allow(Dir).to receive(:tmpdir).and_return(tmpdir)
      allow(helper).to receive(:`).with(/tmux display-message/).and_return(expected_file)
    end

    it 'returns the layout file path' do
      # Exercise
      result = helper._layout_file(runbook_title)

      # Verify
      expect(result).to eq(expected_file)
    end

    it 'calls tmux display-message with the correct format' do
      # We need to match the exact string that will be passed to the shell
      # The implementation uses Ruby string interpolation which results in literal #{var} in the shell command
      expect(helper).to receive(:`).with(
        a_string_matching(%r{^tmux display-message -p -t \$TMUX_PANE "#{Regexp.escape(tmpdir)}/runbook_layout_\#{pid}_\#{session_name}_\#{pane_pid}_\#{pane_id}_#{Regexp.escape(runbook_title)}\.yml"$})
      ).and_return(expected_file)
      helper._layout_file(runbook_title)
    end

    it 'handles runbook titles with special characters' do
      # Setup
      special_title = 'Test!@#$%^&*() Runbook'
      special_expected_file = "#{tmpdir}/runbook_layout_12345_test-session_67890_%1_#{special_title}.yml"
      allow(helper).to receive(:`).with(/tmux display-message/).and_return(special_expected_file)

      # Exercise
      result = helper._layout_file(special_title)

      # Verify
      expect(result).to eq(special_expected_file)
    end
  end
end
