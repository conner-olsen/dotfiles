## Terminal
brew install kitty
echo "Select the theme you want to install"
kitten themes

## zsh4humans
echo "Installing zsh4humans"
if command -v curl >/dev/null 2>&1; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install)"
else
  sh -c "$(wget -O- https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install)"
fi

## CodeWhisperer
echo "Installing CodeWhisperer"
brew install codewhisperer
cw integrations install input-method
echo "Open CodeWhisperer and follow the setup instructions"
open /Applications/CodeWhisperer.app

echo "Press enter to continue..."
read

## Nice to have
echo "Installing nice to have tools"
brew install btop
brew install eza
brew install nnn
brew install gh

## dotfiles
echo "Installing dotfiles"
curl https://raw.githubusercontent.com/ARealConner/dotfiles/main/.zshrc -o $HOME/.zshrc >/dev/null 2>&1

source $HOME/.zshrc

## lazyvim install:
echo "Installing lazyvim"
# for lazyvim
brew install node
brew install neovim
brew install lazygit
brew install ripgrep
brew install fd

# required
mv $HOME/.config/nvim{,.bak}

# optional but recommended
mv $HOME/.local/share/nvim{,.bak}
mv $HOME/.local/state/nvim{,.bak}
mv $HOME/.cache/nvim{,.bak}

git clone https://github.com/LazyVim/starter $HOME/.config/nvim

rm -rf $HOME/.config/nvim/.git

nvim