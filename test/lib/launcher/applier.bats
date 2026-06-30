#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

SRC="${BATS_TEST_DIRNAME}/../../../src/launcher.sh"

setup() {
  setup_test_environment
  unset _LAUNCHER_REVAMPED_LOADED
  export LAUNCHER_DRY_RUN=1
  source "${SRC}"
  # Deterministic seams: a fixed tmux version and a fixed pane path so launch
  # strings are stable. No real tmux, no real app, no popup is ever touched.
  _tmux_version_string() { echo "tmux 3.5"; }
  _pane_path() { echo "/work/project"; }
}

teardown() {
  cleanup_test_environment
}

@test "applier - functions are defined" {
  function_exists apply_launcher
  function_exists _bind_app
  function_exists dispatch
  function_exists _launch
  function_exists _launch_group
  function_exists pick
  function_exists get_opt
  function_exists _tmux
  function_exists _run
}

@test "applier - _tmux echoes under dry-run instead of running" {
  run _tmux bind-key X foo
  [[ "${output}" == "tmux bind-key X foo" ]]
}

@test "applier - _run echoes under dry-run instead of running" {
  run _run fzf --height 40%
  [[ "${output}" == "run fzf --height 40%" ]]
}

@test "dispatch - default lazygit opens a popup at the pane path" {
  run dispatch lazygit
  [[ "${output}" == *"display-popup -E -w 80% -h 80% -d /work/project lazygit"* ]]
}

@test "dispatch - an empty id is a no-op" {
  run dispatch ""
  [[ -z "${output}" ]]
}

@test "dispatch - yazi defaults to a window" {
  run dispatch yazi
  [[ "${output}" == *"new-window -n yazi -c /work/project yazi"* ]]
  [[ "${output}" != *"display-popup"* ]]
}

@test "dispatch - a popup falls back to a window below tmux 3.2" {
  _tmux_version_string() { echo "tmux 3.1"; }
  run dispatch lazygit
  [[ "${output}" != *"display-popup"* ]]
  [[ "${output}" == *"new-window -n lazygit -c /work/project lazygit"* ]]
}

@test "dispatch - split mode opens beside the work" {
  tmux set-option -gq "@launcher_lazygit_mode" "split"
  run dispatch lazygit
  [[ "${output}" == *"split-window -c /work/project lazygit"* ]]
}

@test "dispatch - marker scoping opens at the project root" {
  _pane_path() { echo "/work/project/src/lib"; }
  _path_has_marker() { [[ "${1}" == "/work/project" ]]; }
  tmux set-option -gq "@launcher_lazygit_marker" ".git"
  run dispatch lazygit
  [[ "${output}" == *"-d /work/project lazygit"* ]]
  [[ "${output}" != *"/work/project/src/lib"* ]]
}

@test "dispatch - a global marker option is honored" {
  _pane_path() { echo "/work/project/src"; }
  _path_has_marker() { [[ "${1}" == "/work/project" ]]; }
  tmux set-option -gq "@launcher_marker" ".git"
  run dispatch lazygit
  [[ "${output}" == *"-d /work/project lazygit"* ]]
}

@test "dispatch - a passing guard allows the launch" {
  _guard() { return 0; }
  tmux set-option -gq "@launcher_lazygit_if" "true"
  run dispatch lazygit
  [[ "${output}" == *"display-popup"* ]]
}

@test "dispatch - a failing guard makes the key inert" {
  _guard() { return 1; }
  tmux set-option -gq "@launcher_lazygit_if" "true"
  run dispatch lazygit
  [[ -z "${output}" ]]
}

@test "dispatch - the default guard runs the predicate through sh" {
  tmux set-option -gq "@launcher_lazygit_if" "true"
  run dispatch lazygit
  [[ "${output}" == *"display-popup"* ]]
}

@test "dispatch - the default guard blocks when the predicate fails" {
  tmux set-option -gq "@launcher_lazygit_if" "false"
  run dispatch lazygit
  [[ -z "${output}" ]]
}

@test "dispatch - a group opens a dashboard with a tiled layout" {
  tmux set-option -gq "@launcher_dash_group" "lazygit htop"
  run dispatch dash
  [[ "${output}" == *"new-window -n lazygit -c /work/project lazygit"* ]]
  [[ "${output}" == *"split-window -c /work/project htop"* ]]
  [[ "${output}" == *"select-layout tiled"* ]]
}

@test "dispatch - env, pre, and exit hooks are composed into the command" {
  tmux set-option -gq "@launcher_lazygit_env" "FOO=bar"
  tmux set-option -gq "@launcher_lazygit_pre" "direnv allow"
  tmux set-option -gq "@launcher_lazygit_exit" "tmux refresh-client -S"
  run dispatch lazygit
  [[ "${output}" == *"direnv allow && env FOO=bar lazygit; tmux refresh-client -S"* ]]
}

@test "dispatch - a remote host wraps the command in ssh" {
  tmux set-option -gq "@launcher_k9s_command" "k9s"
  tmux set-option -gq "@launcher_k9s_host" "box.example"
  run dispatch k9s
  [[ "${output}" == *"ssh -t box.example k9s"* ]]
}

@test "dispatch - a runtime argument is appended to the command" {
  tmux set-option -gq "@launcher_man_command" "man"
  run dispatch man tmux
  [[ "${output}" == *"man tmux"* ]]
}

