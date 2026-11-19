#!/usr/bin/env bash
#
# bootstrap.sh — silent, idempotent setup of the tools documented in .zshrc:
#   Homebrew, Oh My Zsh, rbenv (Ruby 3.4.12), nvm (Node.js 24), mise,
#   uv (Python 3.15), Git + SSH configuration.
# It also wires this repo's .zshrc into ~/.zshrc via a `source` line.
#
# Usage: ./bootstrap.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUBY_VERSION="3.4.12"
RUBYGEMS_VERSION="4.0.23"
NODE_VERSION="24"
PYTHON_VERSION="3.15"

SSH_KEY="$HOME/.ssh/id_ed25519_yape"

log()  { printf '==> %s\n' "$1"; }
skip() { printf '    %s (already installed, skipping)\n' "$1"; }
fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

# Ask the user a yes/no question; defaults to "no" (also when non-interactive)
confirm() {
  local reply=""
  read -r -p "==> $1 [y/N] " reply || true
  [[ "$reply" =~ ^[Yy]$ ]]
}

# --- Load user settings from .env -----------------------------------------
# GIT_USER_NAME and GIT_USER_EMAIL live in .env (copy .env.template to .env)
[ -f "$DOTFILES_DIR/.env" ] || fail "Missing $DOTFILES_DIR/.env (copy .env.template to .env and fill it in)"
# shellcheck disable=SC1091
. "$DOTFILES_DIR/.env"
[ -n "${GIT_USER_NAME:-}" ]  || fail "GIT_USER_NAME is not set in .env"
[ -n "${GIT_USER_EMAIL:-}" ] || fail "GIT_USER_EMAIL is not set in .env"

# --- Homebrew (requires ADMIN user) --------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null
else
  skip "Homebrew"
fi

# Load brew into this shell
eval "$(/opt/homebrew/bin/brew shellenv)"
HOMEBREW_PREFIX="$(brew --prefix)"

# --- Brew packages (rbenv, nvm, mise, uv) ---------------------------------
log "Installing Brewfile packages (rbenv, nvm, mise, uv, gnupg, gh, apm, copilot-cli)"
brew bundle --file="$DOTFILES_DIR/Brewfile" --quiet >/dev/null

# --- Oh My Zsh (optional) ---------------------------------------------------
if confirm "Install and configure Oh My Zsh?"; then
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended >/dev/null
  else
    skip "Oh My Zsh"
  fi

  # .zshrc sources ~/.oh-my-zsh_config; create it from the Oh My Zsh template if missing
  if [ ! -f "$HOME/.oh-my-zsh_config" ]; then
    log "Creating ~/.oh-my-zsh_config from Oh My Zsh template"
    OMZ_TEMPLATE="$HOME/.oh-my-zsh/templates/zshrc.zsh-template"
    if [ -f "$OMZ_TEMPLATE" ]; then
      cp "$OMZ_TEMPLATE" "$HOME/.oh-my-zsh_config"
    else
      curl -fsSL \
        https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/templates/zshrc.zsh-template \
        -o "$HOME/.oh-my-zsh_config"
    fi
  fi
else
  log "Skipping Oh My Zsh"
fi

# --- Ruby via rbenv --------------------------------------------------------
eval "$(rbenv init - bash)"
if ! rbenv versions --bare 2>/dev/null | grep -qx "$RUBY_VERSION"; then
  log "Installing Ruby $RUBY_VERSION (this may take a while)"
  rbenv install --skip-existing "$RUBY_VERSION" >/dev/null 2>&1
else
  skip "Ruby $RUBY_VERSION"
fi
rbenv global "$RUBY_VERSION"
if [ "$(gem --version)" != "$RUBYGEMS_VERSION" ]; then
  log "Updating RubyGems to $RUBYGEMS_VERSION"
  gem update --system "$RUBYGEMS_VERSION" --silent >/dev/null
else
  skip "RubyGems $RUBYGEMS_VERSION"
fi

# --- Node.js via nvm -------------------------------------------------------
mkdir -p "$HOME/.nvm"
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
if ! nvm ls "$NODE_VERSION" >/dev/null 2>&1; then
  log "Installing Node.js $NODE_VERSION"
  nvm install "$NODE_VERSION" >/dev/null 2>&1
else
  skip "Node.js $NODE_VERSION"
fi

# --- Python via uv ---------------------------------------------------------
# Python 3.15 is NOT global: activate it per project with `uv venv --python 3.15`
log "Installing Python $PYTHON_VERSION (uv)"
uv python install "$PYTHON_VERSION" --quiet

# --- Git configuration -----------------------------------------------------
log "Configuring Git"
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global credential.helper 'cache --timeout=3600'
if confirm "Set VS Code as Git editor (core.editor \"code --wait\")?"; then
  git config --global core.editor "code --wait"
fi

# --- GPG key ----------------------------------------------------------------
# Unattended equivalent of `gpg --full-generate-key`:
#   RSA and RSA, 4096 bits, 1y expiration, no comment, no passphrase
if ! gpg --list-secret-keys "$GIT_USER_EMAIL" >/dev/null 2>&1; then
  log "Generating GPG key for $GIT_USER_EMAIL"
  gpg --batch --quiet --generate-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $GIT_USER_NAME
