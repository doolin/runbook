require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter "spec"
  add_filter "vendor"
  # add_filter "config"
end
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

  config.include Aruba::Api, type: :aruba

  config.fail_fast = false
end

# Configure Aruba
Aruba.configure do |config|
  config.allow_absolute_paths = true
  config.exit_timeout = 30
  config.io_wait_timeout = 0
  config.startup_wait_time = 0
  config.command_runtime_environment = {
    'BUNDLE_GEMFILE' => nil,
    'RUBYOPT' => nil,
    'RUBY_VERSION' => RUBY_VERSION
  }
end
