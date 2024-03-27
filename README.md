# Dotfiles

This repository contains my personal configuration files for various tools and applications that I use on my macOS system.

## Installation

To install and set up the different components of the dotfiles, run the corresponding command for each component you wish to install. (you must have brew installed)

### Desktop Setup

Installs and sets up the my desktop environment with tools like Yabai, SKHD, Karabiner-Elements with custom bindings, Raycast, and overrides macOS default settings. It includes a installer to allow for customization. 

```bash
curl -L https://raw.githubusercontent.com/arealconner/dotfiles/main/install-desktop.sh | zsh
```

### SketchyBar

Installs SketchyBar and my configuration. I used https://github.com/FelixKratz/dotfiles as a base so most of the credit goes to him.

```bash
curl -L https://raw.githubusercontent.com/arealconner/dotfiles/main/install-sketchybar.sh | zsh
```

### Terminal Setup

Sets up the terminal environment with tools like Kitty, zsh4humans, CodeWhisperer, neovim, and my .zshrc.

```bash
curl -L https://raw.githubusercontent.com/arealconner/dotfiles/main/install-terminal.sh | zsh
```

### Application Installations

This install all the applications I use on macOS. It is mainly just for me to have a quick way to install everything I need on new machines, so it's not really recommended for anyone else. 

```bash
curl -L https://raw.githubusercontent.com/arealconner/dotfiles/main/install-apps.sh | zsh
```

### Install All
This is not recommended for anyone else as this will essentially install my entire setup. It's just a convenience script for me to install everything I need on a new machine.
```bash
curl -L https://raw.githubusercontent.com/arealconner/dotfiles/main/install.sh | zsh
```

## Screenshots

![Single Window](screenshots/single-window.png)
*Single Window*

![Multiple Windows](screenshots/multiple-windows.png)
*Multiple Windows*

## Disclaimer

These scripts are provided as-is and should be used at your own risk. They are intended for my own personal use and may or may not be compatible with other systems.
