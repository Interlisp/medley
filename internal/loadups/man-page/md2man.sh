#!/bin/bash
pandoc loadup.1.md -s -t man -o loadup.1
gzip --stdout loadup.1 >loadup.1.gz
