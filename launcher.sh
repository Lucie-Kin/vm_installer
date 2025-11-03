#!/bin/bash
set -euo pipefail

# running the script as root
if [ "$EUID" -ne 0 ]; then
    echo "re-running with root priviledge..."
    exec sudo bash "$0" "$@"
fi

# var
USER="user"
HOME="/home/$USER"
TRANSFER="$HOME/combined"
TASKBAR="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
NEW_BG="$HOME/tmp/animated_desktop_43.gif"
BACK_COLOR=#6C9F9F

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
chmod 700 "$HOME/.ssh"
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
if [[ -f "$TRANSFER/.env" ]]; then
    mv "$TRANSFER/.env" "$HOME/tmp/.env"
    chown "$USER:$USER" "$HOME/tmp/.env"
fi

# install vs-code
if [[ ! -e "/usr/bin/code" ]]; then
    sudo apt update
    sudo apt upgrade -y
    echo "installing vscode..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
       gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | \
       sudo tee /etc/apt/sources.list.d/vscode.list
    sudo apt update
    sudo apt install -y code
fi

# clone git repo (add specific host to known_hosts beforehand + gcl as user level)
ssh-keyscan -H vogsphere.42nice.fr >> "$HOME/.ssh/known_hosts" 2>/dev/null
chmod 600 "$HOME/.ssh/known_hosts"
chown "$USER:$USER" "$HOME/.ssh/known_hosts"
if [[ -d "$HOME/inception" ]]; then
    rm -rf "$HOME/inception"
fi
echo "copying my work repo locally..."
sudo -u "$USER" env GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa -o UserKnownHostsFile=$HOME/.ssh/known_hosts" \
git clone git@vogsphere.42nice.fr:vogsphere/intra-uuid-a9e25ec3-ccf9-4b00-983c-15153ec3697f-6611255-lchauffo "$HOME/inception"
sudo chown -R "$USER:$USER" "$HOME/inception"

# personalized taskbar
echo "adding new shortcut to the taskbar..."
if [[ -f "$TASKBAR" ]]; then
    FIREFOX=$(ls /usr/share/applications/*firefox*.desktop 2>/dev/null || true)
    KONSOLE=$(ls /usr/share/applications/*konsole*.desktop 2>/dev/null || true)
    if [[ -n "$FIREFOX" && -z "$(awk '/firefox/' "$TASKBAR")" ]]; then
    	sed -i "s#launchers=.*#launchers=&,applications:$FIREFOX#" "$TASKBAR"
    fi
    if [[ -n "$KONSOLE" && -z "$(awk '/konsole/' "$TASKBAR")" ]]; then
    	sed -i "s#launchers=.*#launchers=&,applications:$KONSOLE#" "$TASKBAR"
    fi
fi

# mv background files
if [[ -f "$NEW_BG" ]]; then
    mkdir -p "$HOME/Pictures/Backgrounds"
    mv "$NEW_BG" "$HOME/Pictures/Backgrounds"
    if [[ -f "$HOME/Pictures/Backgrounds" ]]; then
    	NEW_BG="$HOME/Pictures/Backgrounds"
    fi
fi

# set new background
echo "setting new background..."
sudo -u "$USER" kwriteconfig5 --file kwinrc 'BackgroundImage' "file://$NEW_BG"
sudo -u "$USER" kwriteconfig5 --file kwinrc 'BackgroundMode' "2"
sudo -u "$USER" kwriteconfig5 --file kwinrc 'BackgroundColor' "$BACK_COLOR"
plasmashell --replace &
sleep 2

# destroy transfer directory
if [[ -d "$TRANSFER" ]]; then
    echo "All steps done. Destruction of directory."
    rm -rf "$TRANSFER"
fi

