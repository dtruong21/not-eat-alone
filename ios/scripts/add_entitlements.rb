#!/usr/bin/env ruby
# frozen_string_literal: true

# Wires ios/Runner/Runner.entitlements (Sign in with Apple capability) onto
# every build configuration of the Runner target in ios/Runner.xcodeproj, via
# the `xcodeproj` gem (no manual Xcode GUI edits).
#
# This is purely structural: it lets `CODE_SIGN_ENTITLEMENTS` point at the
# entitlements file for every existing configuration (base Debug/Release/
# Profile plus any flavor configs setup_flavors.rb already created, e.g.
# Debug-stage/Debug-prod/...). The actual Sign in with Apple capability is
# only meaningful once the Apple provider + associated App ID capability are
# enabled in the Apple Developer portal -- that's separate, later work. Until
# then this setting is inert.
#
# Usage:
#   gem install xcodeproj   # if not already installed
#   ruby ios/scripts/add_entitlements.rb
#
# Re-running is safe/idempotent: it just (re)sets the same build setting.

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'Runner.xcodeproj')
ENTITLEMENTS_RELATIVE_PATH = 'Runner/Runner.entitlements'

project = Xcodeproj::Project.open(PROJECT_PATH)

runner_target = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found in Runner.xcodeproj' unless runner_target

config_list = runner_target.build_configuration_list
config_list.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = ENTITLEMENTS_RELATIVE_PATH
end

project.save
puts "[add_entitlements] CODE_SIGN_ENTITLEMENTS=#{ENTITLEMENTS_RELATIVE_PATH} set on " \
     "#{config_list.build_configurations.size} Runner configuration(s)."
