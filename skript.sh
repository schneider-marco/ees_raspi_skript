#!/bin/bash

# Prüfen, ob das Skript als Root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Dieses Skript muss als Root ausgeführt werden!" >&2
  exit 1
fi

# Skript wird als Root ausgeführt. Fortfahren mit der Installation von autossh.
echo "Skript wird als Root ausgeführt. Fahren fort..."

# Installieren von autossh
echo "Installiere autossh..."
sudo apt-get update
sudo apt-get install -y autossh
echo "autossh wurde erfolgreich installiert."

# Benutzereingabe für den SSH-Port
read -p "Bitte geben Sie den Port für die SSH-Verbindung ein: " ssh_port

# Überprüfen, ob der eingegebene Port eine gültige Zahl ist
if ! [[ "$ssh_port" =~ ^[0-9]+$ ]] ; then
   echo "Ungültige Eingabe. Der Port muss eine Zahl sein!" >&2
   exit 1
fi

echo "Der angegebene SSH-Port ist: $ssh_port"

# Ermitteln des Home-Verzeichnisses des aktuellen Benutzers
user_home=$(eval echo ~${SUDO_USER})

# Erstellen des systemd-Service-Files für autossh
echo "Erstelle systemd service für autossh..."

sudo bash -c "cat > /etc/systemd/system/autossh.service" <<EOL
[Unit]
Description=Reverse ssh tunnel
After=network-online.target

[Service]
User=root
Environment=AUTOSSH_GATETIME=0
ExecStart=/usr/bin/autossh -M 0 -q -N -o "StrictHostKeyChecking=no" -o "PubKeyAuthentication=yes" -o "PasswordAuthentication=no" -o "ExitOnForwardFailure=yes" -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -i ${user_home}/.ssh/rmm -R ${ssh_port}:localhost:22 -l rmmuser rmm.masc-lab.de
ExecStop=/usr/bin/killall autossh
RestartSec=5
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd to recognize the new service and enable it
sudo systemctl daemon-reload
sudo systemctl enable autossh.service
sudo systemctl start autossh


echo "Der autossh systemd service wurde erstellt und aktiviert."

mkdir .ssh
# Erstellen eines SSH-Schlüssels ohne Passphrase im Ordner ~/.ssh/ des aktuellen Benutzers
echo "Erstelle SSH-Schlüssel ohne Passphrase im Ordner ${user_home}/.ssh/..."
ssh-keygen -t rsa -b 4096 -f ${user_home}/.ssh/rmm -N "" -q

# Ausgabe des öffentlichen Schlüssels
echo ""
echo ""
echo "Der öffentliche Schlüssel lautet:"
cat ${user_home}/.ssh/rmm.pub
