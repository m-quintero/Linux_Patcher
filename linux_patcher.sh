#!/bin/bash

# Script Name: linux_patcher
# Version: 2.1.1
# Author: Michael Quintero, michael.quintero@rackspace.com
# Description: This script can help automate much of not all of the standard patching process. It features an option set for running interactively, manually, or even just a quick QC check, and generates a log file in the $CHANGE directory. Has logic to determine if the patch and reboot has already occurred and will continue with the reamining portion of the patch process, after reboot. Currently, the version only support Red Hat 7, 8, and 9. Ubuntu patching will be integrated in the future.

if [[ "$EUID" -ne 0 ]]; then
   echo "This script must be run as root. Goodbye!" 
   exit 1
fi

check_distribution_and_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            "rhel"|"centos"|"amzn")
                case $VERSION_ID in
                    7)
                        [ "$ID" != "amzn" ] && rhel_7_path || echo "Amazon Linux does not have a version 7."
                        ;;
                    8|9)
                        [ "$ID" != "amzn" ] && rhel_8_9_path || echo "Amazon Linux does not have a version 8 or 9."
                        ;;
                    "2")
                        [ "$ID" == "amzn" ] && amazon_linux_2_path || echo "This case is for Amazon Linux 2."
                        ;;
                    *)
                        echo "Unsupported version: $VERSION_ID for $ID."
                        ;;
                esac
                ;;
            "ubuntu"|"debian")
                ubuntu_debian_path  # Assuming you create a function to handle Ubuntu/Debian-specific actions
                ;;
            *)
                echo "This system does not appear to be running a supported version of Red Hat, CentOS, Amazon Linux, Ubuntu, or Debian."
                ;;
        esac
    else
        echo "Unable to determine the distribution as /etc/os-release is missing."
    fi
}

falcon_check() {
    if pgrep -f "/opt/CrowdStrike/falcond" > /dev/null 2>&1; then
        echo "Falconctl is running. Checking kernel version compatibility."

        next_kernel_version=$(yum check-update kernel | grep -E 'kernel.x86_64*' | awk '{print $2}')

        if [[ -z "$next_kernel_version" ]]; then
            echo "No kernel updates found. Running yum update-minimal with kernel exclusion."
            yum update-minimal --security --exclude=kernel* -y
            return 
        fi

        falcon_check_output=$(/opt/CrowdStrike/falcon-kernel-check -k "$next_kernel_version" 2>&1)
        if echo "$falcon_check_output" | grep -q "is not supported by Sensor"; then
            echo "Next kernel version is not supported by Falcon Sensor. Running yum update with kernel exclusion."
            yum update-minimal --security --exclude=kernel* -y
        elif echo "$falcon_check_output" | grep -q "Crowdstrike Not Found"; then
            echo "CrowdStrike command failure: Crowdstrike Not Found."
            yum update --security -y
        else
            echo "Next kernel version is supported by Falcon Sensor. Running full yum update."
            yum update --security -y
        fi
    else
        echo "Falconctl binary is not found or not running. Performing yum update."
        yum update --security -y
    fi
}

instance_details() {
    echo "Red Hat Version : $(cat /etc/redhat-release)"
    echo "Current Kernel: $(uname -r)"  
}

rhel_7_path() {
    next_kernel=$(yum check-update kernel | grep -Eo 'kernel.x86_64\s+[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+\.el7' | awk '{print $2}')
    echo "Next Kernel Version: ${next_kernel}"
    sleep 5
    yum updateinfo list security installed | grep RHSA > /root/$CHANGE/security_installed.before
}

rhel_8_9_path() {
    next_kernel=$(dnf check-update kernel | grep -Eo 'kernel.x86_64\s+[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+\.el8' | awk '{print $2}')
    echo "Next Kernel Version: ${next_kernel}"
    sleep 5
    dnf updateinfo list security installed | grep RHSA > /root/$CHANGE/security_installed.before
}

ubuntu_debian_path() {
    echo "Debian Found"
}

amazon_linux_2_path() {
    echo "AMAZON Linux Found"
}
rhel_7_post_op() {
    yum updateinfo list security installed | grep RHSA > /root/$CHANGE/security_installed.after
}

rhel_8_9_post_op() {
    dnf updateinfo list security installed | grep RHSA > /root/$CHANGE/security_installed.after
}

