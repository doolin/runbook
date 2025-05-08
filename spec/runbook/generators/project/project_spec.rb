require 'spec_helper'

RSpec.describe Runbook::Generators::Project do
  describe '#shared_lib_dir' do
    context 'when shared-lib-dir option is provided' do
      it 'uses the shared-lib-dir option' do
        generator = described_class.new(['my_runbooks'], { 'shared-lib-dir' => 'custom_lib' })
        expect(generator.shared_lib_dir).to eq('custom_lib')
      end
    end

    context 'when shared-lib-dir option is not provided' do
      it 'prompts the user for the shared lib directory' do
        # Setup
        generator = described_class.new(['my_runbooks'])
        expected_msg = [
          'Where should shared runbook code live?',
          'Use `lib/my_runbooks` for runbook-only projects',
          'Use `lib/my_runbooks/runbook` for projects used for non-runbook tasks',
          'Shared runbook code path:'
        ].join("\n")
        allow(generator).to receive(:ask).and_return('lib/my_runbooks')

        # Exercise
        result = generator.shared_lib_dir

        # Verify
        expect(generator).to have_received(:ask).with(expected_msg)
        expect(result).to eq('lib/my_runbooks')
      end
    end
  end

  describe '.description' do
    it 'returns the generator description' do
      expect(described_class.description).to eq('Generate a project for your runbooks')
    end
  end

  describe '.long_description' do
    it 'returns a detailed description of the generator' do
      expected = <<-LONG_DESC.strip
      This generator generates a project for your runbooks. It creates a
      project skeleton to hold your runbooks, runbook extensions, shared
      code, configuration, tests, and dependencies.
      LONG_DESC
      expect(described_class.long_description.strip).to eq(expected)
    end
  end

  describe '.class_options' do
    it 'defines the expected options' do
      options = described_class.class_options

      # Check for presence of key options
      expect(options.keys).to include(:"shared-lib-dir", :force, :ci, :test)

      # Check specific option properties
      shared_lib_option = options[:"shared-lib-dir"]
      expect(shared_lib_option.type).to eq(:string)
      expect(shared_lib_option.description).to eq('Target directory for shared runbook code')

      force_option = options[:force]
      expect(force_option.type).to eq(:boolean)
      expect(force_option.description).to eq('Overwrite files that already exist')
    end
  end

  describe '#create_readme' do
    it 'creates a README.md with the correct content' do
      # Setup
      generator = described_class.new(['my_runbooks'], { 'shared-lib-dir' => 'lib/my_runbooks' })
      allow(generator).to receive(:template)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.create_readme

      # Verify
      expect(generator).to have_received(:template).with(
        'templates/README.md.tt',
        File.join('.', 'my_runbooks', 'README.md')
      )
    end
  end

  describe '#create_gemfile' do
    it 'creates a Gemfile with template and appends dependencies' do
      # Setup
      generator = described_class.new(['my_runbooks'], { 'shared-lib-dir' => 'lib/my_runbooks' })
      allow(generator).to receive(:template)
      allow(generator).to receive(:append_to_file)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Mock gemspec and gemfile contents
      generator.instance_variable_set(:@gemspec_file_contents, [
                                        "  spec.add_development_dependency 'rspec', '~> 3.0'\n",
                                        "  spec.add_development_dependency 'rubocop', '~> 1.0'\n"
                                      ])
      generator.instance_variable_set(:@gemfile_file_contents, [
                                        "gem 'rake', '~> 13.0'\n",
                                        "gem 'runbook', '~> 2.0'\n"
                                      ])

      # Exercise
      generator.create_gemfile

      # Verify template creation
      expect(generator).to have_received(:template).with(
        'templates/Gemfile.tt',
        File.join('.', 'my_runbooks', 'Gemfile')
      )

      # Verify development dependencies are appended
      expect(generator).to have_received(:append_to_file).with(
        File.join('.', 'my_runbooks', 'Gemfile'),
        "\ngem 'rspec', '~> 3.0'\ngem 'rubocop', '~> 1.0'\n",
        verbose: false
      )

      # Verify gemfile gems are appended
      expect(generator).to have_received(:append_to_file).with(
        File.join('.', 'my_runbooks', 'Gemfile'),
        "\ngem 'rake', '~> 13.0'\ngem 'runbook', '~> 2.0'\n",
        verbose: false
      )
    end

    it 'creates a Gemfile with just template when no dependencies exist' do
      # Setup
      generator = described_class.new(['my_runbooks'], { 'shared-lib-dir' => 'lib/my_runbooks' })
      allow(generator).to receive(:template)
      allow(generator).to receive(:append_to_file)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.create_gemfile

      # Verify template creation
      expect(generator).to have_received(:template).with(
        'templates/Gemfile.tt',
        File.join('.', 'my_runbooks', 'Gemfile')
      )

      # Verify no dependencies are appended
      expect(generator).not_to have_received(:append_to_file)
    end
  end

  describe '#remove_unneeded_files' do
    let(:generator) { described_class.new(['my_runbooks']) }
    let(:root_dir) { '.' }

    before do
      allow(generator).to receive(:parent_options).and_return({ root: root_dir })
      allow(generator).to receive(:remove_file)
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:readlines).and_return([])
    end

    it 'removes all unneeded files' do
      # Exercise
      generator.remove_unneeded_files

      # Verify each file is removed
      expect(generator).to have_received(:remove_file).with(
        File.join(root_dir, 'my_runbooks', 'my_runbooks.gemspec')
      )
      expect(generator).to have_received(:remove_file).with(
        File.join(root_dir, 'my_runbooks', 'README.md')
      )
      expect(generator).to have_received(:remove_file).with(
        File.join(root_dir, 'my_runbooks', 'Gemfile')
      )
      expect(generator).to have_received(:remove_file).with(
        File.join(root_dir, 'my_runbooks', 'lib', 'my_runbooks.rb')
      )
      expect(generator).to have_received(:remove_file).with(
        File.join(root_dir, 'my_runbooks', 'lib', 'my_runbooks', 'version.rb')
      )
    end

    it 'extracts content from existing files before removal' do
      # Setup - simulate existing files
      allow(File).to receive(:exist?).and_return(true)
      gemspec_contents = [
        "  spec.add_development_dependency 'rspec'\n",
        "  spec.add_development_dependency 'rubocop'\n"
      ]
      gemfile_contents = [
        "gem 'rake'\n",
        "gem 'runbook'\n"
      ]
      allow(File).to receive(:readlines)
        .with(File.join(root_dir, 'my_runbooks', 'my_runbooks.gemspec'))
        .and_return(gemspec_contents)
      allow(File).to receive(:readlines)
        .with(File.join(root_dir, 'my_runbooks', 'Gemfile'))
        .and_return(gemfile_contents)

      # Exercise
      generator.remove_unneeded_files

      # Verify contents were extracted
      expect(generator.instance_variable_get(:@gemspec_file_contents)).to eq(gemspec_contents)
      expect(generator.instance_variable_get(:@gemfile_file_contents)).to eq(gemfile_contents)
    end
  end

  describe '#create_runbookfile' do
    it 'creates a Runbookfile with the correct template' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:template)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.create_runbookfile

      # Verify
      expect(generator).to have_received(:template).with(
        'templates/Runbookfile.tt',
        File.join('.', 'my_runbooks', 'Runbookfile')
      )
    end
  end

  describe '#create_runbooks_directory' do
    it 'creates the runbooks directory and adds a .keep file' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:empty_directory)
      allow(generator).to receive(:_keep_dir)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.create_runbooks_directory

      # Verify directory creation
      expect(generator).to have_received(:empty_directory).with(
        File.join('.', 'my_runbooks', 'runbooks')
      )

      # Verify .keep file creation
      expect(generator).to have_received(:_keep_dir).with(
        File.join('.', 'my_runbooks', 'runbooks')
      )
    end
  end

  describe '#create_extensions_directory' do
    it 'creates the extensions directory and adds a .keep file' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:empty_directory)
      allow(generator).to receive(:_keep_dir)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.create_extensions_directory

      # Verify directory creation
      expect(generator).to have_received(:empty_directory).with(
        File.join('.', 'my_runbooks', 'lib', 'runbook', 'extensions')
      )

      # Verify .keep file creation
      expect(generator).to have_received(:_keep_dir).with(
        File.join('.', 'my_runbooks', 'lib', 'runbook', 'extensions')
      )
    end
  end

  describe '#create_generators_directory' do
    it 'creates the generators directory and adds a .keep file' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:empty_directory)
      allow(generator).to receive(:_keep_dir)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.create_generators_directory

      # Verify directory creation
      expect(generator).to have_received(:empty_directory).with(
        File.join('.', 'my_runbooks', 'lib', 'runbook', 'generators')
      )

      # Verify .keep file creation
      expect(generator).to have_received(:_keep_dir).with(
        File.join('.', 'my_runbooks', 'lib', 'runbook', 'generators')
      )
    end
  end

  describe '#create_lib_directory' do
    it 'creates the lib directory structure' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:empty_directory)
      allow(generator).to receive(:_keep_dir)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })
      generator.instance_variable_set(:@shared_lib_dir, 'lib/my_runbooks')

      # Exercise
      generator.create_lib_directory

      # Verify directory creation
      expect(generator).to have_received(:empty_directory).with(
        File.join('.', 'my_runbooks', 'lib/my_runbooks')
      )
      expect(generator).to have_received(:_keep_dir).with(
        File.join('.', 'my_runbooks', 'lib/my_runbooks')
      )
    end
  end

  describe '#create_ruby_version' do
    it 'creates a .ruby-version file with the current Ruby version' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:create_file)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.create_ruby_version

      # Verify file creation
      expect(generator).to have_received(:create_file).with(
        File.join('.', 'my_runbooks', '.ruby-version'),
        "ruby-#{RUBY_VERSION}\n"
      )
    end
  end

  describe '#create_ruby_gemset' do
    it 'creates a .ruby-gemset file with the project name' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:create_file)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.create_ruby_gemset

      # Verify file creation
      expect(generator).to have_received(:create_file).with(
        File.join('.', 'my_runbooks', '.ruby-gemset'),
        "my_runbooks\n"
      )
    end
  end

  describe '#update_bin_console' do
    it 'updates the console script with project configuration' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:gsub_file)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.update_bin_console

      # Verify file modification
      expect(generator).to have_received(:gsub_file).with(
        File.join('.', 'my_runbooks', 'bin', 'console'),
        /require "my_runbooks"/,
        %(require_relative "../lib/my_runbooks"\n\nRunbook::Configuration.load_config),
        verbose: false
      )
    end
  end

  describe '#remove_bad_test' do
    let(:generator) { described_class.new(['my_runbooks']) }
    let(:root_dir) { '.' }

    before do
      allow(generator).to receive(:gsub_file)
      allow(generator).to receive(:parent_options).and_return({ root: root_dir })
    end

    context 'with rspec' do
      it 'removes the version test from the spec file' do
        # Setup
        generator = described_class.new(['my_runbooks'], { 'test' => 'rspec' })
        allow(generator).to receive(:gsub_file)
        allow(generator).to receive(:parent_options).and_return({ root: root_dir })
        allow(generator).to receive(:_name).and_return('my_runbooks')

        # Exercise
        generator.remove_bad_test

        # Verify file modification
        expect(generator).to have_received(:gsub_file).with(
          File.join(root_dir, 'my_runbooks', 'spec', 'my_runbooks_spec.rb'),
          /  .*version.*\n.*\n  end\n\n/m,
          '',
          verbose: false
        )
      end
    end

    context 'with minitest' do
      it 'removes the version test from the test file' do
        # Setup
        generator = described_class.new(['my_runbooks'], { 'test' => 'minitest' })
        allow(generator).to receive(:gsub_file)
        allow(generator).to receive(:parent_options).and_return({ root: root_dir })
        allow(generator).to receive(:_name).and_return('my_runbooks')

        # Exercise
        generator.remove_bad_test

        # Verify file modification
        expect(generator).to have_received(:gsub_file).with(
          File.join(root_dir, 'my_runbooks', 'test', 'my_runbooks_test.rb'),
          /  .*version.*\n.*\n  end\n\n/m,
          '',
          verbose: false
        )
      end
    end

    context 'with invalid test option' do
      it 'raises an error' do
        # Setup
        generator = described_class.new(['my_runbooks'], { 'test' => 'invalid' })
        allow(generator).to receive(:parent_options).and_return({ root: root_dir })
        allow(generator).to receive(:_name).and_return('my_runbooks')

        # Exercise and Verify
        expect { generator.remove_bad_test }.to raise_error(
          RuntimeError,
          'Invalid test option: invalid'
        )
      end
    end

    context 'with no test option' do
      it 'defaults to rspec' do
        # Setup
        generator = described_class.new(['my_runbooks'])
        allow(generator).to receive(:gsub_file)
        allow(generator).to receive(:parent_options).and_return({ root: root_dir })
        allow(generator).to receive(:_name).and_return('my_runbooks')

        # Exercise
        generator.remove_bad_test

        # Verify file modification
        expect(generator).to have_received(:gsub_file).with(
          File.join(root_dir, 'my_runbooks', 'spec', 'my_runbooks_spec.rb'),
          /  .*version.*\n.*\n  end\n\n/m,
          '',
          verbose: false
        )
      end
    end
  end

  describe '#_keep_dir', :private do
    it 'creates a .keep file in the specified directory' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:create_file)
      test_dir = '/path/to/test/dir'

      # Exercise - call private method
      generator.send(:_keep_dir, test_dir)

      # Verify file creation
      expect(generator).to have_received(:create_file).with(
        File.join(test_dir, '.keep'),
        verbose: false
      )
    end
  end

  describe '#init_gem' do
    let(:generator) { described_class.new(['my_runbooks'], { 'test' => 'rspec', 'ci' => 'github' }) }

    before do
      allow(generator).to receive(:system).and_return(true)
      allow(generator).to receive(:run).and_return(true)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })
      allow(generator).to receive(:inside).and_yield
    end

    context 'when bundler is not installed' do
      before do
        allow(generator).to receive(:system).with('which bundle 2>&1 1>/dev/null').and_return(false)
      end

      it 'raises an error' do
        expect { generator.init_gem }.to raise_error('Please ensure bundle is installed')
      end
    end

    context 'when bundler is installed' do
      before do
        allow(generator).to receive(:system).with('which bundle 2>&1 1>/dev/null').and_return(true)
      end

      context 'with bundler version >= 2.2.8' do
        before do
          stub_const('Bundler::VERSION', '2.2.8')
        end

        it 'runs bundle gem with the no-changelog option' do
          generator.init_gem
          expect(generator).to have_received(:run).with(
            'bundle gem my_runbooks --test rspec --ci github --rubocop --no-changelog --no-coc --no-mit'
          )
        end
      end

      context 'with bundler version < 2.2.8' do
        before do
          stub_const('Bundler::VERSION', '2.2.7')
        end

        it 'runs bundle gem without the no-changelog option' do
          generator.init_gem
          expect(generator).to have_received(:run).with(
            'bundle gem my_runbooks --test rspec --ci github --rubocop  --no-coc --no-mit'
          )
        end
      end

      context 'when bundle gem fails' do
        before do
          allow(generator).to receive(:run).and_return(false)
          allow(generator).to receive(:exit)
        end

        it 'exits with status 1' do
          generator.init_gem
          expect(generator).to have_received(:exit).with(1)
        end
      end
    end
  end

  describe '#create_base_file' do
    it 'creates the main Ruby file with the correct template' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:template)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.create_base_file

      # Verify file creation
      expect(generator).to have_received(:template).with(
        'templates/base_file.rb.tt',
        File.join('.', 'my_runbooks', 'lib', 'my_runbooks.rb')
      )
    end
  end

  describe '#modify_rakefile' do
    it 'removes the bundler gem tasks line from the Rakefile' do
      # Setup
      generator = described_class.new(['my_runbooks'])
      allow(generator).to receive(:gsub_file)
      allow(generator).to receive(:parent_options).and_return({ root: '.' })

      # Exercise
      generator.modify_rakefile

      # Verify file modification
      expect(generator).to have_received(:gsub_file).with(
        File.join('.', 'my_runbooks', 'Rakefile'),
        %r{^require "bundler/gem_tasks"\n},
        '',
        verbose: false
      )
    end
  end

  describe '#runbook_project_overview' do
    let(:generator) { described_class.new(['my_runbooks']) }
    let(:root_dir) { '.' }

    before do
      allow(generator).to receive(:say)
      allow(generator).to receive(:parent_options).and_return({ root: root_dir })
    end

    it 'displays project creation success message' do
      # Setup
      generator.instance_variable_set(:@shared_lib_dir, 'lib/my_runbooks')
      expected_msg = [
        '',
        'Your runbook project was successfully created.',
        'Remember to run `./bin/setup` in your project to install dependencies.',
        'Add runbooks to the `runbooks` directory.',
        'Add shared code to `lib/my_runbooks`.',
        'Execute runbooks using `bundle exec runbook exec <RUNBOOK_PATH>` from your project root.',
        'See the README.md for more details.',
        "\n"
      ].join("\n")

      # Exercise
      generator.runbook_project_overview

      # Verify
      expect(generator).to have_received(:say).with(expected_msg)
    end

    it 'includes custom shared lib directory in message' do
      # Setup
      generator.instance_variable_set(:@shared_lib_dir, 'custom/lib/path')
      expected_msg = [
        '',
        'Your runbook project was successfully created.',
        'Remember to run `./bin/setup` in your project to install dependencies.',
        'Add runbooks to the `runbooks` directory.',
        'Add shared code to `custom/lib/path`.',
        'Execute runbooks using `bundle exec runbook exec <RUNBOOK_PATH>` from your project root.',
        'See the README.md for more details.',
        "\n"
      ].join("\n")

      # Exercise
      generator.runbook_project_overview

      # Verify
      expect(generator).to have_received(:say).with(expected_msg)
    end
  end
end
