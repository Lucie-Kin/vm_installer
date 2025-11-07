#!/bin/bash
set -euo pipefail

# running the script as root
if [ "$EUID" -ne 0 ]; then
    ORIGINAL_USER="$USER"
    echo "re-running with root priviledge..."
    exec su -c "ORIGINAL_USER='$ORIGINAL_USER' bash '$0' $@"
else
    USER="${ORIGINAL_USER:-user}"
fi

# var
HOME="/home/$USER"
TRANSFER="$HOME/combined"
TASKBAR="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
BG_DIR="$HOME/Pictures/Backgrounds"
BG_FILE="animated_desktop_43.gif"
BG_FILE_NOBG="animated_desktop_43_nobg.gif"
NEW_BG="$BG_DIR/$BG_FILE"
BG_COLOR=#6C9F9F

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

# ssh key setup
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

# docker setup
echo "adding user to group 'docker'"
sudo usermod -aG docker "$USER"

# copy .env for docker
mkdir -p "$HOME/tmp"
echo "transfering .env for my docker..."
chmod 755 "$HOME/tmp"
if [[ -f "$TRANSFER/.env" ]]; then
    mv "$TRANSFER/.env" "$HOME/tmp/.env"
    chown "$USER:$USER" "$HOME/tmp/.env"
fi

#install latest node.js lts
if ! command -v node &> /dev/null; then
    echo "installing node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
else
    echo "node.js already installed."
fi

# install vs-code
if ! command -v code &> /dev/null; then
    sudo apt update
    sudo apt upgrade -y
    echo "installing vscode..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
       gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | \
       sudo tee /etc/apt/sources.list.d/vscode.list
    sudo apt update
    sudo apt install -y code
else
    echo "vs-code already installed."
fi

# clone git repo (add specific host to known_hosts beforehand + gcl as user level)
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
echo "preparing to clone repository..."
ssh-keyscan -H vogsphere.42nice.fr >> "$KNOWN_HOSTS" 2>/dev/null || true
chmod 600 "$KNOWN_HOSTS"
chown "$USER:$USER" "$KNOWN_HOSTS"

if [[ -d "$HOME/inception" ]]; then
    rm -rf "$HOME/inception"
fi

echo "copying my work repo locally..."
sudo -u "$USER" env GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa -o UserKnownHostsFile=$KNOWN_HOSTS" \
git clone git@vogsphere.42nice.fr:vogsphere/intra-uuid-a9e25ec3-ccf9-4b00-983c-15153ec3697f-6611255-lchauffo "$HOME/inception"
sudo chown -R "$USER:$USER" "$HOME/inception"

# kde personalized taskbar
echo "adding personnalized shortcut to the taskbar..."
if [[ -f "$TASKBAR" ]]; then
    FILEMANAGER="preferred://filemanager"
    BROWSER="preferred://browser"
    TERMINAL=$(ls /usr/share/applications/*konsole*.desktop 2>/dev/null || true)
    #simplest way the taskbar is reachable
    if grep -q "^launchers=" "$TASKBAR"; then
    	echo "adding to existing taskbar..."
    	grep -q "$BROWSER" "$TASKBAR" || sed -i "s#launchers=.*#launchers=&,$BROWSER#" "$TASKBAR"
    	grep -q "$TERMINAL" "$TASKBAR" || sed -i "s#launchers=.*#launchers=&,applications:$TERMINAL#" "$TASKBAR"
    else #creating the specific line to tell taskbar
        echo "creating new taskbar section..."
        REF="[Containments][2][Applets][5]"
        INSERT="$REF[Configuration][General]]
launchers=$FILEMANAGER,$BROWSER,applications:$KONSOLE"
        if grep -qF "$REF" "$TASKBAR"; then
            awk -i inplace -v ref="$REF" -v insert="$INSERT" '
                $0 == ref {
                    print $0
                    in_block = 1
                    next
                }
                in_block && NF == 0 {
                   print ""
                   print insert
                   in_block = 0
                }
                {print $0}
            ' "$TASKBAR" > "${TASKBAR}.tmp" && mv "${TASKBAR}.tmp" "$TASKBAR"
        else
            echo "No $REF section found - please update taskbar manually"
        fi
    fi
    echo "reloading plasmashell..."
    sudo -u "$USER" kquitapp5 plasmashell >/dev/null 2>&1 || true
    sudo -u "$USER" kstart5 plasmashell >/dev/null 2>&1 &
fi

# set background
echo "personalizing background..."
mkdir -p "$BG_DIR"
[[ -f "$TRANSFER/$BG_FILE" ]] && mv "$TRANSFER/$BG_FILE" "$BG_DIR"
[[ -f "$TRANSFER/$BG_FILE_NOBG" ]] && mv "$TRANSFER/$BG_FILE_NOBG" "$BG_DIR"
echo "extracted animated background to '$BG_DIR'"
    
if [[ -f "$NEW_BG" ]]; then
    echo "setting animated background..."
    #retrieve user dbus session
    DBUS_ADDR=$(sudo -u "$USER" cat /run/user/$(id -u "$USER")/bus 2>/dev/null || true)
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$USER")/bus"
    #apply wallpaper using qdbus
    sudo -u "$USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    var Desktops = desktops();
    for (i=0;i<Desktops.length;i++) {
      d = Desktops[i];
      d.wallpaperPlugin = 'org.kde.image';
      d.currentConfigGroup = Array('Wallpaper','org.kde.image','General');
      d.writeConfig('Image', 'file://$NEW_BG');
      d.writeConfig('FillMode', 3);
      d.writeConfig('Color', '$BG_COLOR');
    }
    "
    echo "animated background applied."
fi

# destroy transfer directory
if [[ -d "$TRANSFER" ]]; then
    echo "the transfer directory '$TRANSFER' still exists,"
    read -rp "do you wish to delete it? (y/n): " answer
    case "$answer" in
    	[Yy]*)
    	    echo "removing transfer directory..."
            rm -rf "$TRANSFER"
            echo "destruction of directory."
            ;;
        [Nn]*)
            echo "skipping cleanup."
            ;;
        *)
            echo "invalid input, skipping cleanup."
            ;;
    esac
fi
echo "All steps done."
