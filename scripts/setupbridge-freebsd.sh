#!/bin/sh

Usage() {
    echo "Usage: $0 <n>"
    echo "       <n> - number of interfaces in the bridged set, 1..255"
    exit 1
}

# root is required to create interfaces and bridges
UID=$(id -u)
if [ $UID -ne 0 ]; then
    echo "You must be root to set up bridging."
    exit 1;
fi
# exactly one argument is required
if [ $# -ne 1 ]; then
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
bridge=$( ifconfig bridge create )
if [ $? -gt 0 ]; then
    echo "Unable to create bridge interface"
    exit 1
fi
# say what we're about to do
echo Creating $bridge with $1 interface pairs
# and proceed to create the fake ethernet pairs and bridge them,
# reporting the mac address for each interface as it is created
seq 1 $1 | while read base; do
    base=$( ifconfig epair$base create | sed 's/a$//')
    ifconfig $bridge addm ${base}b
    ifconfig ${base}a up
    ifconfig ${base}b up
    ether=$(ifconfig ${base}a | grep ether | sed 's/ether \([0-9a-f:]*\)/\1/' )
    echo interface ${base}a $ether
done
#finally, bring the bridge up
ifconfig $bridge up
