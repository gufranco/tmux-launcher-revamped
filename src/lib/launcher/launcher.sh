#!/usr/bin/env bash
#
# launcher.sh: pure decision helpers for tmux-launcher-revamped.
#
# Version parsing and the mode decision are pure. The running tmux version and
# the filesystem marker probe sit behind seams the tests override, so the
# binding and scoping decisions are validated without a live tmux or real I/O.

[[ -n "${_LAUNCHER_REVAMPED_LOADED:-}" ]] && return 0
_LAUNCHER_REVAMPED_LOADED=1

# parse_tmux_version TEXT -> major.minor from `tmux -V`, handling 3.4a and next-3.5.
parse_tmux_version() {
  printf '%s\n' "${1}" | sed -En 's/^tmux[ -]([a-z]+-)?([0-9]+\.[0-9]+).*/\2/p'
}

# version_ge HAVE WANT -> 0 when HAVE is greater than or equal to WANT.
version_ge() {
  [[ -n "${1}" && -n "${2}" ]] || return 1
  [ "$(printf '%s\n%s\n' "${2}" "${1}" | sort -V | head -n1)" = "${2}" ]
}

# effective_mode REQUESTED VERSION -> the mode that actually runs. popup is the
# only mode that needs a version gate (display-popup is 3.2+), so an unsupported
# popup degrades to a window. split passes through; window is the safe default.
effective_mode() {
  case "${1}" in
    popup)
      if version_ge "${2}" 3.2; then echo "popup"; else echo "window"; fi
      ;;
    split) echo "split" ;;
    window) echo "window" ;;
    *) echo "window" ;;
  esac
}

# ssh_wrap HOST CMD -> CMD wrapped in `ssh -t HOST` when HOST is set, else CMD.
ssh_wrap() {
  if [[ -n "${1}" ]]; then
    printf 'ssh -t %s %s' "${1}" "${2}"
  else
    printf '%s' "${2}"
  fi
}

# compose_command ENV PRE CMD EXIT -> the launch command with optional env vars,
# a pre hook run first, and an exit hook run after the app quits. Each piece is
# optional; an empty argument is skipped.
compose_command() {
  local env_vars="${1}" pre="${2}" cmd="${3}" exit_hook="${4}" out
  out="${cmd}"
  [[ -n "${env_vars}" ]] && out="env ${env_vars} ${out}"
  [[ -n "${pre}" ]] && out="${pre} && ${out}"
  [[ -n "${exit_hook}" ]] && out="${out}; ${exit_hook}"
  printf '%s' "${out}"
}

# _path_has_marker DIR MARKER -> 0 when DIR/MARKER exists. Filesystem seam; the
# tests override it so the upward walk is validated without touching real paths.
_path_has_marker() { [ -e "${1}/${2}" ]; }

# walk_up_marker START MARKER [MAX] -> print the nearest ancestor of START that
# contains MARKER, walking up at most MAX levels. Returns 1 when none is found.
walk_up_marker() {
  local dir="${1}" marker="${2}" max="${3:-20}" depth=0
  [[ -z "${dir}" || -z "${marker}" ]] && return 1
  while [[ "${depth}" -lt "${max}" ]]; do
    if _path_has_marker "${dir}" "${marker}"; then
      printf '%s' "${dir}"
      return 0
    fi
    [[ "${dir}" == "/" ]] && break
    dir="$(dirname "${dir}")"
    depth=$((depth + 1))
  done
  return 1
}

# scoped_path START MARKER [MAX] -> the marker root above START, or START itself
# when no marker is found within MAX levels. This keeps a launch bounded to the
# pane path when the project root cannot be located.
scoped_path() {
  local root
  if root="$(walk_up_marker "${1}" "${2}" "${3}")"; then
    printf '%s' "${root}"
  else
    printf '%s' "${1}"
  fi
}

# Built-in defaults for the two apps shipped out of the box. yazi defaults to a
# window because tmux popups lack passthrough, so image previews break (tmux#4329).
default_key() {
  case "${1}" in
    lazygit) echo "C-g" ;;
    yazi)    echo "C-y" ;;
    *)       echo "" ;;
  esac
}
default_command() {
  case "${1}" in
    lazygit) echo "lazygit" ;;
    yazi)    echo "yazi" ;;
    *)       echo "${1}" ;;
  esac
}
default_mode() {
  case "${1}" in
    yazi) echo "window" ;;
    *)    echo "popup" ;;
  esac
}

# Host-probe seams. Tests override these.
_tmux_version_string() { tmux -V 2>/dev/null; }

tmux_version() { parse_tmux_version "$(_tmux_version_string)"; }

export -f parse_tmux_version
export -f version_ge
export -f effective_mode
export -f ssh_wrap
export -f compose_command
export -f _path_has_marker
export -f walk_up_marker
export -f scoped_path
export -f default_key
export -f default_command
export -f default_mode
export -f _tmux_version_string
export -f tmux_version
