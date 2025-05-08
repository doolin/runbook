require 'spec_helper'

RSpec.describe Runbook::Generators::Generator do
  let(:name) { 'acme_runbook' }
  let(:root) { '/tmp/runbook_generators' }
  let(:generator_dir) { File.join(root, name) }
  let(:templates_dir) { File.join(generator_dir, 'templates') }
  let(:generator_file) { File.join(generator_dir, "#{name}.rb") }

  describe 'class methods' do
    describe '.usage' do
      it 'returns the correct usage string' do
        expect(described_class.usage).to eq('generator NAME [options]')
      end
    end

    describe '.description' do
      it 'returns the correct description' do
        expect(described_class.description).to eq('Generate a runbook generator named NAME, e.x. acme_runbook')
      end
    end
  end

  describe 'instance methods' do
    let(:generator) { described_class.new([name]) }

    before(:each) do
      allow(generator).to receive(:parent_options).and_return({ root: root })
      allow(generator).to receive(:empty_directory)
      allow(generator).to receive(:template)
    end

    describe '#create_generator_directory' do
      it 'creates an empty directory for the generator' do
        expect(generator).to receive(:empty_directory).with(generator_dir)
        generator.create_generator_directory
      end
    end

    describe '#create_templates_directory' do
      it 'creates an empty directory for templates' do
        expect(generator).to receive(:empty_directory).with(templates_dir)
        generator.create_templates_directory
      end
    end

    describe '#create_generator' do
      it 'creates the generator file from template' do
        expect(generator).to receive(:template).with(
          'templates/generator.tt',
          generator_file
        )
        generator.create_generator
      end
    end
  end

  describe 'integration' do
    let(:generator) { described_class.new([name]) }

    before(:each) do
      FileUtils.rm_rf(root) if File.exist?(root)
      FileUtils.mkdir_p(root)
      allow(generator).to receive(:parent_options).and_return({ root: root })
    end

    after(:each) do
      FileUtils.rm_rf(root)
    end

    it 'creates all required files and directories' do
      allow(generator).to receive(:template).and_call_original
      allow(generator).to receive(:empty_directory).and_call_original

      generator.create_generator_directory
      generator.create_templates_directory
      generator.create_generator

      expect(File.directory?(generator_dir)).to be true
      expect(File.directory?(templates_dir)).to be true
      expect(File.exist?(generator_file)).to be true
    end
  end
end
