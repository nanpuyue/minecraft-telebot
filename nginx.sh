#!/bin/bash
# file: nginx.sh
# license: GPLv3 https://www.gnu.org/licenses/gpl-3.0.txt
# author: nanpuyue <nanpuyue@gmail.com> https://blog.nanpuyue.com

_DIR="$(dirname "$(realpath "$0")")"
. "$_DIR/include/config.sh"

_start(){
	[ -n "$SERVER_PORT" ] || SERVER_PORT="8443"
	if [ -n "$SERVER_NAME" ]; then
		local update_url="https://$SERVER_NAME:$SERVER_PORT/api/pull?token=$UPDATE_TOKEN"
	else
		SERVER_NAME="_"
	fi
	sed "s#nginx.conf_tpl#nginx.conf#;
	     s#__DOCUMENT_ROOT__#$_DIR/cgi/#;
	     s#__SERVER_NAME__#$SERVER_NAME#;
	     s#__SERVER_PORT__#$SERVER_PORT#g" \
	    "$_DIR/nginx/nginx.conf_tpl" > "$_DIR/nginx/nginx.conf"
	mkdir -p "$_DIR/nginx"/{run,log}
	if nginx -p "$_DIR/nginx/" -c nginx.conf &&\
	[ -n "$update_url" ]; then
		echo "update url: $update_url"
	fi
}

_stop(){
	pid_file="$_DIR/nginx/run/nginx.pid"
	if [ -f "$pid_file" ]; then
		kill "$(cat "$pid_file")"
	fi
}

if [ "$(id -u)" = 0 ]; then
	case "$1" in
		start)
			_start
			;;
		stop)
			_stop
			;;
		*)
			echo "Usage: $0 start|stop"
			;;
	esac
else
	echo "Usage: sudo $0 start|stop"
fi
