require 'spec_helper'

RSpec.describe Runbook::Generators::Project do
  describe '#shared_lib_dir' do
    it 'uses the shared-lib-dir option when provided' do
      custom_dir = 'lib/custom/path'
      generator = described_class.new(['test_project'], { 'shared-lib-dir' => custom_dir })
      generator.shared_lib_dir
      expect(generator.instance_variable_get(:@shared_lib_dir)).to eq(custom_dir)
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
end
