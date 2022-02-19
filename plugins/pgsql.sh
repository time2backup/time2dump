#
#  time2dump database plugin
#
#  This file is part of time2dump
#  Source code: https://github.com/time2backup/time2dump
#

# Index of functions
#
#   _pgsql_list_databases
#   _pgsql_backup


# List databases
# Usage: pgsql_list_databases
# Exit codes: forwarded from psql command
_pgsql_list_databases() {
	# prepare command with hiding header and display
	local result=0 cmd=(psql "${global_options[@]}" -t -A -c "SELECT datname FROM pg_database")

	# add options
	[ -n "$db_host" ] && cmd+=(-h "$db_host")
	[ -n "$db_port" ] && cmd+=(-p "$db_port")
	[ -n "$db_user" ] && cmd+=(-U "$db_user")
	[ -n "$db_password" ] && PGPASSWORD=$db_password

	run_command "${cmd[@]}"
	result=$?

	# reset password
	[ -n "$db_password" ] && PGPASSWORD=""

	return $result
}


# Dump a database
# Usage: pgsql_backup DB_FILE [DB_NAME]
# Exit codes: forwarded from mysql command
_pgsql_backup() {
	# prepare command
	local result=0 cmd=(pg_dump "${global_options[@]}" "${backup_options[@]}")

	# add options
	[ -n "$db_host" ] && cmd+=(-h "$db_host")
	[ -n "$db_port" ] && cmd+=(-p "$db_port")
	[ -n "$db_user" ] && cmd+=(-U "$db_user")
	[ -n "$db_password" ] && PGPASSWORD=$db_password

	# output file
	local file=$1
	shift

	debug "Running ${cmd[*]} $*"
	run_command "${cmd[@]}" "$@" > "$file"
	result=$?

	# reset password
	[ -n "$db_password" ] && PGPASSWORD=""

	return $result
}
