#!/bin/zsh

# Function to display progress message
progress() {
    echo "\033[1m\033[32m[*]\033[0m $1"
}

# Function to display success message
success() {
    echo "\033[1m\033[32m[+]\033[0m $1"
}

# Function to clear the console screen
clear_screen() {
    echo "\033[2J\033[H"
}

# Install SketchyBar
clear_screen
progress "Installing SketchyBar..."
brew install sketchybar >/dev/null 2>&1
success "SketchyBar installed"

# Installing Fonts
clear_screen
progress "Installing additional fonts..."
curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/latest/sketchybar-app-font.ttf -o $HOME/Library/Fonts/sketchybar-app-font.ttf >/dev/null 2>&1
mkdir -p $HOME/.config/sketchybar/plugins >/dev/null 2>&1
curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/latest/icon_map.sh -o $HOME/.config/sketchybar/plugins/icon_map.sh >/dev/null 2>&1
success "Additional fonts installed"

# Install SbarLua Plugin to use lua scripts in sketchybar
clear_screen
progress "Installing SbarLua Plugin..."
(git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && cd /tmp/SbarLua/ && make install && rm -rf /tmp/SbarLua/) 2>&1
success "SbarLua Plugin installed"

# Clone FelixKratz dotfiles
clear_screen
progress "Cloning Config..."
mkdir -p $HOME/tmp/dotfiles 
git clone https://github.com/FelixKratz/dotfiles.git $HOME/tmp/dotfiles 2>&1

# Backup existing configuration directories if they exist
mkdir -p "$HOME/.config/backups" >/dev/null 2>&1
timestamp=$(date +%Y%m%d%H%M%S)
mkdir -p "$HOME/.config/backups/$timestamp" >/dev/null 2>&1

# Backup existing configuration directories if they exist
if [ -d "$HOME/.config/sketchybar" ]; then
  mv "$HOME/.config/sketchybar" "$HOME/.config/backups/$timestamp/sketchybar" >/dev/null 2>&1
fi


# Move the new config to the home directory
mv $HOME/tmp/dotfiles/.config/sketchybar $HOME/.config/sketchybar 2>&1
rm -rf $HOME/tmp/dotfiles 2>&1
success "Config cloned"

# Add custom configuration to sketchybar
clear_screen
progress "Customizing SketchyBar configuration..."
# Change apple icon to the arch linux icon
sed -i '' 's/apple = "􀣺"/apple = "󰣇"/g' $HOME/.config/sketchybar/icons.lua
# Charge bar settings
if [ -f "$HOME/.config/sketchybar/bar.lua" ]; then
  if ! grep -q "margin=10," "$HOME/.config/sketchybar/bar.lua"; then
    sed -i '' '/sbar.bar({/,/})/{/})/i\
    margin=6,\
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

# Start SketchyBar
clear_screen
progress "Starting SketchyBar..."
brew services start sketchybar >/dev/null 2>&1
success "SketchyBar started"

clear_screen
success "SketchyBar installation complete!"
