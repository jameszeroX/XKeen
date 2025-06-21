curl -OL https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz
c="tar -xvzf xkeen.tar.gz -C /opt/sbin >/dev/null 2>&1"
$c --overwrite || $c
rm xkeen.tar.gz
xkeen -i
