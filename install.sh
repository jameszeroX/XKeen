opkg update && opkg upgrade && opkg install curl tar
curl -L https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar -o xkeen.tar
tar -xvf xkeen.tar -C /opt/sbin --overwrite > /dev/null && rm xkeen.tar
chmod +x /opt/sbin/xkeen
xkeen -i
