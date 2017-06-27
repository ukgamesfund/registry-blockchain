#!/usr/bin/env bash
files=$(/bin/ls *.js | sort)

for file in ${files} ; do
    js=`pwd`/${file}
    echo "Testing: ${js}"
    ./run-tests.sh ${js}
done
