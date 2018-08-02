#!/bin/bash
# file: push.sh
# license: GPLv3 https://www.gnu.org/licenses/gpl-3.0.txt
# author: nanpuyue <nanpuyue@gmail.com> https://blog.nanpuyue.com

INCLUDE_DIR="${0%${0##*/}}include"
. "$INCLUDE_DIR/config.sh"
. "$INCLUDE_DIR/function.sh"

while read -r line; do
	if [[ "$line" =~ \[.*\]\ \[Server\ thread/INFO\]:\ \<(.*)\>\ (.*)$ ]]; then
        username="${BASH_REMATCH[1]}"
        text="${BASH_REMATCH[2]}"
        for i in $TELE_GROUPS; do
            _=$(telegram_msg "$i" "<$username> $text")
        done
	fi
done
