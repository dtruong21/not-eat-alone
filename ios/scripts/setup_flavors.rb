#!/usr/bin/env ruby
# frozen_string_literal: true

# Sets up "stage" and "prod" iOS build flavors for ios/Runner.xcodeproj by
# scripting the Xcode project with the `xcodeproj` gem (no manual Xcode GUI
# edits, no flavor xcconfig files).
#
# What it does:
#   - For the project object, the Runner target, and the RunnerTests target,
#     duplicates each existing Debug/Release/Profile configuration into a
#     "<Base>-stage" and "<Base>-prod" configuration. Each duplicate copies
#     the base configuration's build settings and keeps the SAME
#     base_configuration_reference as the base config, so the
#     Flutter/Pods-generated xcconfig includes stay intact.
#     (RunnerTests gets plain duplicates with no flavor-specific overrides,
#     purely so the project stays internally consistent if the stage/prod
#     schemes' Test action is ever run.)
#   - On every "*-stage" Runner target configuration, sets:
#       PRODUCT_BUNDLE_IDENTIFIER        = com.daki.noteatalone.stage
#       INFOPLIST_KEY_CFBundleDisplayName = not-eat-alone (stage)
#       FLUTTER_TARGET                    = lib/main_stage.dart
#     and the analogous prod values on every "*-prod" configuration.
#   - Writes two SHARED schemes, `stage` and `prod`, under
#     ios/Runner.xcodeproj/xcshareddata/xcschemes/, each wiring
#     Build/Test/Launch/Profile/Analyze/Archive to the Runner (+ RunnerTests)
#     target(s) with the matching per-action configuration:
#       Launch/Run -> Debug-<flavor>
#       Profile    -> Profile-<flavor>
#       Archive    -> Release-<flavor>
#       Test/Analyze -> Debug-<flavor>
#
# Usage:
#   gem install xcodeproj   # if not already installed
#   ruby ios/scripts/setup_flavors.rb
#
# Re-running is safe/idempotent: existing configurations with the target
# name are reused rather than duplicated again, and schemes are overwritten.

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'Runner.xcodeproj')

project = Xcodeproj::Project.open(PROJECT_PATH)

runner_target = project.targets.find { |t| t.name == 'Runner' }
runner_tests_target = project.targets.find { |t| t.name == 'RunnerTests' }
raise 'Runner target not found in Runner.xcodeproj' unless runner_target

BASE_CONFIGS = %w[Debug Release Profile].freeze

FLAVOR_SETTINGS = {
  'stage' => {
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.daki.noteatalone.stage',
    'INFOPLIST_KEY_CFBundleDisplayName' => 'not-eat-alone (stage)',
    'FLUTTER_TARGET' => 'lib/main_stage.dart',
  },
  'prod' => {
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.daki.noteatalone',
    'INFOPLIST_KEY_CFBundleDisplayName' => 'not-eat-alone',
    'FLUTTER_TARGET' => 'lib/main_prod.dart',
  },
}.freeze

# Duplicates `base_config` into a new configuration named `new_name` inside
# `config_list`, copying its build settings and keeping the same
# base_configuration_reference. Returns the existing configuration if one
# with that name is already present (idempotent re-runs).
def duplicate_configuration(project, config_list, base_config, new_name)
  existing = config_list.build_configurations.find { |c| c.name == new_name }
  return existing if existing

  new_config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  new_config.name = new_name
  new_config.build_settings = base_config.build_settings.dup
  new_config.base_configuration_reference = base_config.base_configuration_reference
  config_list.build_configurations << new_config
  new_config
end

[project.root_object, runner_target, runner_tests_target].compact.each do |owner|
  config_list = owner.build_configuration_list

  BASE_CONFIGS.each do |base_name|
    base_config = config_list.build_configurations.find { |c| c.name == base_name }
    next unless base_config

    FLAVOR_SETTINGS.each_key do |flavor|
      new_name = "#{base_name}-#{flavor}"
      new_config = duplicate_configuration(project, config_list, base_config, new_name)

      # Bundle id / display name / Flutter target only make sense on the
      # Runner (app) target, not the project object or the test target.
      next unless owner == runner_target

      FLAVOR_SETTINGS[flavor].each do |key, value|
        new_config.build_settings[key] = value
      end
    end
  end
