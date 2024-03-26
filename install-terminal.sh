### Terminal
brew install kitty
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

read -p "Press enter to continue..."

brew install neovim

### Nice to have
brew install btop
brew install lazygit
brew install eza
brew install nnn
brew install gh

curl https://raw.githubusercontent.com/ARealConner/dotfiles/main/.zshrc -o $HOME/.zshrc >/dev/null 2>&1

