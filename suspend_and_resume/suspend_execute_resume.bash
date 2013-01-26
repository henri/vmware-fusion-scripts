#/bin/bash 

# (C) 2011 Henri Shustak
# Lucid Information Systems
# http://www.lucidsystems.org

# Released under the GNU GPL v3 or later.

# Version history 
# v1.0 - initial release

# 
# This script is designed to suspend the VMware Fusion VM's running on this machine, 
# execute a script (passed to this script as the first argument) and then resume the
# VMware Fusion VM's which were suspended during the first phase of this script.
#
# Note : This script will not check if the VM's on this system are successfully suspended or restarted. 
#        If such checks are required then the use of a separate system is recommended.
#        This script is primarily designed to provide an interface to simplify the manipulation of VM's in a 
#        suspended state as wright forward as possible.
#

# helper script paths
name_of_suspend_script="suspend_running_vms.bash"
name_of_resume_script="start_vms_listed_in_file.bash"
path_to_script_to_perform_copy="${1}"
parent_directory=`dirname "${0}"`

# path to file which will be used to store a list of VM's which are stopped and then hopefully restarted.
suspended_vm_file_list=`mktemp -q /tmp/vm_stop_start_list.XXXXXXX`
if [ $? != 0 ] ; then
    echo "ERROR! : Unable to generate temporary file"
    exit -4
fi

vm_suspend_script_output=`mktemp -q /tmp/vm_suspend_script_output.XXXXXXX`
if [ $? != 0 ] ; then
    echo "ERROR! : Unable to generate temporary file"
    exit -5
fi

vm_start_script_output=`mktemp -q /tmp/vm_start_script_output.XXXXXXX`
if [ $? != 0 ] ; then
    echo "ERROR! : Unable to generate temporary file"
    exit -6
fi




# internal variables
exit_status=0
start_vms_on_clean_exit="YES"
num_arguments=${#}
num_vms_suspended=0
num_vms_started=0
number_of_vms_stopped_is_the_same_as_those_started="NO"

######
###### Functions
######

function clean_exit {
    if [ "${start_vms_on_clean_exit}" == "YES" ] ; then
        start_vms_on_clean_exit="NO"
        start_vms_which_were_suspended
    fi
    if [ ${num_vms_suspended} != ${num_vms_started} ] ; then
        echo "`date` : ERROR! : The number of VM's suspended differs from the number of VM's which were started."
    fi
    rm -f "${suspended_vm_file_list}"
    rm -f "${vm_suspend_script_output}"
    rm -f "${vm_start_script_output}"
    exit ${exit_status}
}

function start_vms_which_were_suspended {
    export list_started="YES"
    export list_number_of_vms_started="YES"
    "${parent_directory}/${name_of_resume_script}" "${suspended_vm_file_list}" | tee -a "${vm_start_script_output}"
    vm_start_status_return_code=$PIPESTATUS
    num_vms_started=`cat "${vm_start_script_output}" | grep "Total Number of VM's successfully started : " | awk -F "Total Number of VM's successfully started : " '{print $2}'`
    if [ ${vm_start_status_return_code} != 0 ] ; then
        echo "ERROR! : There were problems starting one or more of the VM's."
        start_vms_on_clean_exit="NO"
        exit_status=2
        clean_exit
    fi
    return 0
}


######
###### Pre-flight checks
######

# check there is a single parameter passed to this script (backup script)
if [ $num_arguments != 1 ] ; then
    echo "ERROR! : This script requires a single argument, the path to a script which will"
    echo "         be executed while the VM's are suspended."
    echo ""
    echo "         Usage : ${0} /path/to/backup/script.sh"
    echo ""
    start_vms_on_clean_exit="NO"
    exit_status=-1
    clean_exit
fi

# check that the script provided is availible
if ! [ -e "${path_to_script_to_perform_copy}" ] ; then
    echo "ERROR! : The script provided is not available. No VM's will be suspended or resumed."
    start_vms_on_clean_exit="NO"
    exit_status=-2
    clean_exit
fi

# check that the script provided is is executable
if ! [ -x "${path_to_script_to_perform_copy}" ] ; then
    echo "ERROR! : The script provided is not executable. No VM's will be suspended or resumed."
    start_vms_on_clean_exit="NO"
    exit_status=-3
    clean_exit
fi


######
###### Logic
######

# suspend the vm's on this system
echo "`date` : Suspending VM's…"
export list_suspended="YES"
export list_number_of_vms_suspended="YES"
export write_paths_for_suspended_vms_to_file="YES"
"${parent_directory}/${name_of_suspend_script}" "${suspended_vm_file_list}" | tee -a "${vm_suspend_script_output}"
vm_suspend_status_return_code=$PIPESTATUS
num_vms_suspended=`cat "${vm_suspend_script_output}" | grep "Total Number of VM's successfully suspended : " | awk -F "Total Number of VM's successfully suspended : " '{print $2}'`
if [ $vm_suspend_status_return_code != 0 ] ; then
    echo "ERROR! : Unable to suspend one or more VM's. Backup has been canceled"
    exit_status=1
    clean_exit
fi
sleep 1
sync

# execute the script provided.
echo "`date` : Executing ${path_to_script_to_perform_copy}"
"${path_to_script_to_perform_copy}"
if [ $? != 0 ] ; then
    echo "ERROR! : There was an issue running the backup script."
    clean_exit
fi

sleep 1
sync

# start up the VM's which were suspended.
echo "`date` : Resuming the VM's..."
start_vms_which_were_suspended
if [ $? == 0 ] && [ ${num_vms_suspended} == ${num_vms_started} ] ; then
    start_vms_on_clean_exit="NO"
    echo "`date` : VM's successfully resumed."
fi


clean_exit




