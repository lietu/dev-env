#!/usr/bin/env bash
#
# Script configuration
#

# Edit these if you don't want these things installed or want something more
PACMAN_EXTRAS="discord vivaldi vivaldi-ffmpeg-codecs sublime-merge sublime-text"
AUR_EXTRAS="jetbrains-toolbox 1password insomnia stripe-cli-bin google-cloud-sdk azure-cli-bin git-credential-manager-bin"
SNAP_EXTRAS="slack spotify"

CREDENTIAL_STORE="plaintext"  # https://github.com/GitCredentialManager/git-credential-manager/blob/main/docs/credstores.md


#########################
#                       #
# Script initialization #
#                       #
#########################

# No need to touch anything after this point

USER=$(who -m | cut -d' ' -f1)
USER_HOME=$(bash -c "cd ~$(printf %q "$USER") && pwd")
SCRIPTNAME=$(basename "$0")
start_time="$(date +%s)"

#
# Utilities
#

function check_root {
  if [[ "$EUID" != "0" ]]; then
    echo "Missing permissions"
    echo "Run: sudo ${SCRIPTNAME}"
    exit 1
  fi
}


function label {
  local msg="$*"

  line=$(echo "$msg" | sed 's/./-/g')
  echo -e "\x1b[1;32m"
  echo "/-$line-\\"
  echo "| $msg |"
  echo "\\-$line-/"
  echo -en "\e[0m"
  echo ""
}

#
# Steps
#

function install_keys {
  # Sublime HQ
  curl -O https://download.sublimetext.com/sublimehq-pub.gpg
  pacman-key --add sublimehq-pub.gpg
  pacman-key --lsign-key 8A8F901A
  rm sublimehq-pub.gpg
}

function setup_basic_deps {
  label "Setting up basic dependencies"

  pacman --noconfirm --needed -S \
    base-devel \
    bpython \
    btop \
    byobu \
    docker \
    go \
    jre-openjdk-headless \
    npm \
    pnpm \
    python-pip \
    python-poetry \
    xpra \
    yay \
    # This is intentional
}


function setup_extras {
  label "Setting up extras"

  pacman --noconfirm --needed -S $PACMAN_EXTRAS
  sudo -u "$USER" yay --noconfirm -S $AUR_EXTRAS
  snap install $SNAP_EXTRAS
}

function setup_repos {
  label "Setting up extra repos"

  # Sublime HQ
  if ! grep "sublime-text" /etc/pacman.conf; then
    echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" >> /etc/pacman.conf
  fi

  # Update databases
  pacman -Syy
}

function setup_services {
  label "Enabling services"
  services="docker sshd"

  echo "Enabling and starting: $services"

  for service in $services; do
    systemctl enable "$service"
    systemctl start "$service"
  done
}

function setup_user {
  label "Setting up user account"
  gpasswd -a "$USER" "docker"
}

function setup_env {
  label "Setting up local environment"

  echo "Preparing ~/.local/bin"
  sudo -u "$USER" mkdir -p "$USER_HOME/.local/bin"

  echo "Preparing ~/.ssh/authorized_keys"
  sudo -u "$USER" mkdir -p "$USER_HOME/.ssh"
  sudo -u "$USER" touch "$USER_HOME/.ssh/authorized_keys"
  chmod 0700 "$USER_HOME/.ssh"
  chmod 0600 "$USER_HOME/.ssh/authorized_keys"

  echo "Preparing ~/go"
  sudo -u "$USER" mkdir -p "$USER_HOME/go/bin"

  echo "Preparing docker gcloud helper"
  sudo -u "$USER" gcloud auth configure-docker

  echo "Setting up Git Credential Manager"
  sudo -u "$USER" git-credential-manager-core configure
  sudo -u "$USER" git config --global credential.credentialStore "$CREDENTIAL_STORE"

  echo "Preparing environment variables"

  if ! grep "dev_setup.sh" "$USER_HOME/.zshrc"; then
    cat << EOF >> "$USER_HOME/.zshrc"

# start dev_setup.sh

# The next line updates PATH for the Google Cloud SDK.
source opt/google-cloud-sdk/path.zsh.inc

# The next line enables shell command completion for gcloud.
source /opt/google-cloud-sdk/completion.zsh.inc

export DOCKER_BUILDKIT=1
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:/opt/sublime_merge"
export PATH="$PATH:/opt/sublime_text"
export PATH="$PATH:$HOME/go/bin"

# end dev_setup.sh

EOF
    # End cat
  fi

  if ! grep "dev_setup.sh" "$USER_HOME/.bashrc"; then
    cat << EOF >> "$USER_HOME/.bashrc"

# start dev_setup.sh

# The next line updates PATH for the Google Cloud SDK.
source /opt/google-cloud-sdk/path.bash.inc

# The next line enables shell command completion for gcloud.
source /opt/google-cloud-sdk/completion.bash.inc

export DOCKER_BUILDKIT=1
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:/opt/sublime_merge"
export PATH="$PATH:/opt/sublime_text"
export PATH="$PATH:$HOME/go/bin"

# end dev_setup.sh

EOF
    # End cat
  fi

  cat <<EOF > /etc/docker/daemon.json
{
  "ipv6": false
}
EOF

  # Reload
  source "$USER_HOME/.bashrc"
}

function install_tools {
  label "Installing development tools"

  npm install -g firebase-tools

  sudo -u "$USER" go install github.com/codegangsta/gin@latest
  sudo -u "$USER" go install github.com/lietu/go-pre-commit@latest

  pip install pre-commit
}


#
# Script flow
#

check_root

echo -e "\x1b[1;31m"
echo "/-------------------------------\\"
echo "|                               |"
echo "| Development environment setup |"
echo "|                               |"
echo "\\-------------------------------/"
echo -en "\e[0m"
echo ""

echo
echo "Setting up for development for the user ${USER}"
echo

echo "MAKE SURE YOUR SYSTEM IS FULLY UPDATED BEFORE STARTING"
echo "Run: sudo pacman -Syu"
echo "And then REBOOT"
echo

echo "Press Enter to continue, or Ctrl+C to abort."
read

install_keys
setup_repos
setup_basic_deps
setup_extras
setup_services
setup_user
setup_env
install_tools

# Finalization
end_time="$(date +%s)"

elapsed=$(( end_time - start_time ))
label "Done in $elapsed seconds"

echo
echo "When you have random tools you want to add to your PATH, add them to ~/.local/bin"
echo "You can now append any SSH keys you want to be authorized on this machine to ~/.ssh/authorized_keys"
echo "It's a good idea to log out and log back in to refresh your environment now."
echo
echo "To finish setting up the tools, run:"
echo ""
echo "  git config --global user.name \"Your Name\""
echo "  git config --global user.email \"your.name@email.com\""
echo ""
echo "  gcloud init"
echo "  gcloud auth login"
echo
echo "✈️ Thank you for flying LietuAir ✈️"
echo
