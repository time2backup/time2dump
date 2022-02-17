#
#  time2dump help functions
#
#  This file is part of time2dump
#
#  MIT License
#  Copyright (c) 2017-2021 Jean Prunneaux
#

# Print help for users in console
# Usage: print_help [global]
print_help() {
	echo
	echo "Usage: time2dump [GLOBAL_OPTIONS] COMMAND [OPTIONS] [ARG...]"
	echo
	echo "Global options:"
	echo "  -c, --config FILE  Use custom config file"
	echo "  -h, --help         Print help"
	echo

	if [ "$1" = global ] ; then
		echo "Commands:"
		echo "   backup     Backup databases"
		echo "   history    Displays backup history of a database"
		echo "   rotate     Rotate backups"
		echo
		echo "Run 'time2dump COMMAND --help' for more information on a command."
		return 0
	fi

	case $command in
		backup)
			print_help_usage "[DATABASE...]"
			echo "Backup databases"

			print_help_options #backup
			echo "  -h, --help  Print help"
			;;
		history)
			print_help_usage "DATABASE"
			echo "Get backup history of a database"

			print_help_options #history
			echo "  -q, --quiet  Quiet mode; print only backup dates"
			echo "  -h, --help   Print help"
			;;
		rotate)
			print_help_usage "[LIMIT]"
			echo "Rotate backups"

			print_help_options #rotate
			echo "   -f, --force  Force mode, do not confirm"
			echo "   -h, --help   Print help"
			;;
	esac
}


# Print help usage
# Usage: print_help_usage [ARG...]
print_help_usage() {
	echo "Command usage: $command [OPTIONS] $*
"
}


# Print options text
# Usage: print_help_options
print_help_options() {
	echo "
Options:"
}
