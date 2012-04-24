#!/bin/sh
gcc -E -P -D__attribute__\(x\)= -D__asm__\(x\)= -D__extension__\(x\)= $*
