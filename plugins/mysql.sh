#
#  time2dump database plugin
#
#  This file is part of time2dump
#
#  MIT License
#  Copyright (c) 2017-2021 Jean Prunneaux
#

# Index of functions
#
#   _mysql_list_databases
#   _mysql_backup


# List databases
# Usage: _mysql_list_databases
# Exit codes: forwarded from mysql command
_mysql_list_databases() {
	# prepare command with hiding header and display
	local cmd=(mysql "${global_options[@]}" -s -N -e "show databases")

	# add options
	[ -n "$db_host" ] && cmd+=(-h "$db_host")
	[ -n "$db_port" ] && cmd+=(-P "$db_port")
	[ -n "$db_user" ] && cmd+=(-u "$db_user")
	[ -n "$db_password" ] && cmd+=(-p"$db_password")

	run_command "${cmd[@]}"
}


# Dump a database
# Usage: _mysql_backup DB_FILE [DB_NAME]
# Exit codes: forwarded from mysql command
_mysql_backup() {
	# prepare command
	local cmd=(mysqldump "${global_options[@]}" "${backup_options[@]}")

	# add options
	[ -n "$db_host" ] && cmd+=(-h "$db_host")
	[ -n "$db_port" ] && cmd+=(-P "$db_port")
	[ -n "$db_user" ] && cmd+=(-u "$db_user")
	[ -n "$db_password" ] && cmd+=(-p"$db_password")

	# output file
	local file=$1
	shift

	debug "Running ${cmd[*]} $*"
	run_command "${cmd[@]}" "$@" > "$file"
}
