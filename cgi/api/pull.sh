# file: pull.sh
# license: GPLv3 https://www.gnu.org/licenses/gpl-3.0.txt
# author: nanpuyue <nanpuyue@gmail.com> https://blog.nanpuyue.com

# 将 chatid，username，text 存入变量
to_vars <<< "$(jq '{
	chatid: .message.chat.id,
	username: .message.from.username,
	text: .message.text
}')"

cat_text 200 << EOF
hello api
EOF

# 调用 minecraft_msg 发送消息
printf -v NL '\n'
if check_in "$chatid" "$TELE_GROUPS" && [ "$text" != null ]; then
	while read -r line; do
    	[ -n "$line" ] && minecraft_msg "[t] <$username> $line"
	done <<< "${text//\\n/$NL}"
fi
