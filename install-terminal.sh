## Terminal
brew install kitty
echo "Select the theme you want to install"
kitten themes

## zsh4humans
if ! grep -q "z4h" "$HOME/.zshrc"; then
  echo -e "\\033[31mzsh4humans is not installed. Installing...\\033[0m"
  echo -e "\\033[31mImportant: You must re-run this script after the installation is complete.\\033[0m"
  echo -e "\\033[31mzsh4humans initiates a new shell, which will stop the script from continuing.\\033[0m"
  echo -e "\\033[31mPress enter to continue...\\033[0m"
  read

  if command -v curl >/dev/null 2>&1; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install)"
  else
    sh -c "$(wget -O- https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install)"
  fi

  echo -e "\\033[31mPlease re-run the script to continue with the remaining steps.\\033[0m"
  exit 1
else
  echo -e "\\033[32mzsh4humans is already installed. Skipping installation.\\033[0m"
fi

# Rest of the script...


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

exec zsh
z4h install

## lazyvim install:
echo "Installing lazyvim"
# for lazyvim
brew install node
brew install neovim
brew install lazygit
brew install ripgrep
brew install fd

# Remove existing backups and then move the current directories to backup locations
rm -rf $HOME/.config/nvim.bak
mv $HOME/.config/nvim $HOME/.config/nvim.bak

rm -rf $HOME/.local/share/nvim.bak
mv $HOME/.local/share/nvim $HOME/.local/share/nvim.bak

rm -rf $HOME/.local/state/nvim.bak
mv $HOME/.local/state/nvim $HOME/.local/state/nvim.bak

rm -rf $HOME/.cache/nvim.bak
mv $HOME/.cache/nvim $HOME/.cache/nvim.bak

# Clone the LazyVim starter kit into the .config/nvim directory
git clone https://github.com/LazyVim/starter $HOME/.config/nvim

# Remove the .git directory to prevent it from being a git repository
rm -rf $HOME/.config/nvim/.git

# Open nvim to finish the setup
nvim