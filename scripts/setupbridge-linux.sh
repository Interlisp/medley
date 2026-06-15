#!/bin/sh

Usage() {
    echo "Usage: $0 <n>"
    echo "       <n> - number of interfaces in the bridged set, 1..255"
    exit 1
}

# root is required to create interfaces and bridges
if [ "$(whoami)" != "root" ]; then
    echo "You must be root to set up bridging."
    exit 1;
fi
# exactly one argument is required
if [ "$#" -ne 1 ]; then
    Usage
fi
# which must be numeric
case "$1" in
    ''|*[!0-9]*) Usage ;;
    *) n=$1 ;;
esac
# between 1 and 255
if [ "$n" -le 0 -o "$n" -gt 255 ]; then
    Usage
fi
# now try to create the next available bridge and record its name
n=0
while true; do
    bridge="bridge$n"
    # Check if it already exists
    if ! ip link show "$bridge" >/dev/null 2>&1; then
        # Found an available name, exit the loop
        break
    fi
    n=$((n + 1))
done
# say what we're about to do
echo Creating $bridge with $1 interface pairs
ip link add name "$bridge" type bridge
if [ $? -gt 0 ]; then
    echo "Unable to create bridge interface"
    exit 1
fi

# proceed to create the fake ethernet pairs and bridge them,
# reporting the mac address for each interface as it is created

seq 1 $1 | while read base; do
    pair=$((256 + $base))
    ip link add medley$base type veth peer name medley$pair
    ip link set dev medley$pair master $bridge
    ip link set dev medley$pair up
    ip link set dev medley$base up
    ether=$(ip link show dev medley$base| grep link/ether | sed 's/^.*ether \([0-9a-f:]*\).*$/\1/')
    echo interface -E $ether%medley$base
done
#finally, bring the bridge up
ip link set dev $bridge up

