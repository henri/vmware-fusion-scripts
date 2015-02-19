#/bin/bash 

# (C) 2011 Henri Shustak
# Lucid Information Systems
# http://www.lucidsystems.org
# http://www.lucid.technology/tools/vmware/fusion-scripts

# Released under the GNU GPL v3 or later.

# Version history 
# v1.0 - initial release
# v1.1 - added optional reporting of VM's which are suspended by the script
# v1.2 - added support for VMWare Fusion 4 and later
# v1.3 - added additional reporting feature, including the ability generate a file containing a list of vm's which have been suspended.

# basic script which will attempt to suspend all VMWare Fusion systems running on a system.

# configuration 

# if the environment variable 'list_suspended' is set to 'YES' then report the VM's which are suspended.
if [ "${list_suspended}" == "" ] ; then
    # when suspending VM's the default is to not report that they have been suspended.
    list_suspended="NO"
fi

# if the environment variable 'list_number_of_vms_suspended' is set to "YES" then report the number of VM's suspended
if [ "${list_number_of_vms_suspended}" == "" ] ; then
    # when suspending VM's the default is to not report how many have been suspended.
    list_number_of_vms_suspended="NO"
fi

# if the environment variable 'write_paths_for_suspended_vms_to_file' is set to "YES" then erase the file
# which is passed into this script as the first argument and then update this file with a list of the VM's
# that have been successfully suspended during the execution of this script.
if [ "${write_paths_for_suspended_vms_to_file}" == "" ] ; then
    # when suspending VM's the default is to not report how many have been suspended.
    write_paths_for_suspended_vms_to_file="NO"
fi


# internal variables
OLD_VMRUN_PATH="/Library/Application Support/VMware Fusion/vmrun"
VMRUN_PATH="/Applications/VMware Fusion.app/Contents/Library/vmrun"
num_vms_running=0
run_count_multiplier=2
run_count=0
max_run_count=0 
next_vm_to_suspend=""
num_vms_succesfully_suspended=0
output_file_path_for_list_of_suspended_vms="${1}"

# out put file checks
if [ "${output_file_path_for_list_of_suspended_vms}" == "" ] && [ "${write_paths_for_suspended_vms_to_file}" == "YES" ] ; then
    write_paths_for_suspended_vms_to_file="NO"
    echo "    WARNING! : Suspended VM's will not be written to disk as there was no output file provided."
fi
if [ "${write_paths_for_suspended_vms_to_file}" == "YES" ] ; then
    touch "${output_file_path_for_list_of_suspended_vms}"
    if [ $? != 0 ] || ! [ -w "${output_file_path_for_list_of_suspended_vms}" ] ; then
        echo "    WARNING! : Suspended VM's will not be written to disk because the specified file was not able to be modified."
    fi
fi
if [ "${write_paths_for_suspended_vms_to_file}" != "YES" ] && [ "${output_file_path_for_list_of_suspended_vms}" != "" ] ; then
    echo "    WARNING! : The variable 'write_paths_for_suspended_vms_to_file' is not set to a value other than \"YES\""
    echo "               and an output file was specified was specified \(first argument passed to this script\)."
    echo "               Please note, that if the enviroment variable is set to \"YES\" and this script executed,"
    echo "               then the output (file specified as the first argument to this this script) will be deleted"
    echo "               should it exit at the path specified."
fi

# try using the old vmrun path should the current path not be available
if ! [ -e "${VMRUN_PATH}" ] ; then VMRUN_PATH="${OLD_VMRUN_PATH}" ; fi

# how many vms are running?
function calculate_num_vms_to_suspend {
    sync
    num_vms_running=`"${VMRUN_PATH}" list | head -n 1 | awk -F "Total running VMs: " '{print $2}'`
    if [ $? != 0 ] || [ "$num_vms_running" == "" ] ; then
        # report the problem with getting the list of vm's
        echo "    ERROR! : Unable to determine the number of VM instances which are running : ${next_vm_to_suspend}"
        sleep 3
        sync
        exit -1
    fi
}

# get path to the vm we will try to suspend next
function calculate_path_to_next_vm_to_suspend {
    next_vm_to_suspend=`"${VMRUN_PATH}" list | head -n 2 | tail -n 1`
    if [ $? != 0 ] || [ "$num_vms_running" == "" ] ; then
        # report the problem with getting the list of vm's
        echo "    ERROR! : Unable to determine the path to the next VM instances to suspend : ${next_vm_to_suspend}"
        sleep 3
        sync
        exit -5
    fi
}

# suspend next vm
function suspend_next_vm {
    if [ "${next_vm_to_suspend}" != "" ] ; then 
        sync
        suspend_result=`"${VMRUN_PATH}" -T fusion suspend "${next_vm_to_suspend}"`
        if [ $? != 0 ] ; then
            # report the problem with suspending this VM
            echo "    ERROR! : Unable to suspend VM : ${next_vm_to_suspend}"
            sleep 3
            sync
        else
            ((num_vms_succesfully_suspended++))
            if [ "${list_suspended}" == "YES" ] ; then
                echo "    Successfully suspended VM : ${next_vm_to_suspend}"
            fi
            if [ "${write_paths_for_suspended_vms_to_file}" == "YES" ] ; then
                echo "${next_vm_to_suspend}" >> "${output_file_path_for_list_of_suspended_vms}"
                if [ $? != 0 ] ; then
                    echo "ERROR! : Unable to append this VM which has been suspended to the output file specified."
                    echo "             VM successfully suspended : ${next_vm_to_suspend}"
                    echo "             Output file specified : ${output_file_path_for_list_of_suspended_vms}"
                fi
            fi
        fi
    else
        # this check is not essential as it is covered by another function
        calculate_num_vms_to_suspend
        if [ ${num_vms_running} == 0 ] ; then
            echo "    ERROR! : No VM instances was found to suspend."
            exit -3
        else
            echo "    ERROR! : VM instances was found to suspend, but was not able to determine the path within the filesystem."
            exit -4
        fi
    fi
}

# logic
if [ -e "${VMRUN_PATH}" ] ; then
    calculate_num_vms_to_suspend
    if [ "${write_paths_for_suspended_vms_to_file}" == "YES" ] ; then
        cat /dev/null > "${output_file_path_for_list_of_suspended_vms}"
    fi
    max_run_count=`echo "$num_vms_running * ${run_count_multiplier}" | bc`
    while [ $num_vms_running != 0 ] ; do
        # One or more VM's are running and will try attempt to suspend.
        if [ ${run_count} != $max_run_count ] || [ $num_vms_running != 0 ] ; then
            # we have not hix the max run count
            calculate_path_to_next_vm_to_suspend
            suspend_next_vm
        else
          break  
        fi
        ((run_count++))
        calculate_num_vms_to_suspend
    done
    if [ "${list_number_of_vms_suspended}" == "YES" ] ; then
        echo "    Total Number of VM's successfully suspended : ${num_vms_succesfully_suspended}"
    fi
else
    echo "    ERROR! : Unable to locate the VMWare Fusion run file."
    echo "             Please check that VMware Fusion is installed on this system."
    echo "             File referenced : ${VMRUN_PATH}"
    exit -2
fi



exit 0

