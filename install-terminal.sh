#!/bin/zsh

# install required font
brew install font-meslo-for-powerlevel10k
brew install font-sf-mono
brew install font-sf-pro

# install kitty
if [[ -z "$KITTY_WINDOW_ID" ]]; then
  brew install kitty
fi

# if kitty.conf does not exist, create it
if [[ ! -f ~/.config/kitty/kitty.conf ]]; then
    expect <<EOF
      spawn kitty +edit-config
      expect "kitty.conf"
      send "\033:wq!\r"
      expect eof
EOF
fi

# set font to MesloLGS NF
sed -i '' \
    -e 's/# font_family      monospace/font_family      MesloLGS NF/' \
    -e 's/font_family      .*/font_family      MesloLGS NF/' \
    $HOME/.config/kitty/kitty.conf

if [[ -z "$KITTY_WINDOW_ID" ]]; then
  nohup kitty zsh -c "$(curl -fsSL https://raw.githubusercontent.com/arealconner/dotfiles/main/install-terminal.sh)" > /dev/null 2>&1 &
  echo "Script restarted in kitty"
  exit 0
fi

nohup kitty kitten themes > /dev/null 2>&1 &
echo "Select a theme then press enter to continue"
read

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

## CodeWhisperer
echo "Installing amazon-q"
brew install --cask amazon-q
q integrations install input-method
echo "Open Amazon Q and follow the setup instructions"
echo 'If "q integrations install input-method" fails, run the following command in default mac terminal, it is copied to your clipboard'
echo "q integrations install input-method" | pbcopy
open "/Applications/Amazon Q.app"
echo "Press enter to continue..."
read

## Nice to have
echo "Installing nice to have tools"
brew install btop
brew install eza
brew install nnn
brew install gh
brew install wget2

## dotfiles
echo "Installing dotfiles"
curl https://raw.githubusercontent.com/ARealConner/dotfiles/main/.zshrc -o $HOME/.zshrc

## lazyvim install:
echo "Installing lazyvim"
# for lazyvim
brew install python
brew install lua
brew install luarocks
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
nohup kitty nvim > /dev/null 2>&1 &
echo "Launching nvim to finish the setup"
echo "Press enter to continue..."
read


echo "setup complete"
exec zsh
