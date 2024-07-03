## linux_patcher - Automated Linux Patching Tool

### Description
`linux_patcher` is a versatile Bash script designed to automate the patching process for Linux servers. It simplifies routine patching tasks, offering options for quick Quality Control (QC) checks, automatic patching, creating a patchme file, or installing a specific kernel.

### Version
2.5.8-b

### Features
- **Versatility:** Automatic patching or QC check modes.
- **QC Report Generation:** Creates a QC report in the specified `$CHANGE` directory.
- **Patch Log Generation:** Creates maintenance logs in the specified `$CHANGE` directory.
- **State Awareness:** Detects post-reboot state to continue patching.
- **Linux Distro Support:** Compatible with RHEL 7, 8, 9, Amazon Linux, Oracle Cloud Linux, and Debian/Ubuntu.
- **CrowdStrike Integration:** Checks new kernel compatibility with Falcon Sensor and will update where necessary.
- **Qualys Pre-Integration:** Generates the patchme.sh used for setting kernels. 

### Usage
The script is invoked with various flags for different operations:
```
./linux_patcher [-c Change Ticket] [-q QC Only] [-r Reboot] [-a Automatic Mode] [-k Kernel] [-p Post Reboot Operations] [-h Help] [-v Version]
```

#### Options
- `-c <Change Ticket>`: Specify the change ticket directory for logs.
- `-q`: Perform a Quality Control (QC) check only.
- `-r`: Reboot. Must always be specified before the -a flag to reboot after a patch or kernel operation has completed.
- `-a`: Automatic mode, to perform a minimal update (security) unless the next kernel supports Crowdstrike, then will update kernel and security packages.
- `-p`: Execute post-reboot operations. Only to be run after an automatic session was completed (see -a).
- `-k`: Set kernel to be used to either generate a patchme or for installation of kernel.
- `-v`: Display version and author information.
- `-h`: Display usage information.
- `-s`: Invoke silent mode to redirect all QC standard output and error to /dev/null when enabled.

### Examples of Usage


**Generate a QC report only**
```
./linux_patcher -c CHG0123456 -q (runs qc by default as a failsafe if no switch after the -c switch is specified)
``` 

**Create the patchme config for Qualys only**
```
./linux_patcher -c CHG0123456 -k $KERNEL
```

**Install a specific kernel and NOT reboot**
```
./linux_patcher -c CHG0123456 -k $KERNEL -a
``` 

**Install a specific kernel AND reboot**
```
./linux_patcher -c CHG0123456 -r -k $KERNEL -a
```
 
**Run standard patch job (security) for an instance and NOT reboot then create the maintenance report**  
```
./linux_patcher -c CHG0123456 -a 
```

```
./linux_patcher -c CHG0123456 -p
```

**Run standard patch job (security) for an instance AND reboot**
```
./linux_patcher -c CHG0123456 -r -a
```

**Once the system is back up, you can run the following**
```
./linux_patcher -c CHG0123456 -a or -p
```

### Installation
1. Download the `linux_patcher` script.
2. Ensure the script is executable: `chmod +x linux_patcher` or run with the bash command, bash linux_patcher <flags> (SEE NEXT LINE)
3. Run the script with appropriate flags as described in the Usage section.

### Requirements
- Bash shell.
- Requires root or sudo privileges for full functionality.
- Internet access for package updates.

### Note
This script is currently in development. Use with caution and always test in a non-production environment first.


---

## DoubleTake - Automated info retrieval for AWS EC2 Instances with working SSM configs

`DoubleTake` is a python script which queries AWS EC2 instances via the AWS SSM to provide report info. Primarlily for post patching use, but can be anytime.

### Version
1.9

### Features
- **System Uptime**: Retrieves the uptime of the system.
- **Kernel Version**: Displays the current kernel version running.
- **Updates in the Last 7 Days**: Lists any system updates that have been applied within the last week.
- **CrowdStrike Status**: Checks whether the CrowdStrike Falcon sensor is running & reports its status.
- **CrowdStrike Version**: Fetches the current version of the installed CrowdStrike Falcon sensor.
- **Last Five Reboots**: Shows the last five reboots of the system to help identify reboot patterns or issues.


### Usage
To use `DoubleTake`, follow these steps:

1. Ensure you have the necessary AWS credentials configured that allow access to AWS Systems Manager.
2. Create a file for `doubletake.py` to iterate through, which specifies the EC2 instance IDs.
3. Run the script from a terminal:

   ```bash
   python3 doubletake.py
   ```

4. Follow the prompts to select the type of Linux distro, AWS account type, and AWS region.
5. View the output, PROFIT!

### Installation

To set up `DoubleTake` on your local machine, follow these instructions:

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/doubletake.git
   ```

2. Navigate to the `doubletake` directory:

   ```bash
   cd doubletake
   ```

3. Install required Python packages:

   ```bash
   pip install -r requirements.txt
   ```

### Requirements
- Python 3.x
- Boto3
- AWS CLI configured with appropriate permissions
- Access to AWS EC2 and SSM services

Ensure that your AWS credentials are set from Janus!

### Contributing
Contributions to `DoubleTake` are welcome! Please fork the repo & submit a pull request with your enhancements.

### Support
For any queries or issues, contact michael.quintero@rackspace.com or pcm.ops@rackspace.com
