#!/bin/sh

hexdump -ve '1/4 "%08x\n"' $1
