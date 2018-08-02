#!/bin/bash
# file: push.sh
# license: GPLv3 https://www.gnu.org/licenses/gpl-3.0.txt
# author: nanpuyue <nanpuyue@gmail.com> https://blog.nanpuyue.com

_DIR="${0%${0##*/}}"
DATA_DIR="${_DIR}data"
INCLUDE_DIR="${_DIR}include"
. "$INCLUDE_DIR/config.sh"
. "$INCLUDE_DIR/function.sh"

declare -A PLAYER_MSG=(
    ['left']='离开了游戏'
    ['joined']='加入了游戏'
)

declare -A DEATH_MSG
while read -r line; do
    if [[ "${line%,}" =~ \"(death\..*)\":\ \"?(.*)(\"|$) ]]; then
        DEATH_MSG["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
done < "$DATA_DIR/en_us.json"

# TODO
ignore_msg(){
    false
}

chat_msg(){
	if [[ "$*" =~ \<(.*)\>\ (.*)$ ]]; then
        local username="${BASH_REMATCH[1]}"
        local text="${BASH_REMATCH[2]}"
        for i in $TELE_GROUPS; do
            _=$(telegram_msg "$i" "<$username> $text")
        done
        true
	else
        false
    fi
}

player_msg(){
    if [[ "$*" =~ ([a-zA-Z0-9_]{3,16})\ (left|joined)\ the\ game$ ]]; then
        local username="${BASH_REMATCH[1]}"
        local action="${BASH_REMATCH[2]}"
        for i in $TELE_GROUPS; do
            _=$(telegram_msg "$i" "$username ${PLAYER_MSG[$action]}")
        done
        true
	else
        false
    fi
}

advancement_msg(){
    if [[ "$*" =~ ([a-zA-Z0-9_]{3,16})\ has\ made\ the\ advancement\ (\[.*\])$ ]]; then
        local username="${BASH_REMATCH[1]}"
        local text="${BASH_REMATCH[2]}"
        for i in $TELE_GROUPS; do
            _=$(telegram_msg "$i" "$username 达成成就: $text")
        done
        true
	else
        false
    fi        
}

death_msg(){
    local send="no" regex last_word="_"
    for i in $@; do
        case "$last_word" in
            _)
                regex+="%1\\\$s"
                last_word="$i"
                ;;
            as|by|escape|fighting|hurt|of|to|using|whith)
                regex+="\ ($i|%[1-3]\\\$s)"
                last_word="$i"
                ;;
            *)
                regex+="\ $i"
                last_word="$i"
                ;;
        esac
    done

    for msg in "${DEATH_MSG[@]}";do
        if [[ "$msg" =~ $regex$ ]]; then
            for i in $TELE_GROUPS; do
                _=$(telegram_msg "$i" "$@")
            done
            break
        fi
    done
}

while read -r line; do
    if [[ "$line" =~ \[.*\]\ \[Server\ thread/INFO\]:\ (.*)$ ]]; then
        server_info="${BASH_REMATCH[1]%$'\r'}"
        if chat_msg "$server_info"; then
            continue
        elif player_msg "$server_info"; then
            continue
        elif advancement_msg "$server_info"; then
            continue
        elif death_msg "$server_info"; then
            continue
        fi
    fi
done