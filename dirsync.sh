#!/usr/bin/env bash

# Author : Bobby Valenzuela
# Created : 1st January 2025 

# Description:
# Synchronize a single local directory with a remote directory over SSH

#############################################################################
# =========== CONFIG ===========
# Enter your path details here:

# Local dir where you want changes to be tracked and have these changes pushed out to our remote machine
LOCAL_ROOT='/home/bobby/local_dirs/'

# Remote directory where changes are pushed out to
REMOTE_ROOT='/home/ubuntu/remote_dirs/'

# 3 seconds per iteration
NAP_TIME=3

# SSH Confile file location (full location)
SSH_CONF=~/.ssh/config

# ======== END CONFIG ============
#############################################################################

# Checks for any arguments passed in
DIR="$1"
HOST="$2"
FULL_LOCAL_PATH=""
FULL_REMOTE_PATH=""


if [[ -z "$DIR" && -z "$HOST" ]];then
    echo "Usage: $0 <dir> <host> [ongoing]"
fi

# If a single dot pased in then we are calling Gitsync from inside a repo in our list, only force this one. 
# This way we can just call `gitsync .` from inside a repo to sync (and optinally pass in a second arg as a commit msg).
if [[ "$DIR" == '.' ]]; then

  PWD_DIR=$(basename $(pwd))
  FULL_LOCAL_PATH="${LOCAL_ROOT}${PWD_DIR}"
  FULL_REMOTE_PATH="${REMOTE_ROOT}${PWD_DIR}"

elif [[  ! -z "$DIR" ]]; then

  # Anything other than a dot must be the dir itself thats being forced
  FULL_LOCAL_PATH="${LOCAL_ROOT}$DIR"
  FULL_REMOTE_PATH="${REMOTE_ROOT}${DIR}"

fi

# Exit if no ssh config file
if [[ ! -e $SSH_CONF ]]; then
  echo "No file found at $SSH_CONF. Exiting!"
  exit
fi


# Require both args
if [[ -z "${DIR}" || -z "${HOST}" ]]; then
    echo "Missing args | 1=$DIR | 2=$HOST"
    exit
fi

# Skip if local dir doesn't exist
[[ ! -d ${FULL_LOCAL_PATH} ]] && echo "Dir doesn't exist (only include dir name)" && exit

ssh_user=$(grep -E -A10 "${HOST}(\b|\r|n)" $SSH_CONF | sed -E '/^$/ q' | awk '/User/ { print $2 }')
ssh_hostname=$(grep -E -A10 "${HOST}(\b|\r|n)" $SSH_CONF | sed -E '/^$/ q' | awk '/HostName/ { print $2 }')
ssh_key=$(grep -E -A10 "${HOST}(\b|\r|n)" $SSH_CONF | sed -E '/^$/ q' | awk '/IdentityFile/ { print $2 }')

# Define Associative arrays to hold file count/dir size info
unset local_dir_sizes
declare -A local_dir_sizes

unset local_dir_files
declare -A local_dir_files

dir_size=0
file_count=0

