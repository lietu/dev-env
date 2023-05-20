#!/usr/bin/env bash
#
# Script configuration
#

# Edit these if you don't want these things installed or want something more
APT_EXTRAS="kde-full exa firefox sublime-merge sublime-text vivaldi-stable fonts-jetbrains-mono google-cloud-cli spice-vdagent spice-webdavd virtualbox-guest-utils virtualbox-guest-x11"
TASKS="kde-desktop ssh-server"

CREDENTIAL_STORE="plaintext"  # https://github.com/GitCredentialManager/git-credential-manager/blob/main/docs/credstores.md

# Locale configuration
export LANG=en_US.UTF-8
export LANGUAGE=en_US
export LC_ALL=en_US.UTF-8
export LC_NUMERIC=en_IE.UTF-8
export LC_TIME=en_CA.UTF-8
export LC_MONETARY=en_IE.UTF-8
export LC_PAPER=en_IE.UTF-8
export LC_NAME=en_IE.UTF-8
export LC_ADDRESS=en_IE.UTF-8
export LC_TELEPHONE=en_IE.UTF-8
export LC_MEASUREMENT=en_IE.UTF-8
export TIME_STYLE="+%Y-%m-%d %H:%M:%S"

#########################
#                       #
# Script initialization #
#                       #
#########################

# No need to touch anything after this point

USER=$(who -m | cut -d' ' -f1)
GROUP=$(groups $USER | cut -d':' -f2 | cut -d' ' -f2)
USER_HOME=$(bash -c "cd ~$(printf %q "$USER") && pwd")
SCRIPTNAME=$(basename "$0")
start_time="$(date +%s)"

export _MAXNUM=10
export DEBIAN_FRONTEND="noninteractive"
export DEB_PYTHON_INSTALL_LAYOUT=deb
export POETRY_HOME="$USER_HOME/.local/poetry"

# Abort on error, it's easier to fix errors you can see
set -e

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

function setup_basic_deps {
  label "Setting up APT sources"

  cat << EOF > /etc/apt/sources.list
deb mirror://mirrors.ubuntu.com/mirrors.txt jammy main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt jammy-updates main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt jammy-backports main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt jammy-security main restricted universe multiverse
EOF

  label "Installing apt-fast"
  
  add-apt-repository -y ppa:apt-fast/stable
  apt-get update
  apt-get -y install apt-fast

  # Configuring higher number of simultaneous connections
  sed -Ei "s@^_MAXNUM=[0-9]+@_MAXNUM=${_MAXNUM}@g" /etc/apt-fast.conf

  label "Updating system and setting up basic dependencies"

  apt-fast upgrade -y

  apt-fast install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    tasksel \
    build-essential \
    lsb-release \
    apt-transport-https \
    btop \
    bpython \
    xpra \
    wget \
    ubuntu-keyring \
    python3.11 \
    python3.11-venv \
    python3-distutils \
    openjdk-19-jre \
    golang-1.18 \
    golang-go \
    # This is intentional
}

function install_keys {
  # Sublime HQ
  curl https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/sublimehq-archive.gpg

  # Google Cloud
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

  # Docker
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor > /usr/share/keyrings/docker-archive-keyring.gpg

  # Vivaldi
  curl https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor > /usr/share/keyrings/vivaldi.gpg

  # MongoDB
  curl -fsSL https://pgp.mongodb.com/server-6.0.asc | gpg --dearmor > /usr/share/keyrings/mongodb-server-6.0.gpg
}

function setup_repos {
  label "Setting up extra repos"

  # Sublime HQ
  echo "deb https://download.sublimetext.com/ apt/stable/" > /etc/apt/sources.list.d/sublime-text.list

  # Google Cloud
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list

  # Docker
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

  # Vivaldi
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/vivaldi.gpg] https://repo.vivaldi.com/archive/deb/ stable main" > /etc/apt/sources.list.d/vivaldi.list

  # MongoDB
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-6.0.list

  # NodeSource (also runs apt-get update)
  curl -sL https://deb.nodesource.com/setup_18.x | bash -
}

function setup_docker {
  apt-fast install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
}

function setup_mongodb {
  apt-fast install -y mongodb-org

  # Version pinning
  echo "mongodb-org hold" | sudo dpkg --set-selections
  echo "mongodb-org-database hold" | sudo dpkg --set-selections
  echo "mongodb-org-server hold" | sudo dpkg --set-selections
  echo "mongodb-mongosh hold" | sudo dpkg --set-selections
  echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
  echo "mongodb-org-tools hold" | sudo dpkg --set-selections
}

