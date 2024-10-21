#!/bin/zsh
# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo "Installing Brew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew analytics off
else
    echo "Brew is already installed"
fi

# Add homebrew to path if not already added
if ! command -v brew &> /dev/null; then
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

zsh -c "$(curl -fsSL https://raw.githubusercontent.com/conner-olsen/dotfiles/main/install-apps.sh)"
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/conner-olsen/dotfiles/main/install-desktop.sh)"
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/conner-olsen/dotfiles/main/install-terminal.sh)"
