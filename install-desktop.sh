#!/bin/zsh

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
echo "2. Install SketchyBar only"
echo "3. Custom settings"
read "installation_type?Enter your choice [1-3]: "

# Install Homebrew if not already installed
clear_screen
if ! command -v brew &> /dev/null; then
    progress "Installing Brew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1
    brew analytics off >/dev/null 2>&1
else
    success "Brew is already installed"
fi

# Add homebrew to path if not already added
if ! command -v brew &> /dev/null; then
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/conner/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install essentials based on installation type
if [[ $installation_type == 1 || $installation_type == 3 ]]; then
    clear_screen
    progress "Tapping Brew..."
    brew tap homebrew/cask-fonts >/dev/null 2>&1
    brew tap FelixKratz/formulae >/dev/null 2>&1
    brew tap koekeishiya/formulae >/dev/null 2>&1

    progress "Installing essential packages..."
    brew install yabai >/dev/null 2>&1
    brew install skhd >/dev/null 2>&1
    brew install borders >/dev/null 2>&1
    brew install lua >/dev/null 2>&1
    brew install switchaudio-osx >/dev/null 2>&1
    brew install nowplaying-cli >/dev/null 2>&1
    success "Essential packages installed"
fi

# Install SketchyBar
if [[ $installation_type == 1 || $installation_type == 2 ]]; then
    clear_screen
    progress "Installing SketchyBar..."
    brew install sketchybar >/dev/null 2>&1
    success "SketchyBar installed"
fi

# Install fonts
clear_screen
progress "Installing fonts..."
brew install --cask sf-symbols >/dev/null 2>&1
brew install font-meslo-for-powerlevel10k >/dev/null 2>&1
success "Fonts installed"

# Install Karabiner-Elements and custom bindings
if [[ $installation_type == 1 ]] || ( [[ $installation_type == 3 ]] && prompt_user "Do you want to install Karabiner-Elements and custom bindings?" ); then
    clear_screen
    if ! brew list karabiner-elements &> /dev/null; then
        progress "Installing Karabiner-Elements and custom bindings..."
        brew install karabiner-elements >/dev/null 2>&1
        success "Karabiner-Elements installed"
    else
        success "Karabiner-Elements is already installed"
    fi
    curl https://raw.githubusercontent.com/ARealConner/dotfiles/main/.config/karabiner/assets/complex_modifications/custom-remappings.json -o $HOME/.config/karabiner/assets/complex_modifications/custom-remappings.json >/dev/null 2>&1
    open /Applications/Karabiner-Elements.app
    echo "Open Karabiner-Elements, go to 'Complex Modifications' and click 'Add Predefined Rule' to install the keybindings"
    echo "INSTALL NOT YET COMPLETE: Press enter to continue"
    read
fi

# Install Raycast
if [[ $installation_type == 1 ]] || ( [[ $installation_type == 3 ]] && prompt_user "Do you want to install Raycast?" ); then
    clear_screen
    if ! brew list raycast &> /dev/null; then
        progress "Installing Raycast..."
        brew install raycast >/dev/null 2>&1
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
if [[ $installation_type == 1 ]] || ( [[ $installation_type == 3 ]] && prompt_user "Do you want to override macOS default settings?" ); then
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

# Installing Fonts
clear_screen
progress "Installing additional fonts..."
curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/latest/sketchybar-app-font.ttf -o $HOME/Library/Fonts/sketchybar-app-font.ttf >/dev/null 2>&1
mkdir -p $HOME/.config/sketchybar/plugins >/dev/null 2>&1
curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/latest/icon_map.sh -o $HOME/.config/sketchybar/plugins/icon_map.sh >/dev/null 2>&1
success "Additional fonts installed"

# Copying and checking out configuration files if not SketchyBar only installation
if [[ $installation_type != 2 ]]; then
    clear_screen
    progress "Planting Configuration Files..."
    rm -rf "$HOME/temp-dotfiles" >/dev/null 2>&1
    git clone https://github.com/ARealConner/dotfiles.git "$HOME/temp-dotfiles" >/dev/null 2>&1

    mkdir -p "$HOME/.config/backups" >/dev/null 2>&1
    timestamp=$(date +%Y%m%d%H%M%S)
    mkdir -p "$HOME/.config/backups/$timestamp" >/dev/null 2>&1

    # Backup existing configuration directories if they exist
    for dir in yabai skhd sketchybar borders; do
        if [ -d "$HOME/.config/$dir" ]; then
            mv "$HOME/.config/$dir" "$HOME/.config/backups/$timestamp/$dir" >/dev/null 2>&1
        fi
    done

    # Move configuration directories from the cloned repository if they exist
    for dir in yabai skhd borders; do
        if [ -d "$HOME/temp-dotfiles/.config/$dir" ]; then
            mv "$HOME/temp-dotfiles/.config/$dir" "$HOME/.config/$dir" >/dev/null 2>&1
        fi
    done

    rm -rf "$HOME/temp-dotfiles" >/dev/null 2>&1
    success "Configuration files planted"
fi

