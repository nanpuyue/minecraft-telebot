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
    ['left']='退出了游戏'
    ['joined']='加入了游戏'
)


declare -A ADVAN_MSG DEATH_MSG
while read -r line; do
    if [[ "${line%,}" =~ \"(advancements\..*\.title)\":\ \"?(.*)(\"|$) ]]; then
        ADVAN_MSG["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "${line%,}" =~ \"(death\..*)\":\ \"?(.*)(\"|$) ]]; then
        DEATH_MSG["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
done < "$DATA_DIR/en_us.json"

declare -A ADVAN_MSG_LOCAL DEATH_MSG_LOCAL
while read -r line; do
    if [[ "${line%,}" =~ \"(advancements\..*\.title)\":\ \"?(.*)(\"|$) ]]; then
        ADVAN_MSG_LOCAL["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "${line%,}" =~ \"(death\..*)\":\ \"?(.*)(\"|$) ]]; then
        DEATH_MSG_LOCAL["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
done < "$DATA_DIR/zh_cn.json"

declare -A ADVAN_MSG_MAP
for i in "${!ADVAN_MSG[@]}"; do
    ADVAN_MSG_MAP["${ADVAN_MSG[$i]}"]="${ADVAN_MSG_LOCAL[$i]}"
done
unset ADVAN_MSG ADVAN_MSG_LOCAL

# TODO
ignore_msg(){
    false
}

# 聊天信息
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

# 玩家加入游戏及离开游戏
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

# 成就信息
advancement_msg(){
    if [[ "$*" =~ ([a-zA-Z0-9_]{3,16})\ has\ made\ the\ advancement\ \[(.*)\]$ ]]; then
        local username="${BASH_REMATCH[1]}"
        local advancement="${BASH_REMATCH[2]}"
        [ -n "${ADVAN_MSG_MAP["$advancement"]}" ] &&\
            advancement="${ADVAN_MSG_MAP["$advancement"]}"
        for i in $TELE_GROUPS; do
            _=$(telegram_msg "$i" "$username 取得了进度: $advancement")
        done
        true
	else
        false
    fi        
}

# 死亡信息
death_msg(){
    local regex capture escape msg last="_"

    # 构造正则表达式
    for i in $@; do
        escape=$(shell_escape $i)
        case "$last" in
            _)
                regex+="%1\\\$s"
                ;;
            as|by|escape|fighting|hurt|of|to|using|whith)
                if [ "$capture" = 1 ]; then
                    regex+="\ $escape|%[1-3]\\\$s)"
                    capture=0
                else
                    regex+="\ ($escape"
                    capture=1
                fi
                ;;
            *)

                regex+="\ $escape"
                ;;
        esac
        last="$i"
    done
    [ "$capture" = 1 ] && regex+="|%[1-3]\\\$s)"

    # 进行正则匹配，判断信息是否位死亡信息
    for i in "${!DEATH_MSG[@]}";do
        if [[ "${DEATH_MSG[$i]}" =~ $regex$ ]]; then
            # 尝试对信息进行本地化翻译
            regex=$(shell_escape ${DEATH_MSG[$i]})
            regex=${regex//\%[1-3]\\\$s/(.*)}
            if [[ "$*" =~ $regex$ ]]; then
                msg="${DEATH_MSG_LOCAL[$i]}"
                for j in {1..3}; do
                    [ -n "${BASH_REMATCH[$j]}" ] &&\
                        msg=${msg/\%$j\$s/${BASH_REMATCH[$j]}}
                done
            else
                msg="$*"
            fi

            for j in $TELE_GROUPS; do
                _=$(telegram_msg "$j" "$msg")
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
