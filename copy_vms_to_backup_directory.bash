#/bin/bash

# Lucid Information Systems
# http://www.lucidsystems.org

# Version 1.0 initial release

# Released under the GNU GPL v3 or later.

# This is a basic example script which simply rsync's the (probably) suspended VM's from one directory to another.
# you will need to edit this script to make it work for your setup and installation enviroment.

##
## Danger : This script is running rsync with the --delete command. You must be very carful not to delete important files. 
##          Suggestion is to use -n (dry run) and -v (verbose) flag for testing before running for real!

# Copy the VM's
rsync -a -E --delete --exclude="virtual_machines/test" --exclude="virtual_machines/backups" "/Volumes/source-volume-name/virtual_machines" "/Volumes/destination-volume-name/virtual_machines/backups/"
exit $?
