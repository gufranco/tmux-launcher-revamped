#!/usr/bin/env bash
#
# launcher.sh: bind keys that launch TUI apps in a popup, window, or split,
# scoped to the current pane (or project root). Apps are listed in
# @launcher_apps; each one reads its key, command, mode, name, size, and a set
# of optional behaviours (guard, group, prompt, remote host, env, hooks, reuse)
# from per-app options.
#
# Every tmux command and every external command goes through a single seam
# (_tmux and _run). With LAUNCHER_DRY_RUN set, each seam prints its arguments
# instead of running them, which is how the test suite validates the binding
# matrix and the dispatch paths without a live tmux, a popup, or a real app.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_SELF="${PLUGIN_DIR}/src/launcher.sh"

# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/launcher/launcher.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/utils/has-command.sh"

# _tmux ARGS -> run a tmux command, or echo it under dry-run so the tests assert
# the command string without a live tmux server.
# A single-line seam keeps the dry-run and live paths on one reachable line.
_tmux() { [[ -n "${LAUNCHER_DRY_RUN:-}" ]] && { echo "tmux $*"; return 0; }; command tmux "$@"; }

# _run ARGS -> run an external command (the fzf picker), or echo it under dry-run.
_run() { [[ -n "${LAUNCHER_DRY_RUN:-}" ]] && { echo "run $*"; return 0; }; "$@"; }

# get_opt OPT DEFAULT -> the global option value, or DEFAULT when unset/empty.
get_opt() {
  local v
  v="$(tmux show-option -gqv "${1}" 2>/dev/null)"
  echo "${v:-${2}}"
}

# _pane_path -> the current pane directory, resolved through the tmux seam.
_pane_path() { _tmux display-message -p '#{pane_current_path}'; }

# _guard PRED -> evaluate a launch predicate. Non-zero means do not launch. The
# scoped path is exported as LAUNCHER_PATH so a predicate can test the target.
_guard() { sh -c "${1}"; }

# _window_exists NAME -> select an existing window by exact name. Success means
# the window is already open, which the reuse path uses to avoid a duplicate.
_window_exists() { _tmux select-window -t "=${1}" >/dev/null 2>&1; }

# _first_word STR -> the first whitespace-delimited token of STR.
_first_word() { printf '%s' "${1%% *}"; }

# _launch EFF NAME PATH CMD WIDTH HEIGHT REUSE -> emit the launch for one app.
_launch() {
  local eff="${1}" name="${2}" path="${3}" cmd="${4}" width="${5}" height="${6}" reuse="${7}"
  case "${eff}" in
    popup)
      _tmux display-popup -E -w "${width}" -h "${height}" -d "${path}" "${cmd}"
      ;;
    split)
      _tmux split-window -c "${path}" "${cmd}"
      ;;
    *)
      if [[ "${reuse}" == "on" ]] && _window_exists "${name}"; then
        return 0
      fi
      _tmux new-window -n "${name}" -c "${path}" "${cmd}"
      ;;
  esac
}

# _launch_group MEMBERS PATH -> open a dashboard: the first member in a new
# window, the rest split beside it, then a tiled layout. Members reuse each
# app's configured command.
_launch_group() {
  local members="${1}" path="${2}" first=1 m mcmd
  # shellcheck disable=SC2086
  for m in ${members}; do
    [[ -z "${m}" ]] && continue
    mcmd="$(get_opt "@launcher_${m}_command" "$(default_command "${m}")")"
    [[ -z "${mcmd}" ]] && continue
    if [[ "${first}" -eq 1 ]]; then
      _tmux new-window -n "${m}" -c "${path}" "${mcmd}"
      first=0
    else
      _tmux split-window -c "${path}" "${mcmd}"
    fi
  done
  [[ "${first}" -eq 0 ]] && _tmux select-layout tiled
  return 0
}

