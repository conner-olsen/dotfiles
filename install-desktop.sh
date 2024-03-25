#!/bin/zsh

# Install xCode cli tools
# echo "Installing commandline tools..."
# xcode-select --install

# Homebrew
## Install
if ! command -v brew &> /dev/null; then
    echo "Installing Brew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew analytics off
fi

## Add homebrew to path if not already added:
if ! command -v brew &> /dev/null; then
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/conner/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

## Taps
echo "Tapping Brew..."
brew tap homebrew/cask-fonts
brew tap FelixKratz/formulae
brew tap koekeishiya/formulae

### Essentials
brew install yabai
brew install wget
brew install gh
brew install skhd
brew install sketchybar
brew install borders

### Nice to have
brew install raycast
echo "Open Raycast and follow the setup instructions"
open /Applications/Raycast.app/ 
echo -n "Press Enter to continue..."
read

### Set up keybindings
brew install karabiner-elements
open /Applications/Karabiner-Elements.app
echo "Open Karabiner-Elements, go to 'Complex Modifications' and click 'Add Predefined Rule' to install the keybindings"

echo -n "Press Enter to continue..."
read

### Fonts
brew install --cask sf-symbols
# brew install --cask font-hack-nerd-font
# brew install --cask font-jetbrains-mono
# brew install --cask font-fira-code
brew install front-meslo-for-powerlevel10k

# macOS Settings
echo "Changing macOS defaults..."
# Disable writing .DS_Store files on network and external volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
# Disable spanning displays when using Spaces
defaults write com.apple.spaces spans-displays -bool false
# Automatically hide the dock
defaults write com.apple.dock autohide -bool true
# Disable most recently used (MRU) spaces in Mission Control
defaults write com.apple.dock "mru-spaces" -bool "false"
# Disable window opening and closing animations
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
# Disable the quarantine dialog for downloaded applications
defaults write com.apple.LaunchServices LSQuarantine -bool false
# Disable natural scrolling direction
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
# Set the key repeat rate to the fastest setting
defaults write NSGlobalDomain KeyRepeat -int 1
# Disable automatic spelling correction
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
# Show all file extensions in Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Hide the menu bar
defaults write NSGlobalDomain _HIHideMenuBar -bool true
# Set the highlight color to a specific RGB value
defaults write NSGlobalDomain AppleHighlightColor -string "0.65098 0.85490 0.58431"
# Set the accent color to blue
defaults write NSGlobalDomain AppleAccentColor -int 1
# Set the default location for screenshots to the "Screenshots" directory in "$HOME/Desktop"
mkdir -p "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true
# Set the screenshot format to PNG
defaults write com.apple.screencapture type -string "png"
# Disable all Finder animations
defaults write com.apple.finder DisableAllAnimations -bool true
# Show hidden files in Finder
defaults write com.apple.Finder AppleShowAllFiles -bool true
# Set the default search scope to the current folder
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Show the full POSIX path as the Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
# Set the default view style to List view
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# Hide the status bar in Finder
defaults write com.apple.finder ShowStatusBar -bool false
# Enable dragging windows with gesture
defaults write -g NSWindowShouldDragOnGesture YES

# Copying and checking out configuration files
echo "Planting Configuration Files..."
echo "Cloning Config"
git clone https://github.com/ARealConner/dotfiles.git "$HOME/temp-dotfiles"

mkdir -p $HOME/.config/backups
timestamp=$(date +%Y%m%d%H%M%S)
mkdir -p $HOME/.config/backups/$timestamp
mv $HOME/.config/sketchybar $HOME/.config/backups/$timestamp/sketchybar
mv $HOME/.config/yabai $HOME/.config/backups/$timestamp/yabai
mv $HOME/.config/skhd $HOME/.config/backups/$timestamp/skhd
mv $HOME/.config/karabiner $HOME/.config/backups/$timestamp/karabiner
mv $HOME/.config/borders $HOME/.config/backups/$timestamp/borders
mv /temp-dotfiles/.config/sketchybar $HOME/.config/sketchybar
mv /temp-dotfiles/.config/yabai $HOME/.config/yabai
mv /temp-dotfiles/.config/skhd $HOME/.config/skhd
mv /temp-dotfiles/.config/karabiner $HOME/.config/karabiner
mv /temp-dotfiles/.config/borders $HOME/.config/borders
rm -rf "$HOME/tmp-dotfiles"

# Installing Fonts
# git clone git@github.com:shaunsingh/SFMono-Nerd-Font-Ligaturized.git /tmp/SFMono_Nerd_Font
# mv /tmp/SFMono_Nerd_Font/* $HOME/Library/Fonts
# rm -rf /tmp/SFMono_Nerd_Font/


curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/latest/sketchybar-app-font.ttf -o $HOME/Library/Fonts/sketchybar-app-font.ttf
mkdir -p $HOME/.config/sketchybar/plugins
curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/latest/icon_map.sh -o $HOME/.config/sketchybar/plugins/icon_map.sh

# curl https://raw.githubusercontent.com/ARealConner/dotfiles/main/.config/karabiner/assets/complex_modifications/custom-remappings.json -o $HOME/.config/karabiner/assets/complex_modifications/custom-remappings.json

# Start Services
echo "Starting Services (grant permissions)..."
# start yabai
yabai --start-service
skhd --start-service
brew services start sketchybar
brew services start borders

csrutil status

echo "Adding yabai to sudoers..."
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai
echo "Installation complete...\n"
echo "Important!: To gain full functionality, you must disable SIP."
echo -n "Press Enter to open guide..."
read
open "https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection"

echo "Notice: "every time you update yabai, you must run the following command to update the sha256 in the sudoers file: suyabai"
