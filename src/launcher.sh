#!/usr/bin/env bash
#
# launcher.sh: bind keys that launch TUI apps in a popup or a window, scoped to
# the current pane's directory. Apps are listed in @launcher_apps; each one reads
# its key, command, mode, name, and popup size from per-app options.
#
# With LAUNCHER_DRY_RUN set, each tmux command is printed instead of run, which is
# how the test suite validates the binding matrix without a live tmux.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/launcher/launcher.sh"

_emit() {
  if [[ -n "${LAUNCHER_DRY_RUN:-}" ]]; then
    echo "$*"
  else
    tmux "$@"
  fi
}

# get_opt OPT DEFAULT -> the global option value, or DEFAULT when unset.
get_opt() {
  local v
  v="$(tmux show-option -gqv "${1}" 2>/dev/null)"
  echo "${v:-${2}}"
}

_path='#{pane_current_path}'

# _bind_app ID VERSION -> bind one app from its per-app options.
_bind_app() {
  local id="${1}" ver="${2}" key cmd mode name width height eff
  key="$(get_opt "@launcher_${id}_key" "$(default_key "${id}")")"
  cmd="$(get_opt "@launcher_${id}_command" "$(default_command "${id}")")"
  mode="$(get_opt "@launcher_${id}_mode" "$(default_mode "${id}")")"
  name="$(get_opt "@launcher_${id}_name" "${id}")"
  width="$(get_opt "@launcher_${id}_width" "80%")"
  height="$(get_opt "@launcher_${id}_height" "80%")"
  # A launcher needs a key and a command; skip silently otherwise.
  [[ -z "${key}" || -z "${cmd}" ]] && return 0
  eff="$(effective_mode "${mode}" "${ver}")"
  if [[ "${eff}" == "popup" ]]; then
    _emit bind-key "${key}" display-popup -E -w "${width}" -h "${height}" -d "${_path}" "${cmd}"
  else
    _emit bind-key "${key}" new-window -n "${name}" -c "${_path}" "${cmd}"
  fi
}

apply_launcher() {
  local ver apps id
  ver="$(tmux_version)"
  apps="$(get_opt @launcher_apps "lazygit yazi")"
  for id in ${apps}; do
    [[ -z "${id}" ]] && continue
    _bind_app "${id}" "${ver}"
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  apply_launcher
fi