@test "dispatch - reuse skips a new window when one already exists" {
  tmux set-option -gq "@launcher_lazygit_mode" "window"
  tmux set-option -gq "@launcher_lazygit_reuse" "on"
  run dispatch lazygit
  [[ -z "${output}" ]]
}

@test "dispatch - reuse creates a window when none exists" {
  _window_exists() { return 1; }
  tmux set-option -gq "@launcher_lazygit_mode" "window"
  tmux set-option -gq "@launcher_lazygit_reuse" "on"
  run dispatch lazygit
  [[ "${output}" == *"new-window -n lazygit -c /work/project lazygit"* ]]
}

@test "_bind_app - default lazygit binds the key to dispatch via run-shell" {
  run _bind_app lazygit
  [[ "${output}" == *"bind-key C-g run-shell -b bash"* ]]
  [[ "${output}" == *"dispatch lazygit"* ]]
}

@test "_bind_app - an app without a key is skipped" {
  tmux set-option -gq "@launcher_apps" "nokey"
  run _bind_app nokey
  [[ -z "${output}" ]]
}

@test "_bind_app - a prompt routes the key through command-prompt" {
  tmux set-option -gq "@launcher_man_key" "C-m"
  tmux set-option -gq "@launcher_man_prompt" "topic:"
  run _bind_app man
  [[ "${output}" == *"bind-key C-m command-prompt -p topic:"* ]]
  [[ "${output}" == *"dispatch man %%"* ]]
}

@test "_bind_app - skip-missing drops an app whose command is absent" {
  tmux set-option -gq "@launcher_ghost_key" "C-z"
  tmux set-option -gq "@launcher_ghost_command" "definitely-missing-binary-xyz"
  tmux set-option -gq "@launcher_skip_missing" "on"
  run _bind_app ghost
  [[ -z "${output}" ]]
}

@test "_bind_app - skip-missing keeps an app whose command is present" {
  tmux set-option -gq "@launcher_shellish_key" "C-z"
  tmux set-option -gq "@launcher_shellish_command" "sh"
  tmux set-option -gq "@launcher_skip_missing" "on"
  run _bind_app shellish
  [[ "${output}" == *"bind-key C-z run-shell -b bash"* ]]
}

@test "_bind_app - skip-missing does not probe a remote command" {
  tmux set-option -gq "@launcher_rk_key" "C-z"
  tmux set-option -gq "@launcher_rk_command" "definitely-missing-binary-xyz"
  tmux set-option -gq "@launcher_rk_host" "box.example"
  tmux set-option -gq "@launcher_skip_missing" "on"
  run _bind_app rk
  [[ "${output}" == *"bind-key C-z run-shell -b bash"* ]]
}

@test "_bind_menu - a menu key binds display-menu over every app" {
  tmux set-option -gq "@launcher_menu_key" "C-l"
  run _bind_menu
  [[ "${output}" == *"bind-key C-l display-menu -T Launchers"* ]]
  [[ "${output}" == *"dispatch lazygit"* ]]
  [[ "${output}" == *"dispatch yazi"* ]]
}

@test "_bind_menu - no menu key binds nothing" {
  run _bind_menu
  [[ -z "${output}" ]]
}

@test "_bind_picker - a picker key binds the fzf popup" {
  tmux set-option -gq "@launcher_picker_key" "C-p"
  run _bind_picker
  [[ "${output}" == *"bind-key C-p display-popup -E bash"* ]]
  [[ "${output}" == *"pick"* ]]
}

@test "_bind_picker - no picker key binds nothing" {
  run _bind_picker
  [[ -z "${output}" ]]
}

@test "apply_launcher - default apps each bind to dispatch" {
  run apply_launcher
  [[ "${output}" == *"bind-key C-g run-shell -b bash"* ]]
  [[ "${output}" == *"dispatch lazygit"* ]]
  [[ "${output}" == *"dispatch yazi"* ]]
  [[ "${output}" != *"display-menu"* ]]
}

@test "apply_launcher - menu and picker keys add their bindings" {
  tmux set-option -gq "@launcher_menu_key" "C-l"
  tmux set-option -gq "@launcher_picker_key" "C-p"
  run apply_launcher
  [[ "${output}" == *"display-menu -T Launchers"* ]]
  [[ "${output}" == *"display-popup -E bash"* ]]
}

@test "pick - a chosen app is dispatched" {
  _run() { echo "lazygit"; }
  run pick
  [[ "${output}" == *"display-popup"* ]]
  [[ "${output}" == *"lazygit"* ]]
}

@test "pick - an empty choice launches nothing" {
  _run() { printf ''; }
  run pick
  [[ -z "${output}" ]]
}

@test "entrypoint - running the script with no args applies the bindings" {
  run bash "${SRC}"
  [[ "${output}" == *"run-shell -b bash"* ]]
  [[ "${output}" == *"dispatch lazygit"* ]]
}

@test "entrypoint - the dispatch subcommand launches an app" {
  run bash "${SRC}" dispatch lazygit
  [[ "${output}" == *"lazygit"* ]]
  [[ "${output}" == *"-n lazygit"* ]]
}

@test "entrypoint - the pick subcommand runs the picker" {
  run bash "${SRC}" pick
  [[ "${output}" == *"run fzf"* ]]
}
