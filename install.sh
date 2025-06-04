opkg update >/dev/null 2>&1
opkg install tar
curl -L https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar -o xkeen.tar
tar -xvf xkeen.tar -C /opt/sbin --overwrite > /dev/null && rm xkeen.tar
xkeen -i
