#!/bin/zsh

link_folder() {
    if [ -d ~/Documents/GitHub/dotfiles/$1/ ]; then
        rm -rf ~/$1
        ln -s ~/Documents/GitHub/dotfiles/$1/ ~/$1
    else
        echo "Source folder ~/Documents/GitHub/dotfiles/$1/ does not exist"
    fi
}

link_file() {
    if [ -f ~/Documents/GitHub/dotfiles/$1 ]; then
        rm -f ~/$1
        ln -s ~/Documents/GitHub/dotfiles/$1 ~/$1
    else
        echo "Source file ~/Documents/GitHub/dotfiles/$1 does not exist"
    fi
}

link_config() {
	link_folder ".config/$1"
}

## Folders
link_folder ".ssh"
link_folder "Library/Application Support/Cursor/User/profiles"

## Files
link_file ".gitconfig"
link_file ".p10k.zsh"
link_file ".zprofile"
link_file ".zshenv"
link_file ".zshrc"
link_file ".ideavimrc"
link_file "Library/Application Support/Cursor/User/settings.json"
link_file "Library/Application Support/Cursor/User/globalStorage/storage.json"

## Configs
link_config "borders"
link_config "btop"
link_config "karabiner"
link_config "kitty"
# link_config "nnn"
link_config "nvim"
link_config "sketchybar"
link_config "skhd"
link_config "svim"
link_config "yabai"
