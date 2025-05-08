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
end