# dispatch ID [ARG] -> resolve one app's config and launch it. This is the
# single launch path; both the key bindings and the picker route through it.
dispatch() {
  local id="${1:-}" arg="${2:-}"
  [[ -z "${id}" ]] && return 0

  local cmd pred path marker maxdepth scope group
  local env_vars pre exit_hook remote mode ver eff name width height reuse full

  cmd="$(get_opt "@launcher_${id}_command" "$(default_command "${id}")")"
  [[ -z "${cmd}" ]] && return 0

  ver="$(tmux_version)"
  path="$(_pane_path)"

  marker="$(get_opt "@launcher_${id}_marker" "$(get_opt @launcher_marker "")")"
  if [[ -n "${marker}" ]]; then
    maxdepth="$(get_opt @launcher_max_depth 20)"
    scope="$(scoped_path "${path}" "${marker}" "${maxdepth}")"
  else
    scope="${path}"
  fi

  pred="$(get_opt "@launcher_${id}_if" "")"
  if [[ -n "${pred}" ]]; then
    LAUNCHER_PATH="${scope}" _guard "${pred}" || return 0
  fi

  group="$(get_opt "@launcher_${id}_group" "")"
  if [[ -n "${group}" ]]; then
    _launch_group "${group}" "${scope}"
    return 0
  fi

  env_vars="$(get_opt "@launcher_${id}_env" "")"
  pre="$(get_opt "@launcher_${id}_pre" "")"
  exit_hook="$(get_opt "@launcher_${id}_exit" "")"
  remote="$(get_opt "@launcher_${id}_host" "")"
  [[ -n "${arg}" ]] && cmd="${cmd} ${arg}"

  full="$(compose_command "${env_vars}" "${pre}" "${cmd}" "${exit_hook}")"
  [[ -n "${remote}" ]] && full="$(ssh_wrap "${remote}" "${full}")"

  mode="$(get_opt "@launcher_${id}_mode" "$(default_mode "${id}")")"
  eff="$(effective_mode "${mode}" "${ver}")"
  name="$(get_opt "@launcher_${id}_name" "${id}")"
  width="$(get_opt "@launcher_${id}_width" "80%")"
  height="$(get_opt "@launcher_${id}_height" "80%")"
  reuse="$(get_opt "@launcher_${id}_reuse" "")"

  _launch "${eff}" "${name}" "${scope}" "${full}" "${width}" "${height}" "${reuse}"
}

# pick -> fzf over the app list, then dispatch the chosen app.
pick() {
  local apps choice
  apps="$(get_opt @launcher_apps "lazygit yazi")"
  # shellcheck disable=SC2086
  choice="$(printf '%s\n' ${apps} | _run fzf)"
  [[ -z "${choice}" ]] && return 0
  dispatch "${choice}"
}

# _bind_app ID -> wire one app's key to dispatch. An app with no key, or a
# missing local command when skip-missing is on, binds nothing. A prompt option
# routes through command-prompt so the typed value is appended to the command.
_bind_app() {
  local id="${1}" key cmd prompt host skip first
  key="$(get_opt "@launcher_${id}_key" "$(default_key "${id}")")"
  cmd="$(get_opt "@launcher_${id}_command" "$(default_command "${id}")")"
  [[ -z "${key}" || -z "${cmd}" ]] && return 0

  host="$(get_opt "@launcher_${id}_host" "")"
  skip="$(get_opt @launcher_skip_missing "")"
  if [[ "${skip}" == "on" && -z "${host}" ]]; then
    first="$(_first_word "${cmd}")"
    has_command "${first}" || return 0
  fi

  prompt="$(get_opt "@launcher_${id}_prompt" "")"
  if [[ -n "${prompt}" ]]; then
    _tmux bind-key "${key}" command-prompt -p "${prompt}" "run-shell -b 'bash ${_SELF} dispatch ${id} %%'"
  else
    _tmux bind-key "${key}" run-shell -b "bash ${_SELF} dispatch ${id}"
  fi
}

# _bind_menu -> bind a global menu (display-menu, available below 3.2) listing
# every app. Nothing is bound unless @launcher_menu_key is set.
_bind_menu() {
  local key apps id name args
  key="$(get_opt @launcher_menu_key "")"
  [[ -z "${key}" ]] && return 0
  apps="$(get_opt @launcher_apps "lazygit yazi")"
  args=(display-menu -T "Launchers")
  # shellcheck disable=SC2086
  for id in ${apps}; do
    [[ -z "${id}" ]] && continue
    name="$(get_opt "@launcher_${id}_name" "${id}")"
    args+=("${name}" "" "run-shell -b 'bash ${_SELF} dispatch ${id}'")
  done
  _tmux bind-key "${key}" "${args[@]}"
}

# _bind_picker -> bind the fzf app picker inside a popup. Nothing is bound unless
# @launcher_picker_key is set.
_bind_picker() {
  local key
  key="$(get_opt @launcher_picker_key "")"
  [[ -z "${key}" ]] && return 0
  _tmux bind-key "${key}" display-popup -E "bash ${_SELF} pick"
}

# apply_launcher -> bind every configured app plus the optional menu and picker.
apply_launcher() {
  local apps id
  apps="$(get_opt @launcher_apps "lazygit yazi")"
  # shellcheck disable=SC2086
  for id in ${apps}; do
    [[ -z "${id}" ]] && continue
    _bind_app "${id}"
  done
  _bind_menu
  _bind_picker
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    dispatch) shift; dispatch "$@" ;;
    pick)     pick ;;
    *)        apply_launcher ;;
  esac
fi
