require 'spec_helper'

RSpec.describe Runbook::Generators::Project do
  describe '#shared_lib_dir' do
    it 'uses the shared-lib-dir option when provided' do
      generator = described_class.new(['my_runbooks'], { 'shared-lib-dir' => 'custom_lib' })
      expect(generator.shared_lib_dir).to eq('custom_lib')
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
end
