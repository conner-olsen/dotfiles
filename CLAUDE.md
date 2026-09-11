# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A macOS dotfiles repository. Files here are symlinked into `$HOME` via `install-links.sh`, so edits in this repo are live configuration changes.

## Symlink Architecture

`install-links.sh` is the central linking mechanism. It creates symlinks from `~/Documents/GitHub/dotfiles/` to `~`:
- **Individual files** (`.zshrc`, `.gitconfig`, `.p10k.zsh`, `.zprofile`, `.zshenv`, `.ideavimrc`) are symlinked directly
- **Config directories** (`.config/nvim`, `.config/sketchybar`, `.config/skhd`, `.config/yabai`, etc.) are symlinked as whole directories
- **Cursor IDE** profile folders and databases are also symlinked

This means modifying any config file in this repo immediately affects the running system. Be careful with changes to service configs (yabai, skhd, sketchybar) as they may require service restarts to take effect.

## Install Scripts

All install scripts are zsh and designed to run both locally and via `curl | zsh` from raw GitHub URLs. They are interactive (use `read` prompts) and cannot be tested headlessly.

- `install.sh` — master installer: ensures Homebrew, then runs apps, desktop, terminal installers
- `install-apps.sh` — `brew install` list for all applications; the `.zshrc` `brew()` wrapper auto-adds/removes entries here on install/uninstall
- `install-desktop.sh` — interactive installer for yabai, skhd, borders, karabiner, raycast, macOS defaults; has "install everything" and "custom" modes
- `install-terminal.sh` — kitty, zsh4humans, neovim/LazyVim, Amazon Q, CLI tools
- `install-sketchybar.sh` — SketchyBar + SbarLua bridge + FelixKratz config base + customizations
- `install-links.sh` — creates all symlinks (run locally from the cloned repo)
- `repair-sketchybar.sh` — rebuilds SbarLua when Lua or SketchyBar versions drift (e.g., after `brew upgrade`); supports `--check` (dry run) and `--force` flags
- `check-homebrew-install.sh` — ensures Homebrew is installed and on PATH

## Key Integration Points

**brew() wrapper in .zshrc**: Custom shell function that intercepts `brew install`/`brew uninstall` to auto-update `install-apps.sh` and triggers `sketchybar --trigger brew_update`. When editing `.zshrc` brew-related logic, the script path is hardcoded to `/Users/conner/Documents/GitHub/dotfiles/install-apps.sh`.

**Yabai + sudoers**: Yabai requires a sudoers entry with its SHA256 hash. The `suyabai` function in `.zshrc` regenerates this. The entry must be updated after every yabai binary update.

**SketchyBar Lua bridge**: SketchyBar config is Lua-based (via SbarLua). The `.so` lives at `~/.local/share/sketchybar_lua/sketchybar.so`. When Lua or SketchyBar binaries change, the bridge breaks and `repair-sketchybar.sh` must be run. Build metadata is tracked in `~/.local/share/sketchybar_lua/build-info`.

**Yabai signals SketchyBar**: `yabairc` adds a signal to trigger `sketchybar --trigger window_focus` on window focus changes, coupling the two services.

## Config Details

- **Shell**: zsh4humans (z4h) framework with fast-syntax-highlighting, zsh-z, Oh My Zsh
- **Neovim**: LazyVim starter with custom plugins in `.config/nvim/lua/plugins/`; extras in `plugins/extras/`
- **Window management**: Yabai (BSP layout, zero gaps/padding) + SKHD (alt+hjkl for focus, hyper key for layout ops) + Borders (round style, 2px width)
- **SketchyBar**: Lua config based on FelixKratz/dotfiles; items in `.config/sketchybar/items/`, widgets in `items/widgets/`, C helpers in `helpers/event_providers/`
- **Terminal**: Kitty with MesloLGS NF font
