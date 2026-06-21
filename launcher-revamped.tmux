#!/usr/bin/env bash
#
# launcher-revamped.tmux: TPM entry point.
#
# Binds the configured app launchers. The popup mode is version gated, so this
# runs cleanly on every tmux version TPM supports (1.9 and up).

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${CURRENT_DIR}/src/launcher.sh"
