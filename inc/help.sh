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
		echo "   rotate     Rotate backups"
		echo
		echo "Run 'time2dump COMMAND --help' for more information on a command."
		return 0
	fi

	case $command in
		backup)
			echo "Command usage: $command [OPTIONS] [DB_NAME...]"
			echo
			echo "Backup databases"
			echo
			echo "Options:"
			echo "  -h, --help  Print help"
			;;
		rotate)
			echo "Command usage: $command [OPTIONS] [LIMIT]"
			echo
			echo "Rotate backups"
			echo
			echo "Options:"
			echo "   -f, --force  Force mode, do not confirm"
			echo "   -h, --help   Print help"
			;;
	esac
}
