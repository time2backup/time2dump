#
#  time2dump global functions
#
#  This file is part of time2dump
#
#  MIT License
#  Copyright (c) 2017-2021 Jean Prunneaux
#

# Index
#
#   debug
#   check_config
#   run_command
#   get_backups
#   delete_backup
#   rotate_backups
#   clean_empty_backup
#   clean_exit


# Display a debug message
# Usage: debug TEXT
# Dependencies: $debug_mode
debug() {
	lb_istrue $debug_mode || return 0
	lb_debug "$*"
}


# Check config
# Usage: check_config
check_config() {
	if [ -z "$destination" ] ; then
		lb_display_error "Destination path not defined. Please set it in config file."
		return 1
	fi

	if [ -z "$db_protocol" ] ; then
		lb_display_error "Protocol not defined. Please set it in config file."
		return 1
	fi

	# Default values
	if ! lb_is_integer "$keep_limit" || [ $keep_limit -lt -1 ] ; then
		keep_limit=10
	fi
}


# Run a command
# Usage: run_command COMMAND [ARGS]
run_command() {
	local cmd=()

	# sudo mode
	[ -n "$sudo_user" ] && cmd=(sudo -u "$sudo_user")

	cmd+=("$@")

	# run command
	"${cmd[@]}"
}


# Get all backup dates
# Usage: get_backups
# Dependencies: $destination, $backup_date_format
# Return: dates list (format YYYY-MM-DD-HHMMSS)
# Exit codes:
#   0: OK
#   1: nothing found
get_backups() {
	local backup_date_format="[1-9][0-9]{3}-[0-1][0-9]-[0-3][0-9]-[0-2][0-9][0-5][0-9][0-5][0-9]"
	lb_istrue $archive_backups && backup_date_format+="\.tar"
	ls "$destination" 2> /dev/null | grep -E "^$backup_date_format$"
}


# Delete a backup
# Usage: delete_backup DATE_REFERENCE
# Dependencies: $destination
# Exit codes:
#   0: delete OK
#   1: usage error
#   2: rm error
delete_backup() {
	# usage error
	[ -z "$1" ] && return 1

	# test mode: no delete
	lb_istrue $test_mode && return 0

	# delete backup directory
	debug "Deleting $destination/$1..."
	rm -rf "$destination/$1"
	if [ $? != 0 ] ; then
		lb_display_error --log "Failed to delete backup $1! Please delete this folder manually."
		return 2
	fi
}


# Clean old backups
# Usage: rotate_backups [LIMIT]
# Dependencies: $keep_limit
# Exit codes:
#   0: rotate OK
#   1: usage error
#   2: nothing rotated
#   3: delete error
rotate_backups() {
	local limit=$keep_limit

	# limit specified
	[ -n "$1" ] && limit=$1

	# if unlimited, do not rotate
	[ "$limit" = -1 ] && return 0

	# get all backups
	local all_backups=($(get_backups)) b to_rotate=()
	local nb_backups=${#all_backups[@]}

	# always keep nb + 1 (do not delete latest backup)
	limit=$(($limit + 1))

	# if limit not reached, do nothing
	[ $nb_backups -le $limit ] && return 0

	debug "Clean to keep $limit backups on $nb_backups"

	# get old backups until max - nb to keep
	to_rotate=(${all_backups[@]:0:$(($nb_backups - $limit))})

	# nothing to clean: quit
	if [ ${#to_rotate[@]} = 0 ] ; then
		debug "Nothing to rotate"
		return 0
	fi

	lb_display --log
	lb_display --log "Cleaning old backups..."

	# remove backups from older to newer
	local result=0
	for b in "${to_rotate[@]}" ; do
		delete_backup "$b" || result=3
	done

	return $result
}


# Delete empty backup directory
# Usage: clean_empty_backup BACKUP_DATE
# Exit codes:
#   0: cleaned
#   1: usage error or path is not a directory
clean_empty_backup() {
	# backup date not defined: usage error
	[ -n "$1" ] || return 1

	# if backup does not exists, quit
	[ -d "$destination/$1" ] || return 0

	# if not empty, do nothing
	lb_is_dir_empty "$destination/$1" || return 0

	debug "Clean empty backup: $1"

	# delete and prevent loosing context
	(cd "$destination" &> /dev/null && rmdir "$1" &> /dev/null)

	return 0
}


# Clean things before exit
# Usage: clean_exit [EXIT_CODE]
clean_exit() {
	# clear all traps to avoid infinite loop if following commands takes some time
	trap - 1 2 3 15
	trap

	# set exit code if specified
	[ -n "$1" ] && lb_exitcode=$1

	debug "Clean exit"

	clean_empty_backup $backup_date

	debug "Exited with code: $lb_exitcode"

	lb_exit
}
