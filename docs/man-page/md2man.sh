#!/bin/bash
pandoc medley.1.md -s -t man -o medley.1
gzip --stdout medley.1 >medley.1.gz
