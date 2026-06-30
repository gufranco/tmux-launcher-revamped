# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-30

### Added

- Global launcher menu: set `@launcher_menu_key` to open a `display-menu` listing
  every app. The menu works on tmux below 3.2, where popups are unavailable.
- Conditional launch guard: `@launcher_<id>_if` runs a predicate before dispatch.
  When it fails, the key does nothing instead of opening a dead launcher. The
  scoped path is exported as `LAUNCHER_PATH` for the predicate to test.
- Project-root scoping: `@launcher_<id>_marker` (or the global `@launcher_marker`)
  walks up from the pane path, bounded by `@launcher_max_depth`, and launches at
  the directory holding the marker, falling back to the pane path.
- Argument prompt passthrough: `@launcher_<id>_prompt` routes the key through
  `command-prompt`, appending the typed value to the command (man topic, ssh host).
- App-group launch: `@launcher_<id>_group` opens several apps as a tiled dashboard
  in one key.
- Split-pane mode: `@launcher_<id>_mode split` opens the app beside your work.
- Remote-host launch: `@launcher_<id>_host` wraps the command in `ssh -t` for a
  remote box.
- Reuse existing window: `@launcher_<id>_reuse on` selects a matching window in
  window mode instead of opening a duplicate.
- Missing-command skip: `@launcher_skip_missing on` drops any app whose local
  command is not on PATH (remote apps are never probed).
- Per-app env vars and pre/exit hooks: `@launcher_<id>_env`, `@launcher_<id>_pre`,
  and `@launcher_<id>_exit` compose around the command (direnv, status refresh).
- fzf app picker: set `@launcher_picker_key` to choose an app with fzf in a popup.

### Changed

- Each app key now routes through a single `dispatch` path, so every launch mode
  shares one code path. All launches and tmux calls go through one seam, which the
  dry-run test suite asserts without a live tmux, a popup, or a real app.

## [1.0.1] - 2026-06-23

### Changed

- Self-audit for the family hardening pass. The popup launcher binds, captures
  the chosen command, and runs it without leaving a stray pane. Being an action
  plugin, it emits no status colors, so the tmux 3.7 format-expansion change does
  not apply. No code change needed.

## [1.0.0] - 2026-06-21

### Added

- Launch any TUI app in a popup or a window, scoped to the current pane's path,
  configured per app via @launcher_apps and per-app key, command, mode, name,
  and popup size options.
- lazygit (popup) and yazi (window) ship as working defaults; yazi uses a window
  because tmux popups lack passthrough for image previews.
- Version gating: popup mode uses display-popup on tmux 3.2 and up and falls back
  to a window on older tmux, so every binding works from tmux 1.9 up.
