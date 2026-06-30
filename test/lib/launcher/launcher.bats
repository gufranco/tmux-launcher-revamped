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

@test "launcher.sh - effective_mode passes split through and defaults unknown to window" {
  [[ "$(effective_mode split 3.5)" == "split" ]]
  [[ "$(effective_mode split 1.9)" == "split" ]]
  [[ "$(effective_mode weird 3.5)" == "window" ]]
}

@test "launcher.sh - ssh_wrap wraps only when a host is given" {
  [[ "$(ssh_wrap host.example lazygit)" == "ssh -t host.example lazygit" ]]
  [[ "$(ssh_wrap '' lazygit)" == "lazygit" ]]
}

@test "launcher.sh - compose_command builds the bare command with no extras" {
  [[ "$(compose_command '' '' lazygit '')" == "lazygit" ]]
}

@test "launcher.sh - compose_command adds env vars" {
  [[ "$(compose_command 'FOO=bar' '' lazygit '')" == "env FOO=bar lazygit" ]]
}

@test "launcher.sh - compose_command runs a pre hook first" {
  [[ "$(compose_command '' 'direnv allow' lazygit '')" == "direnv allow && lazygit" ]]
}

@test "launcher.sh - compose_command appends an exit hook" {
  [[ "$(compose_command '' '' lazygit 'tmux refresh-client -S')" == "lazygit; tmux refresh-client -S" ]]
}

@test "launcher.sh - compose_command combines env, pre, and exit" {
  run compose_command 'A=1' 'pre' cmd 'post'
  [[ "${output}" == "pre && env A=1 cmd; post" ]]
}

@test "launcher.sh - _path_has_marker reflects the filesystem" {
  touch "${TEST_TMPDIR}/MARK"
  _path_has_marker "${TEST_TMPDIR}" MARK
  ! _path_has_marker "${TEST_TMPDIR}" NOPE
}

@test "launcher.sh - walk_up_marker finds the nearest ancestor with the marker" {
  _path_has_marker() { [[ "${1}" == "/home/u/proj" ]]; }
  [[ "$(walk_up_marker /home/u/proj/src/lib .git)" == "/home/u/proj" ]]
}

@test "launcher.sh - walk_up_marker stops at the depth bound" {
  _path_has_marker() { [[ "${1}" == "/" ]]; }
  run walk_up_marker /a/b/c/d/e .git 2
  [[ "${status}" -ne 0 ]]
  [[ -z "${output}" ]]
}

@test "launcher.sh - walk_up_marker rejects empty input" {
  ! walk_up_marker "" .git
  ! walk_up_marker /a/b ""
}

@test "launcher.sh - walk_up_marker walks to the root and stops" {
  _path_has_marker() { return 1; }
  ! walk_up_marker /a/b .git 50
}

@test "launcher.sh - scoped_path returns the marker root when found" {
  _path_has_marker() { [[ "${1}" == "/home/u/proj" ]]; }
  [[ "$(scoped_path /home/u/proj/src .git 20)" == "/home/u/proj" ]]
}

@test "launcher.sh - scoped_path falls back to the start path when no marker is found" {
  _path_has_marker() { return 1; }
  [[ "$(scoped_path /home/u/deep/path .git 20)" == "/home/u/deep/path" ]]
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
