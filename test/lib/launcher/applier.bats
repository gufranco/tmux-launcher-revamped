#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _LAUNCHER_REVAMPED_LOADED
  export LAUNCHER_DRY_RUN=1
  source "${BATS_TEST_DIRNAME}/../../../src/launcher.sh"
  _tmux_version_string() { echo "tmux 3.5"; }
}

teardown() {
  cleanup_test_environment
}

@test "applier - functions are defined" {
  function_exists apply_launcher
  function_exists _bind_app
  function_exists get_opt
}

@test "applier - default apps bind lazygit popup and yazi window" {
  run apply_launcher
  [[ "${output}" == *"bind-key C-g display-popup -E -w 80% -h 80% -d #{pane_current_path} lazygit"* ]]
  [[ "${output}" == *"bind-key C-y new-window -n yazi -c #{pane_current_path} yazi"* ]]
}

@test "applier - a custom app defaults to a popup with its own command" {
  tmux set-option -gq "@launcher_apps" "htop"
  tmux set-option -gq "@launcher_htop_key" "C-t"
  run apply_launcher
  [[ "${output}" == *"bind-key C-t display-popup -E -w 80% -h 80% -d #{pane_current_path} htop"* ]]
}

@test "applier - popup falls back to a window below tmux 3.2" {
  _tmux_version_string() { echo "tmux 3.1"; }
  run apply_launcher
  [[ "${output}" != *"display-popup"* ]]
  [[ "${output}" == *"bind-key C-g new-window -n lazygit -c #{pane_current_path} lazygit"* ]]
}

@test "applier - mode can be overridden to a window" {
  tmux set-option -gq "@launcher_lazygit_mode" "window"
  run apply_launcher
  [[ "${output}" == *"bind-key C-g new-window -n lazygit -c #{pane_current_path} lazygit"* ]]
}

@test "applier - popup size is configurable" {
  tmux set-option -gq "@launcher_lazygit_width" "90%"
  tmux set-option -gq "@launcher_lazygit_height" "70%"
  run apply_launcher
  [[ "${output}" == *"display-popup -E -w 90% -h 70%"* ]]
}

@test "applier - a custom command and name are honored" {
  tmux set-option -gq "@launcher_apps" "files"
  tmux set-option -gq "@launcher_files_key" "C-f"
  tmux set-option -gq "@launcher_files_command" "lf"
  tmux set-option -gq "@launcher_files_mode" "window"
  tmux set-option -gq "@launcher_files_name" "lf"
  run apply_launcher
  [[ "${output}" == *"bind-key C-f new-window -n lf -c #{pane_current_path} lf"* ]]
}

@test "applier - an app without a key is skipped" {
  tmux set-option -gq "@launcher_apps" "nokey"
  run apply_launcher
  [[ -z "${output}" ]]
}

@test "applier - multiple apps each get a binding" {
  tmux set-option -gq "@launcher_apps" "lazygit yazi"
  run apply_launcher
  [[ "${output}" == *"C-g display-popup"* ]]
  [[ "${output}" == *"C-y new-window"* ]]
}
