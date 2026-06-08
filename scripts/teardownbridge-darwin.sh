#!/bin/sh
Usage() {
    echo "Usage: $0 <bridge>"
    echo "       <bridge> - name of the bridge to tear down"
    exit 1
}

# root is required to create interfaces and bridges
if [ "$UID" -ne "0" ]; then
    echo "You must be root to tear down bridging."
    exit 1;
fi
# exactly one argument is required
if [ "$#" -ne 1 ]; then
    Usage
fi

case "$1" in
    bridge[0-9]*) bridge=$1 ;;
    *) Usage ;;
esac
ifconfig $bridge | grep member: | awk '{print $2}' | \
    while read member; do
	peer=$( ifconfig $member | grep peer: | awk '{print $2}')
	ifconfig $peer destroy
	ifconfig $member destroy
    done
ifconfig $bridge destroy
