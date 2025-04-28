require "aruba/rspec"
require "bundler/setup"
require "debug"
require "runbook"
require "./spec/support/factory"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include Factory

  config.before(:suite) do
    Runbook.configure
  end
end

# Configure Aruba
Aruba.configure do |config|
  config.allow_absolute_paths = true
  config.exit_timeout = 60
  config.io_wait_timeout = 2
  config.startup_wait_time = 2
  config.command_runtime_environment = {
    'BUNDLE_GEMFILE' => nil,
    'RUBYOPT' => nil,
    'RUBY_VERSION' => RUBY_VERSION
  }
end
