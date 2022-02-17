#
#  time2dump commands
#
#  This file is part of time2dump
#
#  MIT License
#  Copyright (c) 2017-2021 Jean Prunneaux
#

# Index of functions
#
#   t2d_backup
#   t2d_history
#   t2d_rotate


# Perform backup
# Usage: t2d_backup [OPTIONS] [DB_NAME...]
# Exit codes:
#   0: OK
#   1: usage error
#   2: error with paths
t2d_backup() {
	# get options
	while [ $# -gt 0 ] ; do
		case $1 in
			-h|--help)
				print_help
				return 0
				;;
			*)
				break
				;;
		esac
		shift
	done

	local databases=("$@")

	# if database name(s) not specified
	if [ ${#databases[@]} = 0 ] ; then
		lb_display --log "List databases to backup..."

		# get databases from plugin
		lb_cmd_to_array "_${db_protocol}_list_databases"
		if [ $? != 0 ] ; then
			lb_display_error "Database connection failed."
			return 3
		fi

		for db in "${lb_cmd_to_array[@]}" ; do
			[ -z "$db" ] && continue
			if ! lb_in_array "$db" "${ignore_databases[@]}" ; then
				databases+=("$db")
			fi
		done
	fi

	# no databases to backup
	if [ ${#databases[@]} = 0 ] ; then
		lb_warning "Nothing to backup. Please check your config and database connection."
		return 4
	fi

	# get current date
	backup_date=$(date +%Y-%m-%d-%H%M%S)

	# backup each database
	local dumpfile logfile=$destination/$backup_date/time2dump.log

	# create environment
	mkdir -p "$destination/$backup_date"
	if [ $? != 0 ] ; then
		lb_display_error "Cannot create backup destination directory!"
		return 5
	fi

	# set log file
	lb_set_logfile "$logfile"
	if [ $? != 0 ] ; then
		lb_display_error "Cannot create log file!"
		return 6
	fi

	# catch term signals
	trap clean_exit SIGHUP SIGINT SIGTERM

	local -i i=0 res result=0
	for db in "${databases[@]}" ; do
		i+=1
		dumpfile=$destination/$backup_date/$db.sql

		lb_display --log "Backup database $db ($i/${#databases[@]})"

		lb_display --log "Dump..."
		"_${db_protocol}_backup" "$dumpfile" "$db" 2> >(tee -a "$logfile" >&2)
		res=$?

		if [ $res != 0 ] ; then
			lb_display --log "... Failed (code: $res)"
			rm -f "$dumpfile"
			result=4
			continue
		fi

		lb_display --log "Compress..."
		gzip "$dumpfile" 2> >(tee -a "$logfile" >&2)
		if [ $? != 0 ] ; then
			lb_display --log "... Failed (code: $res)"
			result=5
		fi
	done

	if [ $result = 0 ] ; then
		# create latest link (preserve context)
		(cd "$destination" && ln -snf "$backup_date" latest)

		rotate_backups
	fi

	return $result
}


# Get backup history of a database
# Usage: t2d_history [OPTIONS] DB_NAME
# Exit codes:
#   0: OK
#   1: usage error
#   2: error with paths
t2d_history() {
	# get options
	while [ $# -gt 0 ] ; do
		case $1 in
			-q|--quiet)
				quiet_mode=true
				;;
			-h|--help)
				print_help
				return 0
				;;
			*)
				break
				;;
		esac
		shift # load next argument
	done

	# missing arguments
	if [ $# = 0 ] ; then
		print_help
		return 1
	fi

	local database=$*

	# get backup history
	history=($(get_backup_history "$database"))

	# no backup found
	if [ ${#history[@]} = 0 ] ; then
		lb_error "No backup found for '$database'!"
		return 5
	fi

	# print backup versions
	for b in "${history[@]}" ; do
		echo "$b"
	done

	# complete result (not quiet mode)
	if ! lb_istrue $quiet_mode ; then
		echo
		echo "${#history[@]} backups found for $database"
	fi

	return 0
}


# Rotate backups
# Usage: t2d_rotate [OPTIONS] [LIMIT]
# Exit codes:
#   0: OK
#   1: usage error
#   2: error with paths
t2d_rotate() {
	# get options
	while [ $# -gt 0 ] ; do
		case $1 in
			-f|--force)
				force_mode=true
				;;
			-h|--help)
				print_help
				return 0
				;;
			-*)
				print_help
				return 1
				;;
			*)
				break
				;;
		esac
		shift
	done

	local keep=$keep_limit

	# test if specified limit is valid
	if [ $# -gt 0 ] ; then
		if ! lb_is_integer "$1" || [ $1 -lt 0 ] ; then
			print_help
			return 1
		fi
		keep=$1
	fi

	echo "You are about to rotate to keep $keep backup versions."
	lb_istrue $force_mode || lb_yesno "Continue?" || return 0

	rotate_backups $keep || return 5
}
