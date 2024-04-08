link_folder() {
    rm -rf ~/$1
    ln -s ~/Documents/GitHub/dotfiles/$1/ ~/$1
}

link_file() {
    rm -f ~/$1
    ln -s ~/Documents/GitHub/dotfiles/$1 ~/$1
}

## Folders
link_folder ".config"
link_folder ".cursor"
link_folder ".gitkraken"
link_folder ".gk"
link_folder ".ssh"
link_folder ".vscode"

## Files
link_file ".gitconfig"
link_file ".p10k.zsh"
link_file ".zprofile"
link_file ".zshenv"
link_file ".zshrc"
link_file ".ideavimrc"
