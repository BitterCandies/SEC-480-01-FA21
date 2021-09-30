#!/bin/sh
#script to prepare ubuntu desktop vm for cloning
apt-get dist-upgrade
#chrome remote desktop
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install --assume-yes ./google-chrome-stable_current_amd64.deb

wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
sudo apt install --assume-yes ./chrome-remote-desktop_current_amd64.deb

#open ssh
apt-get install -y open-vm-tools-desktop openssh-server
cat /dev/null > /var/log/wtmp 
cat /dev/null > /var/log/lastlog 
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -f /etc/ssh/ssh_host*
rm -f /etc/udev/rules.d/70-persistent-net.rules
cat <<EOL | sudo tee /etc/rc.local
#!/bin/sh -e
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
exit 0
EOL
echo ubuntu > /etc/hostname
apt-get clean
history -c
history -w
chmod +x /etc/rc.local
systemctl stop apt-daily-upgrade.timer
systemctl disable apt-daily-upgrade.timer
systemctl stop apt-daily.timer
systemctl disable apt-daily.timer
sudo apt autoremove -y

echo "remove git repo and then issue a shutdown - h now"