## Start with FelixKratz setup as a base. 
# Install SbarLua Plugin to use lua scripts in sketchybar
clear_screen
progress "Installing SbarLua Plugin..."
(git clone https://github.com/FelixKratz/SbarLua.git $HOME/tmp/SbarLua >/dev/null 2>&1 && cd $HOME/tmp/SbarLua/ >/dev/null 2>&1 && make install >/dev/null 2>&1 && rm -rf $HOME/tmp/SbarLua/ >/dev/null 2>&1)
success "SbarLua Plugin installed"

# Clone FelixKratz dotfiles
clear_screen
progress "Cloning Config..."
mkdir -p $HOME/tmp/dotfiles >/dev/null 2>&1
git clone https://github.com/FelixKratz/dotfiles.git $HOME/tmp/dotfiles >/dev/null 2>&1
mv $HOME/tmp/dotfiles/.config/sketchybar $HOME/.config/sketchybar >/dev/null 2>&1
rm -rf $HOME/tmp/dotfiles >/dev/null 2>&1
success "Config cloned"

## Add custom configuration to sketchybar:
clear_screen
progress "Customizing SketchyBar configuration..."
# Change apple icon to the arch linux icon
sed -i '' 's/apple = "􀣺"/apple = "󰣇"/g' $HOME/.config/sketchybar/icons.lua
# Charge bar settings
if [ -f "$HOME/.config/sketchybar/bar.lua" ]; then
  if ! grep -q "margin=10," "$HOME/.config/sketchybar/bar.lua"; then
    sed -i '' '/sbar.bar({/,/})/{/})/i\
    margin=10,\
    shadow=on,\
    border_color=colors.white,\
    corner_radius=9,\
    border_width=2,
  }' "$HOME/.config/sketchybar/bar.lua"
  fi
fi

sed -i '' \
    -e 's/\(black = \)0x[0-9a-fA-F]\{8\}/\10xff282828/' \
    -e 's/\(white = \)0x[0-9a-fA-F]\{8\}/\10xffebdbb2/' \
    -e 's/\(red = \)0x[0-9a-fA-F]\{8\}/\10xffcc241d/' \
    -e 's/\(green = \)0x[0-9a-fA-F]\{8\}/\10xff98971a/' \
    -e 's/\(blue = \)0x[0-9a-fA-F]\{8\}/\10xff458588/' \
    -e 's/\(yellow = \)0x[0-9a-fA-F]\{8\}/\10xffd79921/' \
    -e 's/\(orange = \)0x[0-9a-fA-F]\{8\}/\10xffd65d0e/' \
    -e 's/\(magenta = \)0x[0-9a-fA-F]\{8\}/\10xffb16286/' \
    -e 's/\(grey = \)0x[0-9a-fA-F]\{8\}/\10xff928374/' \
    -e 's/\(transparent = \)0x[0-9a-fA-F]\{8\}/\10x00000000/' \
    -e 's/\(bg = \)0xf02c2e34/\10xff282828/' \
    -e 's/\(bg1 = \)0x[0-9a-fA-F]\{8\}/\10xff3c3836/' \
    -e 's/\(bg2 = \)0x[0-9a-fA-F]\{8\}/\10xff504945/' \
    $HOME/.config/sketchybar/colors.lua

sed -i '' 's/os.date("%H:%M")/os.date("%I:%M")/' $HOME/.config/sketchybar/items/calendar.lua
success "SketchyBar configuration customized"

# Start Services if not SketchyBar only installation
if [[ $installation_type != 2 ]]; then
    clear_screen
    progress "Starting Services (grant permissions)..."
    # start yabai
    yabai --start-service >/dev/null 2>&1
    skhd --start-service >/dev/null 2>&1
    brew services start borders >/dev/null 2>&1

    progress "Adding yabai to sudoers..."
    echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai >/dev/null 2>&1

    csrutil status
    error "Important!: To gain full functionality, you must disable SIP."
    echo -n "Press Enter to open guide..."
    read
    open "https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection"

    echo "Notice: every time you update yabai, you must run the following command to update the sha256 in the sudoers file: suyabai"
    success "Services started"
fi

# Start SketchyBar
clear_screen
progress "Starting SketchyBar..."
brew services start sketchybar >/dev/null 2>&1
success "SketchyBar started"

# Installation Summary
clear_screen
success "Installation Complete!"
echo "Summary:"
echo "- Installed essential packages: $([[ $installation_type == 1 || $installation_type == 3 ]] && echo "Yes" || echo "No")"
echo "- Installed SketchyBar: $([[ $installation_type == 1 || $installation_type == 2 ]] && echo "Yes" || echo "No")"
echo "- Installed Karabiner-Elements and custom bindings: $([[ $installation_type == 1 ]] && echo "Yes" || ([[ $installation_type == 3 ]] && prompt_user "Do you want to install Karabiner-Elements and custom bindings?" && echo "Yes" || echo "No"))"
echo "- Installed Raycast: $([[ $installation_type == 1 ]] && echo "Yes" || ([[ $installation_type == 3 ]] && prompt_user "Do you want to install Raycast?" && echo "Yes" || echo "No"))"
echo "- Overridden macOS default settings: $([[ $installation_type == 1 ]] && echo "Yes" || ([[ $installation_type == 3 ]] && prompt_user "Do you want to override macOS default settings?" && echo "Yes" || echo "No"))"
echo "- Copied configuration files: $([[ $installation_type != 2 ]] && echo "Yes" || echo "No")"
echo "- Started services: $([[ $installation_type != 2 ]] && echo "Yes" || echo "No")"
echo ""
echo "Notice: Your previous .config files are backed up in $HOME/.config/backups/$timestamp"

echo "Notice: You may need to restart your computer for all changes to take effect."