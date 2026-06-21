#!/usr/bin/env bash
#
# launcher.sh: pure decision helpers for tmux-launcher-revamped.
#
# Version parsing and the mode decision are pure. The running tmux version sits
# behind a seam the tests override, so the binding decisions are validated
# without a live tmux.

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

# effective_mode REQUESTED VERSION -> popup when popup is requested and the tmux
# version supports display-popup (3.2+), otherwise window. display-popup is the
# only mode that needs a version gate, so an unsupported popup degrades to a
# window instead of failing.
effective_mode() {
  if [[ "${1}" == "popup" ]] && version_ge "${2}" 3.2; then
    echo "popup"
  else
    echo "window"
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
export -f default_key
export -f default_command
export -f default_mode
export -f _tmux_version_string
export -f tmux_version
