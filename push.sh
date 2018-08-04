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

declare -A ADVAN_MSG ADVAN_TYPE DEATH_MSG ENTITY
while read -r line; do
    if [[ "${line%,}" =~ \"(advancements\..*\.title)\":\ \"?(.*)(\"|$) ]]; then
        ADVAN_MSG["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "${line%,}" =~ \"(death\..*)\":\ \"?(.*)(\"|$) ]]; then
        DEATH_MSG["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "${line%,}" =~ \"(entity\..*)\":\ \"?(.*)(\"|$) ]]; then
        ENTITY["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "${line%,}" =~ \"(chat\.type\.advancement\..*)\":\ \"?%s\ (.*)\ %s(\"|$) ]]; then
        ADVAN_TYPE["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
done < "$DATA_DIR/en_us.json"

declare -A ADVAN_MSG_LOCAL ADVAN_TYPE_LOCAL DEATH_MSG_LOCAL ENTITY_LOCAL
while read -r line; do
    if [[ "${line%,}" =~ \"(advancements\..*\.title)\":\ \"?(.*)(\"|$) ]]; then
        ADVAN_MSG_LOCAL["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "${line%,}" =~ \"(death\..*)\":\ \"?(.*)(\"|$) ]]; then
        DEATH_MSG_LOCAL["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "${line%,}" =~ \"(entity\..*)\":\ \"?(.*)(\"|$) ]]; then
        ENTITY_LOCAL["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "${line%,}" =~ \"(chat\.type\.advancement\..*)\":\ \"?%s(.*)%s(\"|$) ]]; then
        ADVAN_TYPE_LOCAL["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
done < "$DATA_DIR/zh_cn.json"

declare -A ADVAN_MSG_MAP
for i in "${!ADVAN_MSG[@]}"; do
    ADVAN_MSG_MAP["${ADVAN_MSG[$i]}"]="${ADVAN_MSG_LOCAL[$i]}"
done
unset ADVAN_MSG ADVAN_MSG_LOCAL

declare -A ENTITY_MAP
for i in "${!ENTITY[@]}"; do
    ENTITY_MAP["${ENTITY[$i]}"]="${ENTITY_LOCAL[$i]}"
done
unset ENTITY ENTITY_LOCAL

declare -A ADVAN_TYPE_MAP
for i in "${!ADVAN_TYPE[@]}"; do
    ADVAN_TYPE_MAP["${ADVAN_TYPE[$i]}"]="${ADVAN_TYPE_LOCAL[$i]}"
done
unset ADVAN_TYPE ADVAN_TYPE_LOCAL

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
        return 0
	else
        return -1
    fi
}

# 玩家在线信息
online_msg(){
    if [[ "$*" =~ There\ are\ ([0-9]*)\ of\ a\ max\ ([0-9]*)\ players\ online:\ (.*)$ ]]; then
        local online="${BASH_REMATCH[1]}"
        local list="\n${BASH_REMATCH[3]//, /$'\n'}"
        if (( "$online" > 0 )); then
            local msg="当前共 $online 人在线: ${list/#\\n/$'\n'}"
        else
            local msg="当前无人在线"
        fi
        for i in $TELE_GROUPS; do
                _=$(telegram_msg "$i" "$msg")
        done
        return 0
    else
        return -1
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
        return 0
	else
        return -1
    fi
}

# 成就信息
advancement_msg(){
    if [[ "$*" =~ ([a-zA-Z0-9_]{3,16})\ (has\ .*)\ \[(.*)\]$ ]]; then
        local username="${BASH_REMATCH[1]}"
        local atype="${BASH_REMATCH[2]}"
        local advancement="${BASH_REMATCH[3]}"
        [ -n "${ADVAN_TYPE_MAP["$atype"]}" ] &&\
            atype="${ADVAN_TYPE_MAP["$atype"]}"
        [ -n "${ADVAN_MSG_MAP["$advancement"]}" ] &&\
            advancement="${ADVAN_MSG_MAP["$advancement"]}"
        for i in $TELE_GROUPS; do
            _=$(telegram_msg "$i" "$username $atype: $advancement")
        done
        return 0
	else
        return -1
    fi        
}

# 死亡信息
death_msg(){
    local regex escape msg username entity rematch capture=0 num=2

    # 构造正则表达式
    for i in ${@#* }; do
        escape=$(shell_escape $i)
        case "$i" in
            as|by|escape|fighting|hurt|of|to|using|whith)
                if (( "$capture" > 0 )); then
                    regex+="|%[1-3]\\\$s)\ $escape"
                else
                    regex+="\ $escape"
                fi
                capture=1
                ;;
            *)
                if (( "$capture" == 1 )); then
                    regex+="\ ($escape"
                    let capture++
                else
                    regex+="${regex:+\\ }$escape"
                fi
                ;;
        esac
    done
    (( "$capture" > 0 )) && regex+="|%[1-3]\\\$s)"

    # 进行正则匹配，判断信息是否为死亡信息
    for index in "${!DEATH_MSG[@]}";do
        if [[ "${DEATH_MSG[$index]#* }" =~ $regex$ ]]; then
            # 尝试对信息进行本地化翻译
            regex=$(shell_escape ${DEATH_MSG[$index]})
            regex=${regex//\%[1-3]\\\$s/(.*)}
            if [[ "$*" =~ $regex$ ]]; then
                username="${BASH_REMATCH[1]}"
                rematch=("${BASH_REMATCH[@]}")
                msg="${DEATH_MSG_LOCAL[$index]/\%1\$s/$username}"
                # 只进行必要的翻译尝试
                # [[ ! "$index" =~ \.player ]] && num+="${num:+ }2"
                [[ "$index" =~ \.item$ ]] && num+="${num:+ }3"
                for i in $num; do
                    entity="${rematch[$i]}"
                    if [ -n "$entity" ]; then
                        if [ -n "${ENTITY_MAP["$entity"]}" ]; then
                            entity="${ENTITY_MAP["$entity"]}"
                        fi
                        msg=${msg/\%$i\$s/$entity}
                    fi
                done
            else
                msg="$*"
            fi

            for i in $TELE_GROUPS; do
                _=$(telegram_msg "$i" "$msg")
            done
            return 0
        fi
    done
    return -1
}

while read -r line; do
    if [[ "$line" =~ \[.*\]\ \[Server\ thread/INFO\]:\ (.*)$ ]]; then
        server_info="${BASH_REMATCH[1]%$'\r'}"
        if chat_msg "$server_info"; then
            continue
        elif online_msg "$server_info"; then
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
