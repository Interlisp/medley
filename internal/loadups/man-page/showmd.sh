#!/bin/bash
pandoc loadup.1.md -s -t man | /usr/bin/man -l -
