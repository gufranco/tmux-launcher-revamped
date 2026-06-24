# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
