# file: pull.sh
# license: GPLv3 https://www.gnu.org/licenses/gpl-3.0.txt
# author: nanpuyue <nanpuyue@gmail.com> https://blog.nanpuyue.com

# 将 chatid，username，text，etype 存入变量
to_vars <<< "$(jq '{
	chatid: .message.chat.id,
	username: .message.from.username,
	text: .message.text,
	etype: .message.entities|.[0].type
}')"

cat_text 200 << EOF
hello api
EOF

# 调用 minecraft_msg 发送消息
if check_in "$chatid" "$TELE_GROUPS" && [ "$text" != null ]; then
	if [ "$etype" = "bot_command" ]; then
		# bot 指令
		case "$text" in
			/list|/list@$TELE_BOTNAME)
				minecraft_cmd "list"
				;;
			/ping|/ping@$TELE_BOTNAME)
				_=$(telegram_msg "$chatid" "pong")
				;;
		esac
	else
		# 聊天信息
		while read -r line; do
			[ -n "$line" ] && minecraft_msg "[t] <$username> $line"
		done <<< "${text//\\n/$'\n'}"
	fi
fi