rhel_post_op() {
    local distro_info=$(cat /etc/redhat-release)

    if [[ "$distro_info" == *"Red Hat Enterprise Linux Server release 7"* ]]; then
        echo "Running operations for Red Hat Enterprise Linux 7"
        rhel_7_post_op
    elif [[ "$distro_info" == *"Red Hat Enterprise Linux release 8"* ]] || [[ "$distro_info" == *"Red Hat Enterprise Linux release 9"* ]]; then
        echo "Running operations for Red Hat Enterprise Linux 8 or 9"
        rhel_8_9_post_op
    else
        echo "Unsupported Red Hat Enterprise Linux version or not a Red Hat distribution."
    fi
}

before_markers() {
    ss -ntlp | awk '{print $6}' | awk -F ':' '{print $NF}' | sort | uniq > /root/$CHANGE/netstat_running.before
    ps -e -o ppid,pid,cmd | egrep '^\s+1\s+' > /root/$CHANGE/ps_running.before
    systemctl list-units --type=service > /root/$CHANGE/systemctl_running.before
    mount > /root/$CHANGE/mount.before
    uname -r > /root/$CHANGE/kernel.before
    echo "Hostname: $(hostname)" && echo "IP Address: $(hostname -I)" > /root/$CHANGE/hostname_info.before
    echo "/etc/hosts checksum: $(md5sum /etc/hosts | cut -d ' ' -f1)" > /root/$CHANGE/hosts_info.before 
    echo "/etc/resolv.conf checksum: $(md5sum /etc/resolv.conf | cut -d ' ' -f1)" > /root/$CHANGE/resolv_info.before
}

after_markers() {
    ss -ntlp | awk '{print $6}' | awk -F ':' '{print $NF}' | sort | uniq > /root/$CHANGE/netstat_running.after
    ps -e -o ppid,pid,cmd | egrep '^\s+1\s+' > /root/$CHANGE/ps_running.after
    systemctl list-units --type=service > /root/$CHANGE/systemctl_running.after
    mount > /root/$CHANGE/mount.after
    uname -r > /root/$CHANGE/kernel.after
    grep .service /root/$CHANGE/systemctl_running.before | awk '{print $1,$2,$3,$4}' | sort > /root/$CHANGE/systemctl_running.before.1
    grep .service /root/$CHANGE/systemctl_running.after | awk '{print $1,$2,$3,$4}' | sort > /root/$CHANGE/systemctl_running.after.1
    grep ^/dev /root/$CHANGE/mount.before > /root/$CHANGE/mount.before.1
    grep ^/dev /root/$CHANGE/mount.after > /root/$CHANGE/mount.after.1
    /opt/CrowdStrike/falconctl -g --rfm-state
    diff -U0 /root/$CHANGE/systemctl_running.before.1 /root/$CHANGE/systemctl_running.after.1
    diff -U0 /root/$CHANGE/mount.before.1 /root/$CHANGE/mount.after.1
    echo "Hostname: $(hostname)" && echo "IP Address: $(hostname -I)" > /root/$CHANGE/hostname_info.after
    echo "/etc/hosts checksum: $(md5sum /etc/hosts | cut -d ' ' -f1)" > /root/$CHANGE/hosts_info.after
    echo "/etc/resolv.conf checksum: $(md5sum /etc/resolv.conf | cut -d ' ' -f1)" > /root/$CHANGE/resolv_info.after
}

