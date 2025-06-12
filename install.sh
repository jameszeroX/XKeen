curl -OL https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz
tar -xvzf xkeen.tar.gz -C /opt/sbin --overwrite > /dev/null && rm xkeen.tar.gz
xkeen -i
