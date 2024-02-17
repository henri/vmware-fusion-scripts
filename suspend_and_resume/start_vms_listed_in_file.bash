#/bin/bash 

# (C) 2011 Henri Shustak
# Lucid Information Systems
# http://www.lucidsystems.org
# http://www.lucid.technology/tools/vmware/fusion-scripts

# Released under the GNU GPL v3 or later.

# Version history 
# v1.0 - initial release
# v1.1 - improvements relating to vm startup failure reporting
# v1.2 - added the hiding option when resuming VMWare Fusion

# basic script which will attempt to start all VMWare Fusion systems which are listed in a file.

# configuration 

# if the environment variable 'list_started' is set to 'YES' then report the VM's which are started.
if [ "${list_started}" == "" ] ; then
    # when resuming VM's the default is to not report that they have been startd.
    list_started="NO"
fi

# if the environment variable 'list_number_of_vms_started' is set to "YES" then report the number of VM's suspended
if [ "${list_number_of_vms_started}" == "" ] ; then
    # when starting VM's the default is to not report how many have been started.
    list_number_of_vms_started="NO"
fi


# hide vmware on resume option - security warning and security settings information
#
#    note : In order to enable this you will need to grant accessability access to cron, 
#           the terminal or which ever app will kick this script off otherwise key strokes can not be sent ;
#           in addition, cron will probably require full disk permissions and you will need to manually 
#           wait for cron to start the task and then allow accessability access to cron in order to hide VMWare Fusion
#           this is a security risk ; enable at your own risk!
#
#           macOS crontab : /usr/sbin/cron [System Preferences -> Security -> Accesability]
#           macOS common terminals : /Applications/Utilities/Terminal.app /Applications/iTerm.app /Applications/Warp.app etc
#
#           https://stackoverflow.com/questions/72900568/osascript-via-cron-cannot-send-keystrokes-macos
#           execution error: System Events got an error: osascript is not allowed to send keystrokes. (1002)
#           absolute path to "System Events" : "/System/Library/CoreServices/System Events"
#
#           If you see "Operation not permitted" in cron output or system mail, this is likely due to 
#           security / privaicy issues on macOS 10.15 and later. You may need to enable cron to have full disk access
#           again, this is a secuity risk ; enable this option (set to "YES") at your own risk!
#
hide_vmware_fusion_on_resume="NO" # alteratlivy you may want to run VMWare Fusion Headless or Force Quit the front end


# internal variables
OLD_VMRUN_PATH="/Library/Application Support/VMware Fusion/vmrun"
VMRUN_PATH="/Applications/VMware Fusion.app/Contents/Library/vmrun"
num_vms_running=0
run_count=0
max_run_count=2
next_vm_to_start=""
input_file="${1}"
num_arguments=${#}
path_to_vm_to_start="start"
exit_status=0
num_vms_succesfully_started=0
num_vms_failed_to_start=0

# check there is a single parameter passed to this script (input file)
if [ $num_arguments != 1 ] ; then
    echo "ERROR! : This script requires a single argument. The path to an input file."
    echo "         It is expected that this file will contain one or more lines."
    echo "         It is also expected that each line will contain the path to a VM's which is to be started."
    echo "" 
    echo "         Usage : ${0} /path/to/file/containing/list/of/paths/to/vms_to_start.txt"
    echo ""
    exit -1
fi

# try using the old vmrun path should the current path not be available
if ! [ -e "${VMRUN_PATH}" ] ; then VMRUN_PATH="${OLD_VMRUN_PATH}" ; fi

# how many vms are running?
function calculate_num_of_running_vms {
    sync
    num_vms_running=`"${VMRUN_PATH}" list | head -n 1 | awk -F "Total running VMs: " '{print $2}'`
    if [ $? != 0 ] || [ "$num_vms_running" == "" ] ; then
        # report the problem with getting the list of vm's
        echo "    ERROR! : Unable to determine the number of VM instances which are running : ${next_vm_to_start}"
        sleep 3
        sync
        exit -1
    fi
}

# start the next vm
function start_next_vm {
    if [ -e "${next_vm_to_start}" ] ; then 
        sync
        stated_result=`"${VMRUN_PATH}" -T fusion start "${next_vm_to_start}"`
        started_return_code=$?
        if [ ${started_return_code} != 0 ] ; then
            sleep 3
            sync
            return 3
        fi
    else
        echo "    ERROR! : Unable to start the VM; it was not found at the specified path : ${next_vm_to_start}"
	  exit_status=4
        return 4
    fi
    ((num_vms_succesfully_started++))
    return 0
}

# logic
if [ -e "${VMRUN_PATH}" ] ; then
    pre_num_vms_running=calculate_num_of_running_vms
    #read lines from input file until a bank line is found
    exec < $input_file
    next_vm_to_start="---VM---"
    while [ "${next_vm_to_start}" != "" ] ; do
        read next_vm_to_start
        if [ "${next_vm_to_start}" != "" ] ; then
            run_count=0
            while true ; do
                # Attempt to start this VM
                if [ ${run_count} != $max_run_count ] ; then
                    # we have not yet hit the max run count (maximum number of attempts to start the VM
                    start_next_vm
                    start_next_vm_return_code=${?}
                    if [ ${start_next_vm_return_code} == 0 ] || [ ${start_next_vm_return_code} == 4 ] ; then
                        # either the vm was started or it was not available at the path specified.
                        # within the input file.
                        if [ ${start_next_vm_return_code} == 0 ] && [ "${list_started}" == "YES" ] ; then
                            # Report that the VM was started successful if requested.
                            echo "    Successfully started VM : ${next_vm_to_start}"
                        fi
                        break
                    fi
                else
                    break  
                fi
                ((run_count++))
            done
            # if [ ${start_next_vm_return_code} == 3 ] ; then
			if [ ${start_next_vm_return_code} != 0 ] ; then
                # report the problem with starting this VM
                echo "    ERROR! : VM from input file would not able to be started : ${next_vm_to_start}"
				((num_vms_failed_to_start++))
                exit_status=${start_next_vm_return_code}
            fi
        fi
    done
    if [ "${hide_vmware_fusion_on_resume}" == "YES" ] ; then
        # this just switches to VMWare Fusion and Simulates command-h (hide) due to VMWare Fusions lack of AppleScript support
        # another approach could be to minimise the windows (this could potentially leave the app visiable and the library visable)
        echo "    Hiding VMWare Fusion [command-h] (via Apple Script key strokes)"
        osascript -e 'tell application "VMWare Fusion" to activate' && osascript -e 'tell application "System Events" to key code 4 using command down'
        if [ ${?} != 0 ] ; then
            echo "    WARNING! : Unable to hide VMWare Fusion, you will likely need to configure [System Preferences -> Security -> Accessibaility] to allow the terminal / cron"
        fi
    fi
    if [ "${list_number_of_vms_started}" == "YES" ] ; then
        echo "    Total Number of VM's successfully started : ${num_vms_succesfully_started}"
    fi
else
    echo "    ERROR! : Unable to locate the VMWare Fusion run file."
    echo "             Please check that VMware Fusion is installed on this system."
    echo "             File referenced : ${VMRUN_PATH}"
    exit -2
fi


exit ${exit_status}