Name-Email: $GIT_USER_EMAIL
Expire-Date: 1y
%commit
EOF
  log "GPG public key (add it to GitHub -> Settings -> GPG keys):"
  gpg --armor --export "$GIT_USER_EMAIL"
else
  skip "GPG key for $GIT_USER_EMAIL"
fi

# Sign commits and tags with the generated GPG key
log "Configuring Git commit/tag signing"
GPG_KEY_ID="$(gpg --list-secret-keys --with-colons "$GIT_USER_EMAIL" | awk -F: '/^sec/{print $5; exit}')"
git config --global user.signingkey "$GPG_KEY_ID"
git config --global commit.gpgsign true
git config --global tag.gpgSign true
git config --global gpg.program gpg

log "Public key (add it to GitHub -> Settings -> GPG keys)"
log "Copy your GPG public key to the clipboard with:"
log "  gpg --armor --export $GPG_KEY_ID | pbcopy"



# --- SSH key ---------------------------------------------------------------
if [ ! -f "$SSH_KEY" ]; then
  log "Generating SSH key $SSH_KEY"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  touch "$HOME/.ssh/config"

  # Generate a new SSH key if it doesn't exist
  ssh-keygen -t ed25519 -C "$GIT_USER_EMAIL" -f "$SSH_KEY" -N "" -q
  
  # Add the private key to the ssh-agent
  eval "$(ssh-agent -s)"
  ssh-add --apple-use-keychain "$SSH_KEY" >/dev/null 2>&1
  
  # Copy the public key to the clipboard
  log "Public key (add it to GitHub -> Settings -> SSH keys)"
  log "Copy your SSH public key to the clipboard with:"
  log "  cat \"${SSH_KEY}.pub\" | pbcopy"
else
  skip "SSH key $SSH_KEY"
fi

# Configure ~/.ssh/config to auto-load keys into the agent and the keychain
if ! grep -q "AddKeysToAgent yes" "$HOME/.ssh/config" 2>/dev/null; then
  log "Configuring ~/.ssh/config"
  cat >> "$HOME/.ssh/config" <<EOF
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile $SSH_KEY
EOF
else
  skip "~/.ssh/config"
fi

# --- ~/.netrc entries (optional) --------------------------------------------
# Credentials are read from .env. Existing entries are preserved.
if [ -f "$HOME/.netrc" ]; then
  log "~/.netrc already exists; preserving it and adding only missing entries"
else
  log "~/.netrc does not exist; it will be created if an entry is selected"
fi

netrc_has_host() {
  [ -f "$HOME/.netrc" ] &&
    awk -v host="$1" '$1 == "machine" && $2 == host { found = 1 } END { exit !found }' "$HOME/.netrc"
}

add_netrc_entry() {
  local label="$1" host="$2" login="$3" password="$4"

  if [ -z "$host" ] || [ -z "$login" ] || [ -z "$password" ]; then
    log "Skipping $label entry: required NETRC_* values are missing from .env"
  elif netrc_has_host "$host"; then
    skip "$label entry for $host (already present in ~/.netrc)"
  else
    if [ -s "$HOME/.netrc" ] && [ "$(tail -c 1 "$HOME/.netrc" | wc -l | tr -d ' ')" -eq 0 ]; then
      printf '\n' >> "$HOME/.netrc"
    fi
    (umask 077; printf '# %s\nmachine %s\n  login %s\n  password %s\n' \
      "$label" "$host" "$login" "$password" >> "$HOME/.netrc")
    chmod 600 "$HOME/.netrc"
    log "Added $label entry for $host to ~/.netrc"
  fi
}

if confirm "Configure optional 'sdk facephi' entry in ~/.netrc?"; then
  add_netrc_entry "sdk facephi" \
    "${NETRC_FACEPHI_HOST:-}" "${NETRC_FACEPHI_LOGIN:-}" "${NETRC_FACEPHI_PASSWORD:-}"
else
  log "Skipping sdk facephi entry"
fi

if confirm "Configure optional 'sdk io-baas' entry in ~/.netrc?"; then
  add_netrc_entry "sdk io-baas" \
    "${NETRC_IO_BAAS_HOST:-}" "${NETRC_IO_BAAS_LOGIN:-}" "${NETRC_IO_BAAS_PASSWORD:-}"
else
  log "Skipping sdk io-baas entry"
fi

# --- Wire this repo's .zshrc into ~/.zshrc ---------------------------------
SOURCE_LINE="source \"$DOTFILES_DIR/.zshrc\""
if [ ! -f "$HOME/.zshrc" ] || ! grep -qxF "$SOURCE_LINE" "$HOME/.zshrc"; then
  log "Adding dotfiles source line to ~/.zshrc"
  {
    printf '\n# Load dotfiles (%s)\n' "$DOTFILES_DIR"
    printf '%s\n' "$SOURCE_LINE"
  } >> "$HOME/.zshrc"
else
  skip "~/.zshrc source line"
fi

log "Done. Open a new terminal or run: source ~/.zshrc"
