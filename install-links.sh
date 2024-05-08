#!/bin/zsh

link_folder() {
	rm -rf ~/$1
	ln -s ~/Documents/GitHub/dotfiles/$1/ ~/$1
}

link_config() {
	link_folder ".config/$1"
}

link_file() {
	rm -f ~/$1
	ln -s ~/Documents/GitHub/dotfiles/$1 ~/$1
}

## Folders
link_folder ".ssh"
link_folder "Library/Application\ Support/Code/User/profiles"
link_folder "Library/Application\ Support/Cursor/User/profiles"

## Files
link_file ".gitconfig"
link_file ".p10k.zsh"
link_file ".zprofile"
link_file ".zshenv"
link_file ".zshrc"
link_file ".ideavimrc"
link_file "Library/Application\ Support/Code/User/settings.json"
link_file "Library/Application\ Support/Cursor/User/settings.json"

## Configs
link_config "borders"
link_config "btop"
link_config "karabiner"
link_config "kitty"
link_config "nnn"
link_config "nvim"
link_config "sketchybar"
link_config "skhd"
link_config "svim"
link_config "yabai"