function setup_node {
  apt-fast install -y --no-install-recommends nodejs
  npm install -g pnpm yarn
}

function setup_rust {
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y 
}

function setup_gcm {
  wget https://github.com/git-ecosystem/git-credential-manager/releases/download/v2.1.2/gcm-linux_amd64.2.1.2.deb
  dpkg -i gcm-linux_amd64.2.1.2.deb
  rm gcm-linux_amd64.2.1.2.deb
}

function setup_python {
  update-alternatives --install /usr/bin/python python "/usr/bin/python3.11" 10
  
  # Setup pip
  curl https://bootstrap.pypa.io/get-pip.py | python

  # Setup poetry
  POETRY_URL="https://install.python-poetry.org"

  mkdir -p "${POETRY_HOME}"
  chown -R "${USER}":"${GROUP}" "${POETRY_HOME}"

  su "${USER}" -c "curl -sSL ${POETRY_URL} | python"
  # Create the env file manually; installers prior to 1.2.0 created this by default
  su "${USER}" -c "echo \"export PATH=\\\"${POETRY_HOME}/bin:\\\$PATH\\\"\" > \"${POETRY_HOME}/env\""

  chmod +x "${POETRY_HOME}"/bin/*
}

function setup_extras {
  label "Setting up extras"

  for task in $TASKS; do
    tasksel install $task
  done

  apt-fast install -y $APT_EXTRAS
}

function setup_services {
  label "Enabling services"
  services="docker ssh mongod"

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

  echo "Preparing /etc/profile.d/dev-env.sh"
  cat << EOF > /etc/profile.d/dev-env.sh
export PYTHONUNBUFFERED="1"
export DEB_PYTHON_INSTALL_LAYOUT="deb"
export POETRY_HOME="/usr/local/poetry"
export PATH="${PATH}:${POETRY_HOME}/bin"
EOF

  echo "Setting up /etc/default/locale"
  cat << EOF > /etc/default/locale
LANG=$LANG
LANGUAGE=$LANGUAGE
LC_ALL=$LC_ALL
LC_NUMERIC=$LC_NUMERIC
LC_TIME=$LC_TIME
LC_MONETARY=$LC_MONETARY
LC_PAPER=$LC_PAPER
LC_NAME=$LC_NAME
LC_ADDRESS=$LC_ADDRESS
LC_TELEPHONE=$LC_TELEPHONE
LC_MEASUREMENT=$LC_MEASUREMENT
TIME_STYLE="$TIME_STYLE"
EOF

  echo "Setting up /etc/locale.gen"
  cat << EOF > /etc/locale.gen
en_CA.UTF-8 UTF-8  
en_DK.UTF-8 UTF-8  
en_IE.UTF-8 UTF-8  
en_US.UTF-8 UTF-8  
EOF

  echo "Generating locales"
  locale-gen

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

# The next line enables shell command completion for gcloud.
source /usr/share/google-cloud-sdk/completion.zsh.inc

export DOCKER_BUILDKIT=1
export PATH="\$PATH:\$HOME/.local/bin"
export PATH="\$PATH:\$HOME/.local/poetry/bin"
export PATH="\$PATH:\$HOME/go/bin"

# end dev_setup.sh

EOF
    # End cat
  fi

  if ! grep "dev_setup.sh" "$USER_HOME/.bashrc"; then
    cat << EOF >> "$USER_HOME/.bashrc"

# start dev_setup.sh

# The next line enables shell command completion for gcloud.
source /usr/share/google-cloud-sdk/completion.bash.inc

export DOCKER_BUILDKIT=1
export PATH="\$PATH:\$HOME/.local/bin"
export PATH="\$PATH:\$HOME/.local/poetry/bin"
export PATH="\$PATH:\$HOME/go/bin"

# end dev_setup.sh

EOF
    # End cat
  fi

  # IPv6 often causes issues, including to Docker
  cat << EOF > /etc/docker/daemon.json
{
  "ipv6": false
}
EOF

  # Reload
  source "$USER_HOME/.bashrc"
}

function install_tools {
  label "Installing development tools"

  pnpm setup
  source $HOME/.bashrc
  
  pnpm install -g firebase-tools

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

echo "Press Enter to continue, or Ctrl+C to abort."
read

setup_basic_deps
install_keys
setup_repos
setup_docker
setup_mongodb
setup_node
setup_rust
setup_gcm
setup_python
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