### Start main loop
while :; do

    # Get current git branch
    current_branch=$(cd ${FULL_LOCAL_PATH} && git branch  | grep '*' | awk '{print $2}' | xargs)
    current_branch_remote=$(ssh ${HOST} -F ${SSH_CONF} -i ${ssh_key} "cd ${FULL_REMOTE_PATH} && git branch 2>/dev/null | grep '*' | awk '{print \$2}' | xargs")

    # Skip if no branch found  or if master (only feature branches sync).
    [[ -z "${current_branch}" || "${current_branch}" == 'master' || "${current_branch}" == 'main' ]]  && continue

   
    # Replace any fwd-slashes with underscores
    local_escaped=$(printf ${FULL_LOCAL_PATH////_})

    # Now that we have all keys for this entry, lets check size changes to see if sync is needed
    current_size=$(du -bs ${FULL_LOCAL_PATH} | awk '{print $1}')
    current_file_count=$(ls -lR ${FULL_LOCAL_PATH} | wc -l)

    echo -e "[+] Processing... | Local Dir: ${FULL_LOCAL_PATH} | Remote Dir: ${FULL_REMOTE_PATH}"

    # If no size set for this local dir or we switched branches
    if [[ ${dir_size} -eq 0 || "${current_branch}" != "${current_branch_remote}" ]]; then
    
        dir_size=${current_size}
        file_count=${current_file_count}

        # Run Sync now
        echo -e "\nInitial Sync or Change of branches. Remote branch (${current_branch_remote}) Local branch (${current_branch}). Updating remote..."

        # Clean any untracked files and discard any unsaved changes - then create branch if needed
        echo "[+] Removing unstaged changes..."
        ssh ${HOST} -F ${SSH_CONF} -i ${ssh_key} "cd ${FULL_REMOTE_PATH} && git checkout -- .  "
        echo "[+] Cleaning files..."
        ssh ${HOST} -F ${SSH_CONF} -i ${ssh_key} "cd ${FULL_REMOTE_PATH} && sudo git clean -df "
        echo "[+] Creating/Checking out branch..."
        ssh ${HOST} -F ${SSH_CONF} -i ${ssh_key} "cd ${FULL_REMOTE_PATH} && git checkout -b ${current_branch}"

        # Checkout branch and clean up any untracked files
        echo "[+] Checking out branch..."
        ssh ${HOST} -F ${SSH_CONF} -i ${ssh_key} "cd ${FULL_REMOTE_PATH} && git checkout ${current_branch} " 
        echo "[+] Cleaning files..."
        ssh ${HOST} -F ${SSH_CONF} -i ${ssh_key} "cd ${FULL_REMOTE_PATH} && sudo git clean -df "
        echo "[+] Fetching remote branch..."
        ssh ${HOST} -F ${SSH_CONF} -i ${ssh_key} "cd ${FULL_REMOTE_PATH} && git fetch origin ${current_branch}" 
        echo "[+] Setting branch tracking..."
        ssh ${HOST} -F ${SSH_CONF} -i ${ssh_key} "cd ${FULL_REMOTE_PATH} && git branch --set-upstream-to=origin/${current_branch} ${current_branch} && git pull" 

        echo "[+] Running rsync..."
        rsync=$(rsync --delete-after --exclude "*.git" --info=progress2 -harvpE -e "ssh -i ${ssh_key}"  ${FULL_LOCAL_PATH}/ ${ssh_user}@${ssh_hostname}:${FULL_REMOTE_PATH}/)

        # Discard any files that are deleted
        echo "[+] Removing deleted files..."
        ssh ${HOST} -F ${SSH_CONF} -i ${ssh_key} "cd ${FULL_REMOTE_PATH} && for file in \$(git status | grep 'deleted:' | awk '{print \$2}' ); do git checkout -- \$file; done"  
        echo "[+] Sync Finished."

    else

      # We have a size saved for this dir - lets compare with current size and num of files
      if [[ ${dir_size} -ne ${current_size} ]]; then

        echo -e "\nSize Changed. Syncing remote..."

        # Update size in dict
        dir_size=${current_size}
        file_count=${current_file_count}
       
        # Perform sync
          rsync=$(rsync --delete-after --exclude "*.git" --info=progress2 -harvpE -e "ssh -i ${ssh_key}"  ${FULL_LOCAL_PATH}/ ${ssh_user}@${ssh_hostname}:${FULL_REMOTE_PATH}/ 2>/dev/null)

      elif [[ ${file_count} -ne ${current_file_count} ]]; then

        aecho -e "\nFile count Changed. Syncing remote..."

        # Update file count in dict
        file_count=${current_file_count}
        dir_size=${current_size}
        
        # Perform sync
          rsync=$(rsync --delete-after --exclude "*.git" --info=progress2 -harvpE -e "ssh -i ${ssh_key}"  ${FULL_LOCAL_PATH}/ ${ssh_user}@${ssh_hostname}:${FULL_REMOTE_PATH}/ 2>/dev/null)


      fi

    fi

    printf "."

  
  # If we've been passed some args - this is a once-off unless theres a third argument saying otherwise
  [[  ! -z "${DIR}" && "$3" != "ongoing" ]] && exit

  sleep ${NAP_TIME}

done
