
# Dirsync
`dirsync` is a lightweight Bash script designed to synchronize a single local directory with a remote directory over SSH. It provides a simple, reliable way to push local changes to a remote server, functioning like a remote auto-save for your files.

## Features
- Syncs a single local directory to a remote directory.
- Supports one-time or continuous synchronization.
- Uses SSH for secure file transfer.
- Easy to configure with minimal setup.

## Prerequisites
- Bash (available on Linux, macOS, or WSL on Windows).
- `rsync` installed on both local and remote systems.
- SSH access to the remote server with a valid SSH configuration.
- Read/write permissions for the local and remote directories.

## Installation
1. Clone or download this repository:
   ```bash
   git clone https://github.com/bobby-valenzuela/DirSync.git
   ```
2. Navigate to the project directory:
   ```bash
   cd DirSync
   ```
3. Make the script executable:
   ```bash
   chmod +x dirsync.sh
   ```

<br />  


## Configuration
Edit the `dirsync.sh` script to set the following configuration variables:

```bash
# Path to the local root directory (must end with a slash)
LOCAL_ROOT='/home/bobby/working/'

# Path to the remote root directory (must end with a slash)
REMOTE_ROOT='/home/ubuntu/final/'

# Time between sync checks in continuous mode (seconds)
NAP_TIME=3

# Path to SSH configuration file
SSH_CONF=~/.ssh/config
```

Ensure your SSH configuration file (`~/.ssh/config`) includes an entry for the remote host. For example:

```text
Host myremotevm-001
    HostName 192.168.1.100
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
```

<br />  

## Usage
Run the script from the command line, specifying the local directory name and the remote host alias defined in your SSH config.

<br />  

### One-Time Sync
To sync the local directory to the remote directory once:

```bash
./dirsync.sh mylocaldir myremotevm-001
```

This syncs `/home/bobby/working/mylocaldir` to `/home/ubuntu/final/mylocaldir` on `myremotevm-001`.

<br />  

### Continuous Sync
To enable continuous synchronization (checks for changes every `NAP_TIME` seconds):

```bash
./dirsync.sh mylocaldir myremotevm-001 ongoing
```

<br />

The script will monitor the local directory and push updates to the remote directory as changes occur (as detected by changes in file size).  
You can also use a single dot to refer to set the current dir as the dir to be synced:
```bash
./dirsync.sh . myremotevm-001 # If we're in the 'mylocaldir' dir then this is the same as: ./dirsync.sh mylocaldir myremotevm-001 ongoing
```

<br />  

## How It Works
- The script uses `rsync` to efficiently transfer only changed files from the local directory (`LOCAL_ROOT/<dirname>`) to the remote directory (`REMOTE_ROOT/<dirname>`).
- The remote host is accessed via SSH using the configuration in `SSH_CONF`.
- In continuous mode, the script runs in a loop, checking for changes every `NAP_TIME` seconds.

<br />  

## Troubleshooting
- **Permission denied**: Ensure you have read/write access to both local and remote directories and that your SSH key is correctly configured.
- **Host not found**: Verify the remote host alias in your SSH config file.
- **Rsync errors**: Confirm that `rsync` is installed on both systems.

<br />  

## Contributing
Contributions are welcome! Please submit issues or pull requests to the repository.
