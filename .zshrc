# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# Q pre block. Keep at the top of this file.
## Functions
# Update sudoer file for yabai, run each time yabai updates.
function suyabai () {
    YABAI_BIN=$(which yabai)
    SHA256=$(shasum -a 256 "$YABAI_BIN" | awk '{print $1}')
    LINE="$(whoami) ALL=(root) NOPASSWD: sha256:${SHA256} ${YABAI_BIN} --load-sa"

    echo "$LINE" | sudo tee /private/etc/sudoers.d/yabai > /dev/null
}

# Sketchybar interactivity overloads and overload add to install-apps.sh
function brew() {
  local script_path="/Users/conner/Documents/GitHub/dotfiles/install-apps.sh"
  
  if [[ -f "$script_path" ]]; then
    if [[ "$1" == "install" && $# -ge 2 ]]; then
      # Use arrays to preserve argument boundaries
      local -a packages=()
      local -a cask_packages=()
      local is_cask=false
      
      shift  # Remove 'install'
      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--cask" ]]; then
          is_cask=true
        elif $is_cask; then
          cask_packages+=("$1")
        else
          packages+=("$1")
        fi
        shift
      done
      
      # Install regular packages
      if [[ ${#packages[@]} -gt 0 ]]; then
        command brew install "${packages[@]}"
        if [ $? -eq 0 ]; then
          for package in "${packages[@]}"; do
            if ! grep -q "brew install $package" "$script_path"; then
              if grep -q "^$
## Installations" "$script_path"; then
                sed -i '' '/^$/{
                    N
                    /\n## Installations/i\
brew install '"$package"'
                }' "$script_path"
              else
                echo "brew install $package" >> "$script_path"
                echo "" >> "$script_path"
              fi
            fi
          done
        fi
      fi
      
      # Install cask packages
      if [[ ${#cask_packages[@]} -gt 0 ]]; then
        command brew install --cask "${cask_packages[@]}"
        if [ $? -eq 0 ]; then
          for package in "${cask_packages[@]}"; do
            if ! grep -q "brew install --cask $package" "$script_path"; then
              if grep -q "^$
## Installations" "$script_path"; then
                sed -i '' '/^$/{
                    N
                    /\n## Installations/i\
brew install --cask '"$package"'
                }' "$script_path"
              else
                echo "brew install --cask $package" >> "$script_path"
                echo "" >> "$script_path"
              fi
            fi
          done
        fi
      fi
      
    elif [[ "$1" == "uninstall" && $# -ge 2 ]]; then
      local -a packages=()
      local -a cask_packages=()
      local is_cask=false
      
      shift  # Remove 'uninstall'
      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--cask" ]]; then
          is_cask=true
        elif $is_cask; then
          cask_packages+=("$1")
        else
          packages+=("$1")
        fi
        shift
      done
      
      # Uninstall regular packages
      if [[ ${#packages[@]} -gt 0 ]]; then
        command brew uninstall "${packages[@]}"
        if [ $? -eq 0 ]; then
          for package in "${packages[@]}"; do
            sed -i '' "/brew install $package/d" "$script_path"
          done
        fi
      fi
      
      # Uninstall cask packages
      if [[ ${#cask_packages[@]} -gt 0 ]]; then
        command brew uninstall --cask "${cask_packages[@]}"
        if [ $? -eq 0 ]; then
          for package in "${cask_packages[@]}"; do
            sed -i '' "/brew install --cask $package/d" "$script_path"
          done
        fi
      fi
      
    else
      command brew "$@"
    fi
  else
    command brew "$@"
  fi
  
  if [[ $* =~ "upgrade" ]] || [[ $* =~ "update" ]] || [[ $* =~ "outdated" ]] || [[ "$1" == "install" ]] || [[ "$1" == "uninstall" ]]; then
    sketchybar --trigger brew_update
  fi
}

## zsh4humans configuration:
# Personal Zsh configuration file. It is strongly recommended to keep all
# shell customization and configuration (including exported environment
# variables such as PATH) in this file or in files sourced from it.
#
# Documentation: https://github.com/romkatv/zsh4humans/blob/v5/README.md.

# Periodic auto-update on Zsh startup: 'ask' or 'no'.
# You can manually run `z4h update` to update everything.
zstyle ':z4h:' auto-update      'ask'
# Ask whether to auto-update this often; has no effect if auto-update is 'no'.
zstyle ':z4h:' auto-update-days '7'

# Keyboard type: 'mac' or 'pc'.
zstyle ':z4h:bindkey' keyboard  'mac'

# Don't start tmux.
zstyle ':z4h:' start-tmux       no

# Mark up shell's output with semantic information.
zstyle ':z4h:' term-shell-integration 'yes'

# Right-arrow key accepts one character ('partial-accept') from
# command autosuggestions or the whole thing ('accept')?
zstyle ':z4h:autosuggestions' forward-char 'accept'

# Recursively traverse directories when TAB-completing files.
zstyle ':z4h:fzf-complete' recurse-dirs 'no'

# Enable direnv to automatically source .envrc files.
zstyle ':z4h:direnv'         enable 'yes'
# Show "loading" and "unloading" notifications from direnv.
zstyle ':z4h:direnv:success' notify 'yes'

# Enable ('yes') or disable ('no') automatic teleportation of z4h over
# SSH when connecting to these hosts.
zstyle ':z4h:ssh:example-hostname1'   enable 'yes'
zstyle ':z4h:ssh:*.example-hostname2' enable 'no'
# The default value if none of the overrides above match the hostname.
zstyle ':z4h:ssh:*'                   enable 'no'

# Send these files over to the remote host when connecting over SSH to the
# enabled hosts.
zstyle ':z4h:ssh:*' send-extra-files '~/.nanorc' '~/.env.zsh'

# Clone additional Git repositories from GitHub.
#
# This doesn't do anything apart from cloning the repository and keeping it
# up-to-date. Cloned files can be used after `z4h init`. This is just an
# example. If you don't plan to use Oh My Zsh, delete this line.
z4h install ohmyzsh/ohmyzsh || return

# Install or update core components (fzf, zsh-autosuggestions, etc.) and
# initialize Zsh. After this point console I/O is unavailable until Zsh
# is fully initialized. Everything that requires user interaction or can
# perform network I/O must be done above. Everything else is best done below.

# Disable built-in-highlighting
zstyle ':z4h:zsh-syntax-highlighting' channel 'none'

# Use fast-syntax-highlighting instead
z4h install zdharma-continuum/fast-syntax-highlighting || return

# Add z command.
z4h install agkozak/zsh-z || return

z4h init || return

# Extend PATH.
path=(~/bin $path)

# Export environment variables.
export GPG_TTY=$TTY
export PATH="/opt/homebrew/anaconda3/bin:$PATH"

# Source additional local files if they exist.
z4h source ~/.env.zsh

# Use additional Git repositories pulled in with `z4h install`.
#
# This is just an example that you should delete. It does nothing useful.
# z4h source ohmyzsh/ohmyzsh/lib/diagnostics.zsh  # source an individual file
# z4h load   ohmyzsh/ohmyzsh/plugins/emoji-clock  # load a plugin
z4h load zdharma-continuum/fast-syntax-highlighting
z4h load agkozak/zsh-z

# Define key bindings.
z4h bindkey undo Ctrl+/   Shift+Tab  # undo the last command line change
z4h bindkey redo Option+/            # redo the last undone command line change

z4h bindkey z4h-cd-back    Shift+Left   # cd into the previous directory
z4h bindkey z4h-cd-forward Shift+Right  # cd into the next directory
z4h bindkey z4h-cd-up      Shift+Up     # cd into the parent directory
z4h bindkey z4h-cd-down    Shift+Down   # cd into a child directory
z4h bindkey z4h-accept-line Enter       # enable zsh-no-ps2 / disable ps2

# Autoload functions.
autoload -Uz zmv

# Define functions and completions.
function md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }
compdef _directories md

# Define named directories: ~w <=> Windows home directory on WSL.
[[ -z $z4h_win_home ]] || hash -d w=$z4h_win_home

# Define aliases.
alias ls="eza"
alias wget="wget2"
alias python="python3" 
alias pip="pip3"
alias ..="cd .."
# alias vim="nvim"
alias vi="nvim"
alias nnn="nnn -de"

# Add environment variables.
export PATH="/opt/homebrew/anaconda3/bin:$PATH"
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"

# TODO: Figure out why these two are now needed
export SDKROOT="$(xcrun --show-sdk-path)"
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

export CPPFLAGS="-I/opt/homebrew/opt/openjdk@17/include"

# Make mac use brew installed ruby: 
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# Add flags to existing aliases.
alias tree='tree -a -I .git'

# Set shell options: http://zsh.sourceforge.net/Doc/Release/Options.html.
setopt glob_dots     # no special treatment for file names with a leading dot
setopt no_auto_menu  # require an extra TAB press to open the completion menu

export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

  # Python
if command -v pyenv 1>/dev/null 2>&1; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:/Library/Developer/CommandLineTools/usr/bin:$PATH"
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

# bun completions
[ -s "/Users/conner/.bun/_bun" ] && source "/Users/conner/.bun/_bun"

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"
