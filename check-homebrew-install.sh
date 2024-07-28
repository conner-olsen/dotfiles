#!/bin/zsh 
# Install Homebrew if not already installed 
if ! command -v brew &> /dev/null; then
    echo "Installing Brew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Brew is already installed"
fi

# Add homebrew to path if not already added
if ! command -v brew &> /dev/null; then
    echo "Adding brew to path"
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Brew is already added to path"
fi

brew analytics off
