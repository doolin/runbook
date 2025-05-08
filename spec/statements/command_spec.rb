require "spec_helper"

RSpec.describe Runbook::Statements::Command do
  let(:cmd) { "echo 'hi'" }
  let(:ssh_config) {
    {
      servers: ["server1.prod"],
      parallelization: {
        strategy: :groups,
        limit: 2,
        wait: 2,
      },
      path: "/home/bobby_mcgee",
      user: "bobby_mcgee",
      group: "bobby_mcgee",
      env: {rails_env: "production"},
      umask: "077",
    }
  }
  let(:raw) { true }
  let(:book) { Runbook::Entities::Book.new("My Book") }
  let(:parent) { Runbook::Entities::Step.new("My Step").tap { |step| step.parent = book } }
  let(:command) {
    Runbook::Statements::Command.new(
      cmd,
      ssh_config: ssh_config,
      raw: raw,
    ).tap { |cmd| cmd.parent = parent }
  }
  let(:toolbox) { instance_double("Runbook::Toolbox") }
  let(:metadata) {
    {
      noop: false,
      auto: false,
      paranoid: true,
      start_at: "0",
      toolbox: toolbox,
      layout_panes: {},
      depth: 1,
      index: 0,
      parent: nil,
      position: "",
      reverse: Runbook::Util::Glue.new(false),
      reversed: Runbook::Util::Glue.new(false),
      book_title: "My Book",
    }
  }

  it "has a command" do
    expect(command.cmd).to eq(cmd)
  end

  it "has an ssh_config" do
    expect(command.ssh_config).to eq(ssh_config)
  end

  it "has a raw param" do
    expect(command.raw).to eq(raw)
  end

  describe "default_values" do
    let(:command) { Runbook::Statements::Command.new(cmd) }
    it "sets defaults for ssh_config" do
      expect(command.ssh_config).to be_nil
    end

    it "sets defaults for raw" do
      expect(command.raw).to be_falsey
    end
  end

  describe "execution behavior" do
    subject { Class.new { include Runbook::Run } }

    before(:each) do
      allow(toolbox).to receive(:output)
    end

    context "when dynamic and visited" do
      before do
        command.dynamic!
        command.visited!
      end

      it "skips execution" do
        expect(subject).not_to receive(:runbook__statements__command)
        command.run(subject, metadata)
      end
    end

    context "when not dynamic or not visited" do
      it "executes normally" do
        expect(subject).to receive(:runbook__statements__command).with(command, metadata)
        command.run(subject, metadata)
        expect(command.visited?).to be true
      end
    end
  end
end
