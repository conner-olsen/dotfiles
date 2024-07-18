#!/bin/zsh

# Function to display instruction message
instruction() {
    echo "\033[1;333m$1\033[0m"
}

# Function to display progress message
progress() {
    echo "\033[1m\033[32m[*]\033[0m $1"
}

# Function to display error message
error() {
    echo "\033[1m\033[31m[!]\033[0m $1"
}

# Function to display success message
success() {
    echo "\033[1m\033[32m[+]\033[0m $1"
}

# Function to clear the console screen
clear_screen() {
    echo "\033[2J\033[H"
}

# Function to prompt user for yes/no input
prompt_user() {
    while true; do
        read "response?$1 [y/n]: "
        case $response in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Prompt user for installation type
clear_screen
echo "Choose installation type:"
echo "1. Install everything"
echo "2. Custom settings"
read "installation_type?Enter your choice [1-2]: "

# Install essentials based on installation type
if [[ $installation_type == 1 || $installation_type == 2 ]]; then
    clear_screen
    progress "Tapping Brew..."
    brew tap homebrew/cask-fonts
    brew tap FelixKratz/formulae
    brew tap koekeishiya/formulae

    progress "Installing essential packages..."
    brew install yabai
    brew install skhd
    brew install borders
    brew install lua
    brew install switchaudio-osx
    brew install nowplaying-cli
    success "Essential packages installed"
fi

# Install fonts
clear_screen
progress "Installing fonts..."
brew install --cask sf-symbols
brew install font-meslo-for-powerlevel10k
success "Fonts installed"

# Install Karabiner-Elements and custom bindings
if [[ $installation_type == 1 ]] || ( [[ $installation_type == 2 ]] && prompt_user "Do you want to install Karabiner-Elements and custom bindings?" ); then
    clear_screen
    if ! brew list karabiner-elements &> /dev/null; then
        progress "Installing Karabiner-Elements and custom bindings..."
        brew install karabiner-elements
        success "Karabiner-Elements installed"
    else
        success "Karabiner-Elements is already installed"
    fi
    mkdir -p $HOME/.config/karabiner/assets/complex_modifications
    curl https://raw.githubusercontent.com/ARealConner/dotfiles/main/.config/karabiner/assets/complex_modifications/custom-remappings.json -o $HOME/.config/karabiner/assets/complex_modifications/custom-remappings.json
    open /Applications/Karabiner-Elements.app
    instruction "Open Karabiner-Elements, go to 'Complex Modifications' and click 'Add Predefined Rule' to install the keybindings"
    instruction "INSTALL NOT YET COMPLETE: Press enter to continue"
    read
fi

# Install Raycast
if [[ $installation_type == 1 ]] || ( [[ $installation_type == 2 ]] && prompt_user "Do you want to install Raycast?" ); then
    clear_screen
    if ! brew list raycast &> /dev/null; then
        progress "Installing Raycast..."
        brew install raycast
        echo "Open Raycast and follow the setup instructions"
        open /Applications/Raycast.app/ 
        echo -n "Press Enter to continue..."
        read
        success "Raycast installed"
    else
        success "Raycast is already installed"
    fi
fi

# Override macOS default settings
if [[ $installation_type == 1 ]] || ( [[ $installation_type == 2 ]] && prompt_user "Do you want to override macOS default settings?" ); then
    clear_screen
    progress "Changing macOS defaults..."
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
    # disable press-and-hold for keys in favor of key repeat
    defaults write -g ApplePressAndHoldEnabled -bool false
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
    success "macOS default settings updated"
fi

# Install SketchyBar
if [[ $installation_type == 1 ]] || ( [[ $installation_type == 2 ]] && prompt_user "Do you want to install SketchyBar?" ); then
    clear_screen
    progress "Installing SketchyBar..."
    curl -L https://raw.githubusercontent.com/arealconner/dotfiles/main/install-sketchybar.sh | zsh
    success "SketchyBar installation complete"
fi

# Copying and checking out configuration files
clear_screen
progress "Planting Configuration Files..."
rm -rf "$HOME/temp-dotfiles"
git clone https://github.com/ARealConner/dotfiles.git "$HOME/temp-dotfiles"

mkdir -p "$HOME/.config/backups"
timestamp=$(date +%Y%m%d%H%M%S)
mkdir -p "$HOME/.config/backups/$timestamp"

# Backup existing configuration directories if they exist
for dir in yabai skhd borders; do
    if [ -d "$HOME/.config/$dir" ]; then
        mv "$HOME/.config/$dir" "$HOME/.config/backups/$timestamp/$dir"
    fi
done

# Move configuration directories from the cloned repository if they exist
for dir in yabai skhd borders; do
    if [ -d "$HOME/temp-dotfiles/.config/$dir" ]; then
        mv "$HOME/temp-dotfiles/.config/$dir" "$HOME/.config/$dir"
    fi
done

rm -rf "$HOME/temp-dotfiles"
success "Configuration files planted"

# Start Services
clear_screen
progress "Starting Services (grant permissions)..."
# start yabai
yabai --start-service
skhd --start-service
brew services start borders

progress "Adding yabai to sudoers..."
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai

csrutil status
error "Important!: To gain full functionality, you must disable SIP."
echo -n "Press Enter to open guide..."
read
open "https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection"

echo "Notice: every time you update yabai, you must run the following command to update the sha256 in the sudoers file: suyabai"
success "Services started"

# Installation Summary
clear_screen
success "Installation Complete!"
echo "Summary:"
echo "- Installed essential packages: $([[ $installation_type == 1 || $installation_type == 2 ]] && echo "Yes" || echo "No")"
echo "- Installed SketchyBar: $([[ $installation_type == 1 ]] && echo "Yes" || ([[ $installation_type == 2 ]] && prompt_user "Do you want to install SketchyBar?" && echo "Yes" || echo "No"))"
echo "- Installed Karabiner-Elements and custom bindings: $([[ $installation_type == 1 ]] && echo "Yes" || ([[ $installation_type == 2 ]] && prompt_user "Do you want to install Karabiner-Elements and custom bindings?" && echo "Yes" || echo "No"))"
echo "- Installed Raycast: $([[ $installation_type == 1 ]] && echo "Yes" || ([[ $installation_type == 2 ]] && prompt_user "Do you want to install Raycast?" && echo "Yes" || echo "No"))"
echo "- Overridden macOS default settings: $([[ $installation_type == 1 ]] && echo "Yes" || ([[ $installation_type == 2 ]] && prompt_user "Do you want to override macOS default settings?" && echo "Yes" || echo "No"))"
echo "- Copied configuration files: Yes"
echo "- Started services: Yes"
echo ""
echo "Notice: Your previous .config files are backed up in $HOME/.config/backups/$timestamp"

echo "Notice: You may need to restart your computer for all changes to take effect."
