#!/bin/sh
Usage() {
    echo "Usage: $0 <bridge>"
    echo "       <bridge> - name of the bridge to tear down"
    exit 1
}

# root is required to tear down interfaces and bridges
if [ "$(whoami)" != "root" ]; then
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

ip link show master $bridge | grep @ | awk '{print $2}' | sed 's/@.*$//' | \
    while read member; do
	ip link delete $member
    done
ip link delete $bridge
