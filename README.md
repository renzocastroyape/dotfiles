# dotfiles

Personal configuration for macOS (Apple Silicon).

The applications mentioned in this repository are the **everyday** ones, and their versions were defined based on the GitHub Runner to be used: [macOS 27 — xcode-27-arm64](./github-runner.md). This ensures the local environment stays consistent with the CI/CD environment.

## Contents

| File | Description |
| --- | --- |
| [`bootstrap.sh`](./bootstrap.sh) | Silent, idempotent installation of the whole environment |
| [`Brewfile`](./Brewfile) | Homebrew packages (`rbenv`, `nvm`, `mise`, `uv`, `gnupg`, `gh`, `apm`, `copilot-cli`) for `brew bundle` |
| [`.zshrc`](./.zshrc) | Zsh configuration: Oh My Zsh, Homebrew, rbenv, nvm, mise, uv/Python and GPG |
| [`.gitconfig`](./.gitconfig) | Git configuration |
| [`.env.template`](./.env.template) | Variables template (`GIT_USER_NAME`, `GIT_USER_EMAIL`); copy to `.env`, which is git-ignored |
| [`.gitignore`](./.gitignore) | Ignores macOS files (`.DS_Store`, `._*`) and secrets (`.env`) |
| [`github-runner.md`](./github-runner.md) | Reference versions from the GitHub Actions runner |

## Installation

Before starting, set up your email on GitHub (**Settings → Access → Emails**):

- Add your corporate email (as primary or backup).
- Enable **Keep my email address private** and take note of the GitHub-provided private address (e.g. `randomcode+username@users.noreply.github.com`) — it is the one used as `GIT_USER_EMAIL` in all the following steps.

Clone the repo, fill in the `.env` and run the bootstrap:

```sh
git clone https://github.com/renzocastroyape/dotfiles.git
cd dotfiles

cp .env.template .env   # fill in GIT_USER_NAME and GIT_USER_EMAIL

./bootstrap.sh
```

The script is **silent and idempotent** (it can be re-run; it skips what is already installed) and performs:

1. **Homebrew** (`NONINTERACTIVE` installation) and the [`Brewfile`](./Brewfile) packages via `brew bundle`.
2. **Oh My Zsh** *(optional, asks for confirmation)*: unattended install and creates `~/.oh-my-zsh_config` from the official template.
3. **Ruby 3.4.12** (rbenv) + RubyGems 4.0.23, **Node.js 24** (nvm) and **Python 3.15** (uv).
4. **Git**: `user.name`/`user.email` from `.env`, `credential.helper`, and VS Code as editor *(optional, asks for confirmation)*.
5. **GPG**: generates an RSA 4096 key (expires in 1 year, no passphrase) and configures commit and tag signing (`user.signingkey`, `commit.gpgsign`, `tag.gpgSign`).
6. **SSH**: generates `~/.ssh/id_ed25519_yape`, adds it to the keychain and configures `~/.ssh/config` (`AddKeysToAgent`/`UseKeychain`).
7. **`~/.netrc`** *(optional, asks for confirmation for each entry)*: can add an `sdk facephi` entry using `NETRC_FACEPHI_HOST`/`NETRC_FACEPHI_LOGIN`/`NETRC_FACEPHI_PASSWORD` and an `sdk io-baas` entry using `NETRC_IO_BAAS_HOST`/`NETRC_IO_BAAS_LOGIN`/`NETRC_IO_BAAS_PASSWORD` from `.env`. If `~/.netrc` already exists, the script reports it, preserves its contents, and appends only entries whose hosts are not already present. The file is secured with `600` permissions.
8. Adds `source "<repo>/.zshrc"` to `~/.zshrc` (creating it if it does not exist).

At the end it prints the commands to copy the GPG and SSH public keys (`| pbcopy`) and paste them into GitHub → Settings.

## Prerequisites

Everyday tools that `.zshrc` assumes are installed — **all of them are installed by `bootstrap.sh`**; the commands below are the manual reference. Versions match the [xcode-27-arm64](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md) runner:

### Oh My Zsh

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Homebrew (requires ADMIN user)

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Ruby v3.4.12 (rbenv)

```sh
brew install rbenv
rbenv global 3.4.12
gem update --system 4.0.23
```

### Node.js v24.x (nvm)

```sh
brew install nvm
mkdir ~/.nvm
nvm install 24
```

### mise

```sh
brew install mise
# or
curl -fsSL https://mise.run/zsh | sh
```

### Python 3.15 (uv)

The system Python (`/usr/bin/python3`, 3.9.6, unsupported) is not used. Python is managed by [uv](https://docs.astral.sh/uv/):

```sh
brew install uv
uv python install 3.15
```

Python 3.15 is not available globally; it is activated only in the projects that need it:

```sh
uv venv --python 3.15
source .venv/bin/activate
```

## Git + GPG/SSH configuration

`bootstrap.sh` performs it automatically, taking `GIT_USER_NAME` and `GIT_USER_EMAIL` from the `.env`:

```sh
# Identity and credentials
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global credential.helper 'cache --timeout=3600'
git config --global core.editor "code --wait"

# GPG: RSA 4096 key (expires in 1y) + commit/tag signing
gpg --batch --generate-key ...        # unattended, no passphrase
git config --global user.signingkey "$GPG_KEY_ID"
git config --global commit.gpgsign true
git config --global tag.gpgSign true
git config --global gpg.program gpg
gpg --armor --export "$GPG_KEY_ID" | pbcopy   # paste into GitHub → Settings → GPG keys

# SSH: ed25519 key + keychain + ~/.ssh/config
ssh-keygen -t ed25519 -C "$GIT_USER_EMAIL" -f ~/.ssh/id_ed25519_yape
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_yape
pbcopy < ~/.ssh/id_ed25519_yape.pub   # paste into GitHub → Settings → SSH keys
```

## Reference versions

Taken from the [xcode-27-arm64](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md) runner:

- Node.js 24.x · Ruby 3.4.12 · Python 3.15
- Homebrew · RubyGems 4.0.23 · Bundler 4.0.23
- Git · Git LFS · GitHub CLI · GnuPG

## About Python

macOS 27 and Command Line Tools 27.2 ship with python 3.9.6.

• End of support: Python 3.9 reached EOL in October 2025, so it no longer receives security patches.
• It is old: 3.9.6 was released in June 2021. Since then several CVEs have been fixed in the standard library, for example in `tarfile`, `urllib`, `email`, `zipfile` and `ssl`.
• Apple maintains it: the Python at `/usr/bin/python3` is shipped by Apple with Xcode or the CLT. Apple usually backports patches to that version, but does not upgrade it to a newer major version. It cannot and should not be upgraded by hand.

What to do:

1. Do not touch the system Python. Some macOS and Xcode tools rely on it.
2. Install a current version separately, for example with `brew install python@3.13` or with `pyenv` or `uv`. Pick a supported version, 3.12 or newer.
3. Use virtual environments (`python3 -m venv`) for your projects.
4. If you want `python3` to point to the new version, put `/opt/homebrew/bin` before `/usr/bin` in the PATH.
