##################################################################################################################################################
# Script Name: cve_checker.sh
# Author: michael.quintero@rackspace.com
# Description: Used to search for installed CVEs related to patching for our patching team (in relation to remediation)
##################################################################################################################################################

#!/bin/bash

CVE_LIST=("CVE-2022-42896" "CVE-2023-4921" "CVE-2023-38409" "CVE-2023-45871" "CVE-2024-1086" "CVE-2024-26602" "CVE-2023-42753")
found_count=0
total_cves=${#CVE_LIST[@]}

hostname
date

for CVE in "${CVE_LIST[@]}"; do
    echo "Checking installed packages for $CVE:"
    found=$(rpm -qa --changelog | grep -c $CVE)
    if [ "$found" -ne "0" ]; then
        echo "Patch for $CVE found in installed packages."
        ((found_count++))
    else
        echo "No patch for $CVE found in installed packages."
    fi
    echo ""
done

echo "Search completed for $total_cves CVEs, with $found_count CVEs patched on the system."

if [ $found_count -eq $total_cves ]; then
    state="all"
elif [ $found_count -gt 0 ]; then
    state="some"
else
    state="none"
fi

echo "Result: $state of the CVEs were patched on the system."
rm -- "$0" 
