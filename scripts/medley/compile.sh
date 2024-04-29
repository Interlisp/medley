#!/bin/sh
mv medley.command medley.command~
./inline.sh --in-file medley_main.sh --out-file medley.command
chmod +x medley.command

