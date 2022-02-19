#
#  time2dump global functions
#
#  This file is part of time2dump
#  Source code: https://github.com/time2backup/time2dump
#

backup_date_format="[1-9][0-9]{3}-[0-1][0-9]-[0-3][0-9]-[0-2][0-9][0-5][0-9][0-5][0-9]"
current_timestamp=$(date +%s)

# Index of functions
#
#   debug
#   test_period
#   period2seconds
#   check_backup_date
#   check_config
#   run_command
#   get_backups
#   get_backup_date
#   get_backup_history
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


# Test if a string is a period
# Usage: test_period PERIOD
# Exit codes:
#   0: period is valid
#   1: not valid syntax
test_period() {
	echo "$*" | grep -Eq "^[1-9][0-9]*(m|h|d)$"
}


# Convert a period in seconds
# Usage: period2seconds N(m|h|d)
# Return: seconds
period2seconds() {
	# convert minutes then to seconds
	echo $(($(echo "$*" | sed 's/m//; s/h/\*60/; s/d/\*1440/') * 60))
}


# Check syntax of a backup date
# Usage: check_backup_date DATE
# Dependencies: $backup_date_format
# Exit codes:
#   0: OK
#   1: non OK
check_backup_date() {
	echo $1 | grep -Eq "^$backup_date_format$"
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
	ls "$destination" 2> /dev/null | grep -E "^$backup_date_format$"
}


# Get readable backup date
# Usage: get_backup_date [OPTIONS] YYYY-MM-DD-HHMMSS
# Options:
#   -t  Get timestamp instead of date
# Dependencies: $tr_readable_date
# Return: backup datetime (format YYYY-MM-DD HH:MM:SS)
# e.g. 2016-12-31-233059 -> 2016-12-31 23:30:59
# Exit codes:
#   0: OK
#   1: format error
get_backup_date() {
	local format="%Y-%m-%d at %H:%M:%S"

	# get timestamp option
	if [ "$1" = '-t' ] ; then
		format='%s'
		shift
	fi

	# test backup format
	check_backup_date "$*" || return 1

	# get date details
	local byear=${1:0:4} bmonth=${1:5:2} bday=${1:8:2} \
	      bhour=${1:11:2} bmin=${1:13:2} bsec=${1:15:2}

	# return date formatted for languages
	case $lb_current_os in
		BSD|macOS)
			date -j -f "%Y-%m-%d %H:%M:%S" "$byear-$bmonth-$bday $bhour:$bmin:$bsec" +"$format"
			;;
		*)
			date -d "$byear-$bmonth-$bday $bhour:$bmin:$bsec" +"$format"
			;;
	esac
}


# Get backup history of a database
# Usage: get_backup_history [OPTIONS] DATABASE
# Options:
#   -l  get only last version
#   -z  except latest backup
# Dependencies: $destination
# Return: dates (YYYY-MM-DD-HHMMSS format)
# Exit codes:
#   0: OK
#   1: usage error
#   2: no backups found
#   3: cannot found backups (no absolute path, deleted parent directory)
get_backup_history() {
	# default options
	local last_version=false not_latest=false

	# get options
	while [ $# -gt 0 ] ; do
		case $1 in
			-l)
				last_version=true
				;;
			-z)
				not_latest=true
				;;
			*)
				break
				;;
		esac
		shift # load next argument
	done

	# usage error
	[ $# = 0 ] && return 1

	# get all backups
	local all_backups=($(get_backups))

	# no backups found
	[ ${#all_backups[@]} = 0 ] && return 2

	# get backup path
	local database=$*

	# prepare for loop
	local date first=true
	local -i i nb_versions=0

	# try to find database from latest backup to oldest
	for ((i=${#all_backups[@]}-1 ; i>=0 ; i--)) ; do

		date=${all_backups[i]}

		# if backup file does not exists, continue
		[ -f "$destination/$date/$database.sql.gz" ] || continue

		# except the latest
		if $not_latest && $first ; then
			first=false
			continue
		fi

		# if get only last version, print and exit
		if $last_version ; then
			echo $date
			return 0
		fi

		echo $date
		nb_versions+=1
	done

	[ $nb_versions -gt 0 ] || return 2
}


# Delete a backup
# Usage: delete_backup DATE_REFERENCE
# Dependencies: $destination
# Exit codes:
#   0: delete OK
#   1: usage error
#   2: rm error
delete_backup() {
	[ -z "$1" ] && return 1

	# test mode: no delete
	lb_istrue $test_mode && return 0

	# delete backup directory
	debug "Deleting $destination/$1..."
	if ! rm -rf "$destination/$1" ; then
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

	# clean based on number of backups
	if lb_is_integer $limit ; then
		# always keep nb + 1 (do not delete latest backup)
		limit=$(($limit + 1))

		# if limit not reached, do nothing
		[ $nb_backups -le $limit ] && return 0

		debug "Clean to keep $limit backups on $nb_backups"

		# get old backups until max - nb to keep
		to_rotate=(${all_backups[@]:0:$(($nb_backups - $limit))})

	else
		# clean based on time periods
		local t time_limit=$(($current_timestamp - $(period2seconds $limit)))

		for b in "${all_backups[@]}" ; do
			# do not delete the only backup
			[ $nb_backups -le 1 ] && break

			# get timestamp of this backup
			t=$(get_backup_date -t $b)
			lb_is_integer $t || continue

			# time limit reached: stop iterate
			[ $t -ge $time_limit ] && break

			debug "Clean old backup $b because > $limit"

			# add backup to list to clean
			to_rotate+=("$b")

			# decrement nb of current backups
			nb_backups=$(($nb_backups - 1))
		done
	fi

	# nothing to clean: quit
	if [ ${#to_rotate[@]} = 0 ] ; then
		debug "Nothing to rotate"
		return 0
	fi

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
