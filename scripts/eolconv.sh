#!/bin/sh
LANG=C tr '\r' '\n' < $1 | tr -d '\001-\006'
