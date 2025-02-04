#/bin/sh

find . -name "*.~[1-9]*~" -exec if \[ ! -f {}:h \]\; then echo "{}" " with no versionless" \;
