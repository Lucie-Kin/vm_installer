#!/bin/bash
set -e

# var
USER="user"
HOME="/home/$USER"
TRANSFER="$HOME/combined"

# check transfer file
if [[ ! -d "$TRANSFER" ]]; then
    echo "Please scp your files from host machine beforehand."
    exit
fi

# add user to sudoers
if ! sudo grep -q "^$USER ALL=(ALL:ALL) NOPASSWD:ALL" /etc/sudoers.d/$USER 2>/dev/null; then
    echo "$USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER
    sudo chmod 440 /etc/sudoers.d/$USER
fi

# copy keys
mkdir -p "$HOME/.ssh"
if [[ -f "$TRANSFER/id_rsa" ]]; then
    echo "transfering ssh keys..."
    mv "$TRANSFER/id_rsa" "$HOME/.ssh"
    mv "$TRANSFER/id_rsa.pub" "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/id_rsa"
    chmod 644 "$HOME/.ssh/id_rsa.pub"
    chown -R "$USER:$USER" "$HOME/.ssh"
fi

# add user to 'docker' group
echo "adding user to group 'docker'"
sudo usermod -aG docker "$USER"

# copy .env
mkdir -p "$HOME/tmp"
echo "transfering .env for my docker..."
chmod 755 "$HOME/tmp"
if [[ -f "$TRANFER/.env" ]]; then
    mv "$TRANSFER/.env" "$HOME/tmp/.env"
    chown "$USER:$USER" "$HOME/tmp/.env"
fi

# install vs-code
sudo apt update
sudo apt upgrade -y
echo "installing vscode..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
  gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | \
  sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update
sudo apt install -y code

# clone git repo
if [[ -d "$HOME/inception" ]]; then
    rm -rf "$HOME/inception"
fi
echo "copying my work repo locally..."
git clone git@vogsphere.42nice.fr:vogsphere/intra-uuid-a9e25ec3-ccf9-4b00-983c-15153ec3697f-6611255-lchauffo "$HOME/inception"
sudo chown -R "$USER:$USER" "$HOME/inception"

# destroy transfer directory
if [[ -d "$TRANSFER" ]]; then
    echo "All steps done. Destruction of directory."
    rm -rf "$TRANSFER"
fi