end

# ---------------------------------------------------------------------------
# "Copy Firebase plist" Run Script build phase
# ---------------------------------------------------------------------------
# Copies ios/config/{prod,stage}/GoogleService-Info.plist into the built app
# based on $CONFIGURATION (see ios/scripts/copy_firebase_plist.sh). Runs after
# "Copy Bundle Resources" so it overwrites whatever GoogleService-Info.plist
# ended up there (flutterfire configure writes ios/Runner/GoogleService-Info.plist
# directly, which is git-ignored and only used as flutterfire's scratch output).
COPY_PLIST_PHASE_NAME = 'Copy Firebase plist'
existing_phase = runner_target.shell_script_build_phases.find { |p| p.name == COPY_PLIST_PHASE_NAME }
if existing_phase
  copy_plist_phase = existing_phase
else
  copy_plist_phase = runner_target.new_shell_script_build_phase(COPY_PLIST_PHASE_NAME)
  # Insert right after "Copy Bundle Resources" so our copy wins.
  resources_phase = runner_target.resources_build_phase
  if resources_phase
    phases = runner_target.build_phases
    phases.delete(copy_plist_phase)
    insert_at = phases.index(resources_phase) + 1
    phases.insert(insert_at, copy_plist_phase)
  end
end
copy_plist_phase.shell_path = '/bin/sh'
copy_plist_phase.shell_script = '"$SRCROOT/scripts/copy_firebase_plist.sh"'
copy_plist_phase.show_env_vars_in_log = '1'

# Info.plist's CFBundleDisplayName is switched to
# $(INFOPLIST_KEY_CFBundleDisplayName) below, but the base (unflavored)
# Debug/Release/Profile configs never had that build setting -- only the new
# *-stage/*-prod ones do. Backfill it on the base Runner target configs so
# the original "Runner" scheme keeps showing the same display name it always
# has instead of resolving to an empty string.
BASE_DISPLAY_NAME = 'Not Eat Alone'
runner_config_list = runner_target.build_configuration_list
BASE_CONFIGS.each do |base_name|
  base_config = runner_config_list.build_configurations.find { |c| c.name == base_name }
  next unless base_config
  next if base_config.build_settings.key?('INFOPLIST_KEY_CFBundleDisplayName')

  base_config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = BASE_DISPLAY_NAME
end

project.save
puts "[setup_flavors] Configurations added to project" \
     "#{runner_tests_target ? ', Runner, and RunnerTests' : ' and Runner'}."

# ---------------------------------------------------------------------------
# Shared schemes
# ---------------------------------------------------------------------------

def build_scheme(flavor, runner_target, runner_tests_target)
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(runner_target, runner_tests_target, launch_target: true)

  # Flutter requires this pre-build script (mirrors the stock Runner scheme)
  # so `flutter build`/`flutter run` can hand off to Xcode correctly.
  pre_action = Xcodeproj::XCScheme::ExecutionAction.new(nil, :shell_script)
  content = Xcodeproj::XCScheme::ShellScriptActionContent.new
  content.title = 'Run Prepare Flutter Framework Script'
  content.script_text = %(/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" prepare\n)
  content.buildable_reference = Xcodeproj::XCScheme::BuildableReference.new(runner_target)
  pre_action.action_content = content
  scheme.build_action.add_pre_action(pre_action)

  scheme.test_action.build_configuration = "Debug-#{flavor}"
  scheme.test_action.should_use_launch_scheme_args_env = true

  scheme.launch_action.build_configuration = "Debug-#{flavor}"

  scheme.profile_action.build_configuration = "Profile-#{flavor}"
  scheme.profile_action.should_use_launch_scheme_args_env = true

  scheme.analyze_action.build_configuration = "Debug-#{flavor}"

  scheme.archive_action.build_configuration = "Release-#{flavor}"
  scheme.archive_action.reveal_archive_in_organizer = true

  scheme
end

%w[stage prod].each do |flavor|
  scheme = build_scheme(flavor, runner_target, runner_tests_target)
  scheme.save_as(PROJECT_PATH, flavor, true)
  puts "[setup_flavors] Wrote shared scheme '#{flavor}'."
end

puts '[setup_flavors] Done.'
