require "spec_helper"
require 'securerandom'

RSpec.describe "runbook sshkit integration", type: :aruba do
  let(:config_file) { "runbook_config.rb" }
  let(:config_content) do
    <<-CONFIG
    Runbook.configure do |config|
      config.ssh_kit.use_format :dot
    end
    CONFIG
  end
  let(:runbook_file) { "my_runbook.rb" }
  let(:book_title) { "My Runbook" }
  let(:repo_file) {
    Runbook::Util::Repo._file(book_title)
  }
  let(:stored_pose_file) {
    Runbook::Util::StoredPose._file(book_title)
  }
  let(:user) { ENV["USER"] }
  let(:key_dir) do
    File.join(
      aruba.root_directory,
      aruba.current_directory,
      "ssh_keys"
    )
  end

  # Detect platform and set appropriate Docker platform flag
  let(:docker_platform) do
    host_arch = `uname -m`.strip
    case host_arch
    when "arm64"
      "--platform linux/amd64" # Force AMD64 on ARM Macs for consistency
    else
      "" # No platform flag needed for AMD64/x86_64
    end
  end

  around(:each) do |example|
    ports = "-p 10022:22"
    mount = "-v #{key_dir}/id_rsa.pub:/etc/authorized_keys/$USER"
    users = %Q{-e SSH_USERS="$USER:500:500"}

    begin
      FileUtils.mkdir_p(key_dir)
      key_gen_cmd = "[ -f #{key_dir}/id_rsa ] || ssh-keygen -t rsa -N '' -f #{key_dir}/id_rsa"
      `#{key_gen_cmd}`
      `docker build #{docker_platform} --rm -t sshd:latest -f dockerfiles/Dockerfile-sshd .`
      run_cmd = "docker run -d #{ports} #{mount} #{users} sshd:latest 2>/dev/null"
      @cid = `#{run_cmd}`.strip
      sleep 1
      `docker exec #{@cid} chown root:root /etc/authorized_keys/$USER`
      `docker exec #{@cid} adduser #{user} wheel`
      example.run
    ensure
      `docker stop -t 0 #{@cid}`
      system("docker rm -f #{@cid} 2>&1 1>/dev/null")
    end
  end

  before(:each) { write_file(config_file, config_content) }
  before(:each) { write_file(runbook_file, content) }

  before(:each) do
    FileUtils.rm_f(repo_file)
    FileUtils.rm_f(stored_pose_file)
  end

  before(:each) { run_command(command) }

  describe "sshkit" do
    let(:command) { "runbook exec -P #{runbook_file}" }
    let(:content) do
      <<-RUNBOOK
      SSHKit::Backend::Netssh.configure do |ssh|
        ssh.ssh_options = {
          verify_host_key: :never,
          keys: ["#{key_dir}/id_rsa"],
        }
      end

      Runbook.book "#{book_title}" do
        step do
          server "#{user}@127.0.0.1:10022"

          command "cat /etc/hostname"
        end
      end
      RUNBOOK
    end
    let(:output_lines) {
      [
        /#{@cid[0..11]}/,
      ]
    }

    it "executes remote commands" do
      output_lines.each do |line|
        expect(last_command_started).to have_output(line)
      end
    end

    context "when single quotes are not escaped and user is specified" do
      let(:echo_output) { "I \\$love you" }
      let(:content) do
        <<-RUNBOOK
        SSHKit::Backend::Netssh.configure do |ssh|
          ssh.ssh_options = {
            verify_host_key: :never,
            keys: ["#{key_dir}/id_rsa"],
          }
        end

        Runbook.book "#{book_title}" do
          step do
            server "#{user}@127.0.0.1:10022"
            user "root"

            command "echo '#{echo_output}'"
          end
        end
        RUNBOOK
      end
      let(:output_lines) {
        [
          / #{echo_output}$/,
        ]
      }


      it "does not break the command" do
        output_lines.each do |line|
          expect(last_command_started).to have_output(line)
        end
      end
    end
  end
end

