# AWS Post Patch Check v1.9 AUTHOR: michael.quintero@rackspace.com
# PURPOSE: To grab the following pieces of information from an AWS EC2 instance; Uptime, Last Five Reboots, Current Kernel, Last Patches in Seven days, & Crowdstrike Status.
# FEATURES: Checks uptime, kernel version, User provides an input file with the instance ids to be used.
# Usage: python3 doubletake.py
# Note: User is expected to have already set credentials. Requirements are boto3, time, datetime, clienterror

import os
import boto3
import time
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

verbose = os.getenv('VERBOSE', '0') == '1'

def get_recent_updates_logs(distro_type):
    end_date = datetime.now()
    start_date = end_date - timedelta(days=7)
    date_format = "%Y-%m-%d" if distro_type == '1' else "%Y-%m-%d"  # Adjust if format differs

    if distro_type == '1':  # If the user selected 1 for Red Hat, AWS, Oracle
        command = f"awk '$0 ~ /{start_date.strftime(date_format)}/, $0 ~ /{end_date.strftime(date_format)}/' /var/log/yum.log"
    else:  # If the user didn't select 1, then assume Ubuntu/Debian
        command = f"awk '$0 ~ /{start_date.strftime(date_format)}/, $0 ~ /{end_date.strftime(date_format)}/' /var/log/apt/history.log"

    return command

def get_instance_info(instance_ids, region, distro_type):
    ssm_client = boto3.client('ssm', region_name=region)
    commands = {
        'Uptime': 'uptime',
        'Last_Five_Reboots': 'last reboot | head -5',
        'Kernel_Version': 'uname -r',
        'Updates_In_Last_7_Days': get_recent_updates_logs(distro_type),
        'Crowdstrike_Version': 'echo "(Current Crowdstrike Version): $(/opt/CrowdStrike/falconctl -g --version 2>/dev/null)"',
        'Crowdstrike_Status': '/opt/CrowdStrike/falconctl -g --rfm-state 2>/dev/null | grep -q "rfm-state=false" && echo "(Is Crowdstrike running): Yes" || echo "(Is Crowdstrike running): No"'
    }

    instance_info = {}

    for instance_id in instance_ids:
        instance_info[instance_id] = {}
        try:
            for info, command in commands.items():
                response = ssm_client.send_command(
                    InstanceIds=[instance_id],
                    DocumentName="AWS-RunShellScript",
                    Parameters={'commands': [command]}
                )
                command_id = response['Command']['CommandId']
                output = None

                for _ in range(10):
                    try:
                        output = ssm_client.get_command_invocation(
                            CommandId=command_id,
                            InstanceId=instance_id
                        )
                        if output['Status'] not in ['Pending', 'InProgress']:
                            break
                    except ssm_client.exceptions.InvocationDoesNotExist:
                        # Use 'VERBOSE=1' to set the flag for the script, preceeding the script commmand...to see this print statement
                        # No biggie if not, but had some ideas for the future especially when debugging with print statements 
                        if verbose:
                            print("Waiting for command invocation to be available...")
                        time.sleep(3)

                if output and output['Status'] == 'Success':
                    content = output['StandardOutputContent'].strip()
                    if content == "":
                        instance_info[instance_id][info] = "No data returned."
                    else:
                        instance_info[instance_id][info] = content
                else:
                    error_details = output.get('StandardErrorContent', 'No error details provided.') if output else 'No output retrieved.'
                    instance_info[instance_id][info] = f"Command execution failed: {error_details}"

        except ClientError as e:
            if e.response['Error']['Code'] == 'InvalidInstanceId':
                print(f"Instance {instance_id} is not available via SSM or not in a valid state.")
            else:
                print(f"An unexpected error occurred: {e}")

    return instance_info

def main():
    file_path = input("Enter the path to the file with instance IDs: ")
    with open(file_path, 'r') as file:
        instance_ids = [line.strip() for line in file if line.strip()]

    print("Select the type of Linux distribution:")
    print("1. Red Hat, AWS, Oracle")
    print("2. Ubuntu/Debian")
    distro_type = input("Enter option 1 or 2: ")

    print("Select the type of AWS account:")
    print("1. Commercial")
    print("2. Government")
    account_type = input("Enter option 1 or 2: ")
    
    if account_type == '1':
        regions = ['us-east-1', 'us-east-2', 'us-west-1', 'us-west-2']
    else:
        regions = ['us-gov-west-1', 'us-gov-east-1']
    
    print("Available regions based on account type:")
    for i, region in enumerate(regions, 1):
        print(f"{i}. {region}")
    region_index = int(input("Select the region number: ")) - 1
    region = regions[region_index]

    info = get_instance_info(instance_ids, region, distro_type)
    for instance_id, details in info.items():
        print("\n")
        print(f"Report for Instance ID: {instance_id}")
        for key, value in details.items():
            print(f"  {key}: {value}")
        print("\n")

if __name__ == "__main__":
    main()
