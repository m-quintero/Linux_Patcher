#############################################################################################################################
# Script Name: cve_checker.sh
# Version: 1.1
# Author: michael.quintero@rackspace.com
# Description: Searches for installed CVEs & checks if those CVEs are available for install. Only supports RHEL at the moment
#############################################################################################################################

#!/bin/bash

check_cve_update() {
    local CVE=$1
    echo "Checking for available update for CVE: $CVE"
    found=$(yum updateinfo list cves | grep -c $CVE)
    if [ "$found" -ne "0" ]; then
        echo "Update available for $CVE."
        ((found_update_count++))
    else
        echo "No update found for $CVE."
    fi
    echo ""
}

check_cve_installed() {
    local CVE=$1
    echo "Checking if CVE is installed: $CVE"
    found=$(rpm -qa --changelog | grep -c $CVE)
    if [ "$found" -ne "0" ]; then
        echo "Patch for $CVE found in installed packages."
        ((found_installed_count++))
    else
        echo "No patch for $CVE found in installed packages."
    fi
    echo ""
}

read -p "Enter CVEs separated by space: " -a CVE_LIST

found_update_count=0
found_installed_count=0
total_cves=${#CVE_LIST[@]}

hostname
date

for CVE in "${CVE_LIST[@]}"; do
    check_cve_update $CVE
    check_cve_installed $CVE
done

echo "Search completed for $total_cves CVEs."
echo "$found_update_count CVEs have available updates."
echo "$found_installed_count CVEs are patched on the system."

if [ $found_update_count -eq $total_cves ]; then
    update_state="all"
elif [ $found_update_count -gt 0 ]; then
    update_state="some"
else
    update_state="none"
fi

if [ $found_installed_count -eq $total_cves ]; then
    installed_state="all"
elif [ $found_installed_count -gt 0 ]; then
    installed_state="some"
else
    installed_state="none"
fi

echo "Result: $update_state of the CVEs have available updates."
echo "Result: $installed_state of the CVEs are patched on the system."

# Self destruct!!!!!!!!!!!
# rm -- "$0"
