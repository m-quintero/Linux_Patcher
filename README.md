## linux_patcher - Automated Linux Patching Tool

### Description
`linux_patcher` is a versatile Bash script designed to automate the patching process for Linux servers. It simplifies routine patching tasks, offering options for interactive, manual, or quick Quality Control (QC) checks. The script creates detailed log files in the specified `$CHANGE` directory. It detects if a patch and reboot have already been executed and resumes the remaining steps post-reboot. Currently, it supports RHEL versions 7, 8, and 9, with plans to integrate Ubuntu patching in future releases.

### Author
Michael Quintero  
Email: michael.quintero@rackspace.com

### Version
2.0

### Features
- **Versatility:** Interactive, manual, or QC check modes.
- **Log Generation:** Creates logs in the specified `$CHANGE` directory.
- **State Awareness:** Detects post-reboot state to continue patching.
- **Linux Distro Support:** Compatible with RHEL 7, 8, 9, Amazon Linux, Ubuntu (Coming Soon).
- **CrowdStrike Integration:** Checks new kernel compatibility with Falcon Sensor and will update accordingly.
- **Qualys Pre-Integration:** Generates the patchme.sh used for setting kernels. 

### Usage
The script is invoked with various flags for different operations:
```
./linux_patcher [-c Change Ticket] [-q QC Only] [-i Interactive Mode] [-a Automatic Mode] [-k Kernel] [-p Post Reboot Operations] [-h Help] [-v Version]
```

#### Options
- `-c <Change Ticket>`: Specify the change ticket directory for logs.
- `-q`: Perform a Quality Control check only.
- `-i`: Run in interactive mode.
- `-a`: Run in automatic mode.
- `-p`: Execute post-reboot operations.
- `-k`: Set kernel to be used.
- `-v`: Display version and author information.
- `-h`: Display usage information.

### Functions
- `check_redhat_version`: Determines the applicable path based on RHEL version.
- `falcon_check`: Checks kernel version compatibility with Falcon Sensor to determine upgrade path.
- `instance_details`: Gathers general RHEL instance details and outputs to STDOUT.
- `before_markers` & `after_markers`: Records system state before and after reboots.
- `maintenance_report`: Creates a detailed maintenance report after the reboot. A log file is in the $CHANGE directory.
- `QC`: Performs initial quality control checks for disk space & repo operational check.
- `pre_reboot_operations` & `post_reboot_operations`: Handles operations before and after system reboot.
- `interactive_mode`: Guides the user through each patching step interactively.
- `auto_mode`: Runs the patching process automatically without user intervention.

### Installation
1. Download the `linux_patcher` script.
2. Ensure the script is executable: `chmod +x linux_patcher` or run with the bash command, bash linux_patcher <flags> (SEE NEXT LINE)
3. Run the script with appropriate flags as described in the Usage section.

### Requirements
- Designed for RHEL versions 7, 8, and 9.
- Requires root or sudo privileges for full functionality.
- Internet access for package updates.

### Note
This script is currently in development. Important features such as Ubuntu patching are planned for future releases. Use with caution and always test in a non-production environment first.

### Support
For any queries or issues, contact michael.quintero@rackspace.com.

---
