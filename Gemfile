source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in runbook.gemspec
gemspec

gem 'base64'
gem 'mutex_m'
gem 'rubocop'

# Audits the locked gems against the Ruby Advisory Database:
#   bundle exec bundle-audit check --update
gem 'bundler-audit', require: false, groups: %i[development test]
