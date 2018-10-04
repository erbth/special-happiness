#!/bin/bash

set -e

GCC="/home/therb/opt/cross/bin/i686-elf-gcc"

if [ $# -ne 2 ]; then
	echo "Usage: htoinc.sh <infile> <outfile>" >&2
	exit 1
fi

# shopt -s extglob

# if [ -e "$2" ]; then
#	rm "$2"
# fi

# IFS=$' \t'

# while read LINE; do
#	KV=${LINE/"#define"/""}
#	KV=${KV##*( )}
#	KEY=${KV%% *}
#	VALUE=${KV#* }

#	echo "$KEY equ $VALUE" >> "$2"
# done <<<$($GCC "$1" -fpreprocessed -P -dD -E -o /dev/stdout)

$GCC "$1" -fpreprocessed -P -dD -E -o /dev/stdout | \
	sed 's/#define/%define/' | \
	sed 's/#ifndef/%ifndef/' | \
	sed 's/#endif/%endif/' > "$2"

exit 0
