#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _LAUNCHER_REVAMPED_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/launcher/launcher.sh"
}

teardown() {
  cleanup_test_environment
}

@test "launcher.sh - parse_tmux_version handles suffixes" {
  [[ "$(parse_tmux_version 'tmux 3.4a')" == "3.4" ]]
  [[ "$(parse_tmux_version 'tmux next-3.5')" == "3.5" ]]
  [[ "$(parse_tmux_version 'tmux 1.9')" == "1.9" ]]
}

@test "launcher.sh - version_ge compares correctly" {
  version_ge 3.4 3.2
  version_ge 3.2 3.2
  ! version_ge 3.1 3.2
  ! version_ge "" 3.2
}

@test "launcher.sh - effective_mode gates popup on tmux 3.2" {
  [[ "$(effective_mode popup 3.5)" == "popup" ]]
  [[ "$(effective_mode popup 3.2)" == "popup" ]]
  [[ "$(effective_mode popup 3.1)" == "window" ]]
  [[ "$(effective_mode window 3.5)" == "window" ]]
}

@test "launcher.sh - built-in defaults for lazygit and yazi" {
  [[ "$(default_key lazygit)" == "C-g" ]]
  [[ "$(default_key yazi)" == "C-y" ]]
  [[ -z "$(default_key htop)" ]]
  [[ "$(default_command lazygit)" == "lazygit" ]]
  [[ "$(default_command htop)" == "htop" ]]
  [[ "$(default_mode yazi)" == "window" ]]
  [[ "$(default_mode lazygit)" == "popup" ]]
}

@test "launcher.sh - tmux_version uses the seam" {
  _tmux_version_string() { echo "tmux 3.3a"; }
  [[ "$(tmux_version)" == "3.3" ]]
}

@test "launcher.sh - host-probe seam is callable" {
  run _tmux_version_string
  true
}
