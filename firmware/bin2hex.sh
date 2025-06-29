#!/bin/sh

hexdump -e '1/4 "%08x\n"' $1
