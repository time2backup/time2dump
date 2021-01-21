#!/bin/bash
#
#  time2dump
#
#  Backup your databases
#
#  MIT License
#  Copyright (c) 2017-2021 Jean Prunneaux
#
#  Version 1.4.0 (2021-01-21)
#

declare -r version=1.4.0


#
#  Initialization
#

# get real path of the script
if [ "$(uname)" = Darwin ] ; then
	# macOS which does not support readlink -f option
	current_script=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' "$0")
else
	current_script=$(readlink -f "$0")
fi

# get directory of the current script
script_directory=$(dirname "$current_script")

# load libbash
source "$script_directory"/libbash/libbash.sh - > /dev/null
if [ $? != 0 ] ; then
	echo >&2 "Error: cannot load libbash. Please add it to the '$script_directory/libbash' directory."
	exit 1
fi

# load functions
source "$script_directory"/inc/functions.sh > /dev/null
if [ $? != 0 ] ; then
	lb_error "Error: cannot load functions!"
	exit 1
fi

# load commands
source "$script_directory"/inc/commands.sh > /dev/null
if [ $? != 0 ] ; then
	lb_error "Error: cannot load commands!"
	exit 1
fi

# load help
source "$script_directory"/inc/help.sh > /dev/null
if [ $? != 0 ] ; then
	lb_error "Error: cannot load help!"
	exit 1
fi


#
#  Main Program
#

# get global options
while [ $# -gt 0 ] ; do
	case $1 in
		-c|--config)
			# custom config path
			if ! [ -f "$2" ] ; then
				print_help global
				exit 1
			fi
			config_file=$2
			shift
			;;
		-D|--debug)
			debug_mode=true
			;;
		-V|--version)
			echo $version
			exit
			;;
		-h|--help)
			print_help global
			exit
			;;
		-*)
			print_help global
			exit 1
			;;
		*)
			break
			;;
	esac
	shift # load next argument
done

# load default config file if not specified
if [ -z "$config_file" ] ; then
	# search config first in current directory, then in /etc
	for f in "$script_directory"/config/time2dump.conf /etc/time2dump.conf ; do
		if [ -f "$f" ] ; then
			config_file=$f
			break
		fi
	done

	if [ -z "$config_file" ] ; then
		lb_error "No config file found"
		exit 1
	fi
fi

lb_set_log_level INFO
lb_istrue $debug_mode && lb_set_log_level DEBUG

# analyse config template
if ! lb_read_config -a "$script_directory"/config/time2dump.example.conf ; then
	lb_error "Failed to load config template"
	exit 3
fi

# load config file
if ! lb_import_config "$config_file" "${lb_read_config[@]}" ; then
	lb_error "Failed to load config"
	exit 3
fi

# check config
check_config || exit 3

# load plugin
source "$script_directory"/plugins/"$db_protocol".sh > /dev/null
if [ $? != 0 ] ; then
	lb_error "Error: cannot load plugin for protocol $db_protocol!"
	exit 1
fi

# check plugin functions
for f in list_databases backup ; do
	if ! lb_function_exists "_${db_protocol}_$f" ; then
		lb_error "Error: plugin not compliant"
		exit 1
	fi
done

# backup is the default command
if [ $# = 0 ] ; then
	command=backup
else
	command=$1
	shift
fi

# run command
case $command in
	backup|rotate)
		t2d_$command "$@"
		clean_exit $?
		;;
	help)
		print_help global
		;;
	*)
		# unknown command
		print_help global
		exit 1
		;;
esac
