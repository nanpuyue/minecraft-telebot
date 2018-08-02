#!/bin/bash
# file: api.sh
# license: GPLv3 https://www.gnu.org/licenses/gpl-3.0.txt
# author: nanpuyue <nanpuyue@gmail.com> https://blog.nanpuyue.com

INCLUDE_DIR="${0%${0##*/}}../include"
. "$INCLUDE_DIR/config.sh"
. "$INCLUDE_DIR/function.sh"

# 解析参数
for x in ${QUERY_STRING//&/ }; do
	case $x in
	token=*)
		token=${x#token=}
		;;
	esac
done

# 检查 token
if [ "$token" = "$UPDATE_TOKEN" ]; then
	# 执行实际任务处理脚本
	script="${REQUEST_URI%%\?*}"
	script="api/${script##*/}.sh"
	if [ -x "$script" ]; then
		. "$script"
	else
		cat_text 404 << EOF
Not found!
EOF
	fi
else
	cat_text 400 << EOF
Token missing or error!
EOF
fi
