#!/bin/bash

set -e

if [ $# -ne 2 ]; then
	echo "Usage: inctoh.sh <infile> <outfile>" >&2
	exit 1
fi

cat "$1" | \
	sed 's/;.*//' | \
	sed 's/%ifndef\(.*_INC\)\s*/#ifndef\1_H/' | \
	sed 's/%define\(.*_INC\)\s*/#define\1_H/' | \
	sed 's/%define/#define/' | \
	sed 's/%ifndef/#ifndef/' | \
	sed 's/%endif/#endif/' > "$2"

exit 0
