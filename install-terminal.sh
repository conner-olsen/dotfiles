### Terminal
brew install kitty
echo "Select the theme you want to install"
kitten themes

### zsh4humans
if command -v curl >/dev/null 2>&1; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install)"
else
  sh -c "$(wget -O- https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install)"
fi

brew install codewhisperer
cw integrations install input-method
echo "Open CodeWhisperer and follow the setup instructions"
open /Applications/CodeWhisperer.app

echo "Press enter to continue..."
read

brew install neovim

### Nice to have
brew install btop
brew install eza
brew install nnn
brew install gh

## for lazyvim
brew install lazygit
brew install ripgrep
brew install fd

curl https://raw.githubusercontent.com/ARealConner/dotfiles/main/.zshrc -o $HOME/.zshrc >/dev/null 2>&1

## lazyvim install:
# required
mv ~/.config/nvim{,.bak}

# optional but recommended
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}

git clone https://github.com/LazyVim/starter ~/.config/nvim

rm -rf ~/.config/nvim/.git

nvim

source $HOME/.zshrc