maintenance_report() {
    maintdate=$(date "+%d %b %Y")
    
    if [ -z "$CHANGE" ]; then
        echo "CHANGE variable not set. Exiting."
        return 1
    fi

    LOG_FILE="/root/$CHANGE/maintenancelog.txt"

    {
        echo "===== Maintenance report for $(hostname -s) ====="
        echo "(Current date): $(date)"
        echo "(Server running since): $(uptime -s)"
        echo "(Packages installed during maintenance): $(rpm -qa --last | grep "$maintdate" | wc -l)"
        echo "(Previous running kernel version): $(cat /root/$CHANGE/kernel.before)"
        echo "(Current running kernel version): $(uname -r)"
        echo "(Kernel packages installed during maintenance):"
        rpm -qa --last | grep "$maintdate" | grep kernel

        hostname_changed=$(diff <(grep 'Hostname' /root/$CHANGE/hostname_info.before) <(grep 'Hostname' /root/$CHANGE/hostname_info.after) > /dev/null && echo "No" || echo "Yes")
        hosts_changed=$(diff <(grep '/etc/hosts checksum' /root/$CHANGE/hosts_info.before) <(grep '/etc/hosts checksum' /root/$CHANGE/hosts_info.after) > /dev/null && echo "No" || echo "Yes")
        resolv_conf_changed=$(diff <(grep '/etc/resolv.conf checksum' /root/$CHANGE/resolv_info.before) <(grep '/etc/resolv.conf checksum' /root/$CHANGE/resolv_info.after) > /dev/null && echo "No" || echo "Yes")

        echo "(Hostname changed?): $hostname_changed"
        echo "(Hosts file changed?): $hosts_changed"
        echo "(Resolv.conf change?): $resolv_conf_changed"
    } | tee -a "$LOG_FILE"
}

