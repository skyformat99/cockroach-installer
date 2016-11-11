#!/bin/bash

APP_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
DATA_DIR="/var/data/cockroachdb"
ETC="/etc/cockroachdb"
CERT_DIR="$ETC/certs"

function usage {
	printf "Cockroachdb Installer\nUsage: $1 /path/to/cockroachdb.tgz [user]\n"
	echo "download cockroachdb tgz file from https://www.cockroachlabs.com"
}

function extractRoach {
	mkdir -p "$APP_DIR" || exit 1
	tar -xzf "$1" || exit 1
}

function setInstallDirs {
	filename=$(basename "$1")
	extension="${filename##*.}"
	filename="${filename%.*}"
	mv -f "$filename/cockroach" "$APP_DIR/cockroach" || exit 1
    rm -r "$filename"
	mkdir -p "$DATA_DIR" || exit 1
}
  
function installCerts {
    mkdir -p "$CERT_DIR" || exit 1
    pushd "$CERT_DIR" || exit 1
	"$APP_DIR/cockroach" cert create-ca --ca-cert=ca.cert --ca-key=ca.key || exit 1
	"$APP_DIR/cockroach" cert create-node localhost $(hostname) --ca-cert=ca.cert --ca-key=ca.key --cert=node.cert --key=node.key || exit 1
	"$APP_DIR/cockroach" cert create-client root --ca-cert=ca.cert --ca-key=ca.key --cert=root.cert --key=root.key || exit 1
	popd
}

function changePerms {
    usr=$1
    if [ -z "$usr" ];then
        return
    fi
    chown -R "$usr:$usr" "$ETC" #remove the need for sudo when accessing cockroachdb
}

function installService {
	mkdir -p "$SYSTEMD_DIR" || exit 1
	cp -f cockroach.service "$SYSTEMD_DIR" || exit 1
	systemctl enable "$SYSTEMD_DIR/cockroach.service" || exit 1
}

#create cconnect script for easier access to the sql console
function outputConnectUtil {
    touch "/usr/local/bin/cconnect"
    echo "cockroach sql --ca-cert=/etc/cockroachdb/certs/ca.cert --cert=/etc/cockroachdb/certs/root.cert --key=/etc/cockroachdb/certs/root.key" > "/usr/local/bin/cconnect"
    chmod +x "/usr/local/bin/cconnect"
}

## Begin processing script

if [ -z "$1" ]; then
	usage $0
	exit 1
fi

./systemdUninstaller.sh

echo "Installing..."
extractRoach $1
setInstallDirs $1
installCerts
changePerms $2
installService
outputConnectUtil
echo "Done!"

exit 0