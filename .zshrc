export GPG_TTY=$(tty)

export PATH="$HOME/.local/bin:$PATH"

# ohmyz.sh configuration
#```
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
#```
# Load Oh My Zsh config only if present (its install is optional in bootstrap.sh)
[ -f "$HOME/.oh-my-zsh_config" ] && source "$HOME/.oh-my-zsh_config"

# Homebrew (require ADMIN USER)
#```
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#```
HOMEBREW_PREFIX="$(brew --prefix)"
eval "$($HOMEBREW_PREFIX/bin/brew shellenv zsh)"

# Ruby v3.4.12 + Gem v4.0.23
#```
# brew install rbenv
# rbenv global 3.4.12
# gem update --system 4.0.23
#```
# rbenv environment setup
eval "$(rbenv init - zsh)"

# NodeJS v24.x
#```
# brew install nvm
# mkdir ~/.nvm
# nvm install 24
#```
export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"  # This loads nvm
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# mise
#```
# brew install mise
# o
# curl -fsSL https://mise.run/zsh | sh
#```
eval "$(mise activate zsh)"

# Python 3.15 (uv)
#```
# brew install uv
# uv python install 3.15
#```
# Python 3.15 NO es global: se activa por proyecto con `uv venv --python 3.15`
# Usar los certificados del sistema (proxies corporativos)
export UV_SYSTEM_CERTS=1
