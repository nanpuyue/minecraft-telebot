# file: function.sh
# license: GPLv3 https://www.gnu.org/licenses/gpl-3.0.txt
# author: nanpuyue <nanpuyue@gmail.com> https://blog.nanpuyue.com

# 转义
shell_escape(){
    printf "%q" "$*"
}

# 输出 http 状态码及文本
cat_text(){
	echo "Status: $1"
	echo "Content-Type: text/plain"
	echo
	while read i; do
		echo "$i"
	done
}

# 检测 $1 在 $2 中是否存在
check_in(){
	for i in $2; do
		[ "$1" = "$i" ] && return 0
	done
	false
}

# 处理 jq 解析出的数据，即将结果存入变量
# 注意此函数不能以子进程（管道或 $()）调用
# TODO: 使用 hashtab 替换 eval
to_vars(){
	while read -r line; do
		if [[ "${line%,}" =~ \"(.*)\":\ \"?(.*)(\"|$) ]]; then
#		if [[ "${line%,}" =~ \"(.*)\":\ ?(.*)$ ]]; then
			eval "${BASH_REMATCH[1]}"='${BASH_REMATCH[2]}'
		fi
	done
}

# 向 Minecraft 玩家发送消息，接收的参数需要转义
minecraft_msg(){
	local text="{\"text\":\"$*\"}"
	local tell_command="tellraw Space @a Space"
	if [ -S "$TMUX_SOCKET" ]; then
		tmux -S "$TMUX_SOCKET" send-key -t "$TMUX_SESSION" C-u $tell_command "$text" Enter
	else
		tmux send-key -t "$TMUX_SESSION" C-u $tell_command "$text" Enter
	fi
}

# 向 telegram 发送消息，$1: chat_id， $2: text
telegram_msg(){
	local url="${TELE_API}${TELE_TOKEN}/sendMessage"
	local header="Content-Type: application/json"
	local proxy="${CURL_PROXY:+-x $CURL_PROXY}"
	local chat_id="$1"; shift
	local text="${*//\\/\\\\}"
	text="${text//\"/\\\"}"
	local json="{\"chat_id\":\"$chat_id\",\"text\":\"$text\"}"
	if [ -n "$text" ]; then
		curl -X "POST" -H "$header" -sd "$json" "$url" $proxy
	fi
}
