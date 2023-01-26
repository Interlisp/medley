#!/bin/bash
pandoc medley.1.md -s -t man | /usr/bin/man -l -