QC() {
    export PYTHONWARNINGS="ignore"
    local test_repos_result="PASSED"
    local disk_space_check_result="PASSED"

    mkdir -p "/root/$CHANGE"

check_kernel_updates() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        echo "UNABLE TO IDENTIFY THE DISTRIBUTION IN USE"
        return 1
    fi

    case $ID in
        ubuntu|debian|linuxmint)
            sudo apt update > /dev/null 2>&1
            apt list --upgradable 2>&1 | grep 'linux-image'
            ;;
        centos|rhel|amzn)
            yum list kernel --showduplicates | tail -5
            ;;
        *)
            echo "DISTRIBUTION $ID NOT SUPPORTED BY THIS SCRIPT."
            return 1
            ;;
    esac
}

    echo
    echo "--------------------------------"
    echo "TESTING REPOSITORY FUNCTIONALITY"
    echo "--------------------------------"
    echo
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release

        local distro=$ID
        local version=$VERSION_ID
    else
        echo "UNABLE TO DETERMINE DISTRIBUTION."
        test_repos_result="FAILED"
        return 1
    fi

    local clean_cmd=""

    case "$distro" in
        "rhel"|"centos")
            local major_version="${version%%.*}"
            if [[ "$major_version" -ge 8 ]]; then
                clean_cmd="dnf makecache"
            else
                clean_cmd="yum makecache"
            fi
            ;;
        "amzn")
            clean_cmd="yum makecache"
            ;;
        "ubuntu"|"debian")
            clean_cmd="apt-get update"
            ;;
        *)
            echo "!!!! UNSUPPORTED DISTRIBUTION !!!! $distro"
            test_repos_result="FAILED"
            ;;
    esac

    if [ -n "$clean_cmd" ]; then
        if ! $clean_cmd; then
            echo "QC FAILED: ISSUE MAKING CACHE. POSSIBLY DUE TO PERMISSION ISSUES, CORRUPTED CACHE FILES, OR PACKAGE MANAGER CONFIGURATION ERRORS"
            test_repos_result="FAILED"
        fi
    fi

    echo
    if [ "$test_repos_result" = "FAILED" ]; then
        return 1
    else
        echo
        echo "QC REPOSITORY FUNCTIONALITY TEST PASSED."
        echo
    fi

    echo "------------------------------------------"
    echo "DOING SOME HOUSE CLEANING FOR $distro"
    echo "------------------------------------------"
    echo

    case "$distro" in
        "rhel"|"centos")
            local clean_cmd="yum clean all"
            ;;
        "amzn")
            local clean_cmd="yum clean all"
            ;;
        "ubuntu"|"debian")
            local clean_cmd="apt-get clean"
            ;;
        *)
            echo "!!!! UNSUPPORTED DISTRIBUTION !!!! $distro"
            test_repos_result="FAILED"
            return 1
            ;;
    esac

    echo "Executing: $clean_cmd"
    if ! sudo bash -c "$clean_cmd"; then
        echo "QC FAILED: ISSUES CLEANING CACHE."
        test_repos_result="FAILED"
        return 1
    fi

    if [[ "$distro" == "amzn" || "$clean_cmd" == *"yum"* ]]; then
        echo "REMOVING /var/cache/yum/*"
        sudo rm -rf /var/cache/yum/*
    fi

    echo
    echo "-------------------"
    echo "CHECKING DISK SPACE"
    echo "-------------------"
    echo
    local var_space=$(df -BG /var | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ "$var_space" -lt 3 ]]; then
        echo "QC DISK SPACE CHECK FAILED: LESS THAN 3GB AVAILABLE IN /var"
        test_repos_result="FAILED"
        echo
        echo "PLEASE REVIEW DISK SPACE"
        df -BG /var
        sleep 2
        return 1
    else
        echo
        echo -e "SUFFICIENT DISK SPACE IN /var.\nPROCEEDING WITH THE SCRIPT."
        df -BG /var
        sleep 2
    fi

    echo
    echo "QC PASSED FOR DISK CHECK"

    echo
    echo "--------------------"
    echo "GENERATING QC REPORT"
    echo "--------------------"
    echo
    sleep 5

{
        echo "===== QC report for $(hostname -s) ====="
        echo "(Current date): $(date)"
        echo "(Server running since): $(uptime)"
        echo "(Current running kernel version): $(uname -r)"
        echo "(Available Kernel Updates):"
        echo "$(check_kernel_updates)"
        echo "(Crowdstrike Version): $(/opt/CrowdStrike/falconctl -g --version 2>/dev/null || echo "CROWDSTRIKE BINARIES NOT FOUND!!!")"
        echo "(Crowdstrike Running?): $(/opt/CrowdStrike/falconctl -g --rfm-state 2>/dev/null || echo "CROWDSTRIKE NOT FOUND RUNNING ON THIS SYSTEM!!!")"
        echo "(Available Kernel Updates Supported By Crowdstrike): $(/opt/CrowdStrike/falconctl -g --version &>/dev/null && echo "$(check_kernel_updates | awk '{print $2}' | while read kernel; do /opt/CrowdStrike/falcon-kernel-check -k "$kernel" 2>&1; done | grep -v "not supported" | sed 's/ matches://g' | while read line; do echo "$line" ; done | grep -vE '\.x86_64')" || echo "NOT PROCESSED, CHECK CROWDSTRIKE INSTALLATION!!!")"
        echo "(Test Repositories Result): $test_repos_result"
        echo "(Disk Space Check Result): $disk_space_check_result"
        echo "========================================"
    } | tee /root/$CHANGE/qc_report.txt

if [ ! -z "$Kernel" ]; then  # Ensure this uses the correct case, matching how it's set with the -k option.
        echo "Kernel version specified: $Kernel. Generating patchme.sh..."

        if [[ "$distro" == "rhel" || "$distro" == "centos" || "$distro" == "amzn" ]]; then
            local package_manager="yum"
            if [[ "$distro" == "rhel" || "$distro" == "centos" ]] && [[ "$version" =~ ^8 ]]; then
                package_manager="dnf"
            fi

            cat <<EOF > /root/$CHANGE/patchme.sh
#!/bin/bash
newkernel="$Kernel"
$package_manager install kernel-$Kernel -y
reboot
EOF
        elif [[ "$distro" == "ubuntu" || "$distro" == "debian" ]]; then
            cat <<EOF > /root/$CHANGE/patchme.sh
#!/bin/bash
newkernel="$Kernel"
apt-get update
apt-get install $Kernel -y
reboot
EOF
        else
            echo "DISTRIBUTION NOT SUPPORTED FOR KERNEL PATCHING"
            return 1
        fi

        chmod +x /root/$CHANGE/patchme.sh
        echo "patchme.sh SCRIPT SUCCESSFULLY GENERATED."
    else
        echo
        echo "QC REPORT COMPLETE"
        echo
    fi
}

pre_reboot_operations() {
    found_marker=$(find /root/$CHANGE -name "script_reboot_marker" -print -quit)

    if [ -z "$found_marker" ]; then
    echo "Performing pre-reboot operations..."
    
    temp_file="/root/$CHANGE/script_reboot_marker"
    
    touch $temp_file

    echo "$CHANGE" > "$temp_file"

    if [ -n "$CHANGE" ]; then
        echo "$CHANGE" > $temp_file
    else
        echo "Change variable is not set"
    fi

    [ -d "/root/$CHANGE" ] || mkdir -p "/root/$CHANGE"

    QC
    instance_details
    /opt/CrowdStrike/falconctl -g --rfm-state | grep -q 'rfm-state=false' && echo "Is Crowdstrike running: Yes" || echo "Is Crowdstrike running: No"
    echo "Crowdstrike: $(/opt/CrowdStrike/falconctl -g --version)"
    echo "Falcon Kernel Check: $(/opt/CrowdStrike/falcon-kernel-check)"
    check_redhat_version
    before_markers
    falcon_check

    echo "Rebooting now..."
    sudo reboot
else
    post_reboot_operations
fi
}

post_reboot_operations() {
    echo "Performing post-reboot operations..."
    after_markers
    rhel_post_op
    maintenance_report
    rm -f "$found_marker"
}

interactive_mode() {
    echo "Step 1: Quality Control Check (QC)"
    QC
    read -p "Proceed to the next step? (y/n): " choice
    [[ $choice != "y" ]] && return

    echo "Step 2: Gathering Instance Details"
    instance_details
    read -p "Proceed to the next step? (y/n): " choice
    [[ $choice != "y" ]] && return

    echo "Step 3: Checking if Crowdstrike is running"
    /opt/CrowdStrike/falconctl -g --rfm-state | grep -q 'rfm-state=false' && echo "Is Crowdstrike running: Yes" || echo "Is Crowdstrike running: No"
    read -p "Proceed to the next step? (y/n): " choice
    [[ $choice != "y" ]] && return

    echo "Step 4: Getting Crowdstrike Version"
    echo "Crowdstrike: $(/opt/CrowdStrike/falconctl -g --version)"
    read -p "Proceed to the next step? (y/n): " choice
    [[ $choice != "y" ]] && return

    echo "Step 5: Falcon Kernel Check"
    echo "Falcon Kernel Check: $(/opt/CrowdStrike/falcon-kernel-check)"
    read -p "Proceed to the next step? (y/n): " choice
    [[ $choice != "y" ]] && return

    echo "Step 6: Red Hat Version Check"
    check_redhat_version
    read -p "Proceed to the next step? (y/n): " choice
    [[ $choice != "y" ]] && return

    echo "Step 7: Setting Before Markers"
    before_markers
    read -p "Proceed to the next step? (y/n): " choice
    [[ $choice != "y" ]] && return

    echo "Step 9: Package Updates"
    echo "Do you want to update the system?"
    echo "1. Update without kernel updates"
    echo "2. Update all packages (including kernel)"
    read -p "Enter your choice (1 or 2): " update_choice

    case $update_choice in
        1)
            echo "Updating without kernel updates..."
            sudo yum update --exclude=kernel* -y
            ;;
        2)
            echo "Updating all packages, including kernel..."
            sudo yum update -y
            ;;
        *)
            echo "Invalid choice. Exiting."
            return 1
            ;;
    esac

    echo "Step 10: System Reboot"
    read -p "Do you want to reboot the system now? (y/n): " reboot_choice
    if [[ $reboot_choice == "y" ]]; then
        echo "Rebooting the system..."
        sudo reboot
    else
        echo "System reboot skipped."
    fi
}

auto_mode () {
    pre_reboot_operations
}

while getopts "c:qiaphvk:" opt; do
    case $opt in
        c) CHANGE="$OPTARG"
           mkdir -p /root/"$CHANGE"
           ;;
        k) Kernel="$OPTARG"
           ;;
        q) QC
           exit 0
           ;;
        i) interactive_mode
           exit 0
           ;;
        a) auto_mode
           exit 0
           ;;
        p) if [ -f "/root/$CHANGE/script_reboot_marker" ]; then
               post_reboot_operations
           else
               echo "No reboot marker found. Exiting."
           fi
           exit 0
           ;;
        v) echo "Version: 1, Author: Mike Quintero"
           exit 0
           ;;
        h) echo "Usage: $0 [-c Change Ticket] [-q QC Only] [-i Interactive Mode] [-a Automatic Mode] [-p Post Reboot Operations] [-h Help] [-v Version] [-k Kernel Version]"
           exit 0
           ;;
        *) echo "Invalid option: -$OPTARG" >&2
           exit 1
           ;;
    esac
done


if [ -z "$CHANGE" ]; then
    echo "Error: CHANGE variable not set. Use the -c flag to set it."
    exit 1
fi

QC
