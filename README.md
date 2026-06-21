<div align="center">

<h1>tmux-launcher-revamped</h1>

**Launch any TUI app in a popup or a window, scoped to the current pane's directory, with one configurable binding per app.**

[![Tests](https://github.com/gufranco/tmux-launcher-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/gufranco/tmux-launcher-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

**any** app · **popup or window** · **tmux 1.9 to 3.5** · **41** tests · **95%+** coverage

Bind a key to open `lazygit`, `yazi`, `lf`, `htop`, `k9s`, or any other terminal app, in a floating popup or a fresh window, always starting in the current pane's directory. You list the apps and set a key, command, mode, and size for each. Popups need tmux 3.2, so on older tmux a popup launcher falls back to a window automatically.

Built from [tmux-plugin-template](https://github.com/gufranco/tmux-plugin-template).

<table>
<tr>
<td><strong>Any app</strong><br>Define `name`, key, command, and mode for each launcher; nothing is hardcoded.</td>
<td><strong>Popup or window</strong><br>Pick a floating popup or a real window per app. Apps that need image passthrough work in a window.</td>
</tr>
<tr>
<td><strong>Current directory</strong><br>Every launcher starts in `#{pane_current_path}`, so the app opens where you are.</td>
<td><strong>Version-aware</strong><br>`display-popup` is used on tmux 3.2 and up; below that, a popup launcher opens a window instead.</td>
</tr>
</table>

## How it works

List your apps in `@launcher_apps`. For each app `<id>`, set its options. `lazygit` (popup, `C-g`) and `yazi` (window, `C-y`) ship as working defaults.

```tmux
set -g @plugin 'gufranco/tmux-launcher-revamped'

# add your own apps to the list
set -g @launcher_apps 'lazygit yazi lazydocker htop k9s'

set -g @launcher_lazydocker_key 'C-d'
set -g @launcher_htop_key 'C-t'
set -g @launcher_k9s_key 'C-s'
```

## Configuration

`@launcher_apps` is a space separated list of app ids. Each id reads the options below.

| Option | Default | Meaning |
|--------|---------|---------|
| `@launcher_apps` | `lazygit yazi` | the apps to bind |
| `@launcher_<id>_key` | built-in for `lazygit`/`yazi`, else required | the prefix key |
| `@launcher_<id>_command` | the id itself | the shell command to run |
| `@launcher_<id>_mode` | `popup` (`yazi` is `window`) | `popup` or `window` |
| `@launcher_<id>_name` | the id itself | window name, in `window` mode |
| `@launcher_<id>_width` | `80%` | popup width |
| `@launcher_<id>_height` | `80%` | popup height |

An app listed without a key and without a built-in default is skipped, so a typo never produces a broken binding.

## Examples

Popular apps people bind, with the mode that works best. File and media tools with image previews want `window` mode, since tmux popups have no passthrough ([tmux#4329](https://github.com/tmux/tmux/issues/4329)).

| App | Command | Suggested mode | Why |
|-----|---------|----------------|-----|
| lazygit | `lazygit` | popup | quick git, no previews |
| lazydocker | `lazydocker` | popup | container TUI |
| gitui | `gitui` | popup | git TUI |
| k9s | `k9s` | popup | kubernetes TUI |
| htop / btop | `htop` / `btop` | popup | process monitor |
| gh dash | `gh dash` | popup | GitHub dashboard |
| taskwarrior-tui | `taskwarrior-tui` | popup | tasks |
| yazi | `yazi` | window | image previews need passthrough |
| lf | `lf` | window | file manager, previews |
| ranger | `ranger` | window | file manager, previews |
| nnn | `nnn` | window | file manager |
| broot | `broot` | window | directory tree, opens files |

A full block adding several of these:

```tmux
set -g @launcher_apps 'lazygit lazydocker k9s htop yazi lf'

set -g @launcher_lazydocker_key 'C-d'
set -g @launcher_k9s_key       'C-s'
set -g @launcher_htop_key      'C-t'
set -g @launcher_lf_key        'C-f'
set -g @launcher_lf_mode       'window'

# a roomier lazygit popup
set -g @launcher_lazygit_width  '90%'
set -g @launcher_lazygit_height '85%'
```

## Install

With [TPM](https://github.com/tmux-plugins/tpm), add to `~/.tmux.conf`:

```tmux
set -g @plugin 'gufranco/tmux-launcher-revamped'
```

Then press `prefix + I` to install. Out of the box, `prefix + C-g` opens lazygit and `prefix + C-y` opens yazi.

Manual install:

```bash
git clone https://github.com/gufranco/tmux-launcher-revamped ~/.tmux/plugins/tmux-launcher-revamped
run-shell ~/.tmux/plugins/tmux-launcher-revamped/launcher-revamped.tmux
```

## Compatibility

Works on every tmux version TPM supports, 1.9 and up, on Linux (x86_64 and arm64) and macOS (Intel and Apple Silicon). The `popup` mode uses `display-popup`, which is tmux 3.2 and up; on older tmux a popup launcher opens a window instead, so every binding still works. Each launcher runs whatever command you give it, so the app itself must be installed.

## Development

```bash
make test    # bats suite
make lint    # shellcheck
make coverage  # kcov line coverage on Linux
```

The decision logic lives in [`src/lib/launcher/launcher.sh`](src/lib/launcher/launcher.sh) as pure, seam-backed helpers, and the applier in [`src/launcher.sh`](src/launcher.sh) runs under a dry-run mode so the full binding matrix is validated without a live tmux.

## License

[MIT](LICENSE), copyright Gustavo Franco.
