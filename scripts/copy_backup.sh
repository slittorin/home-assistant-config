#!/bin/bash
#
# Purpose:
# Copy backup to other server.
#
# Usage:
# ./copy_backup.sh SERVER REMOTEDIR
#
# Example: ./copy_backup.sh pi@192.168.2.30 /srv/ha/backup
#
# SERVER    - Mandatory. Is the remote server in format: user@NAME/IP.
#             Remember that the server must be able to run commands without password (such as key based login).
# REMOTEDIR - Mandatory. Remote directory.
#
# Since shell commands by default do not have /backup mounted, we do this manually: https://community.home-assistant.io/t/tips-for-shell-command-and-auto-deleting-old-snapshots/207688
# We could have utilized this approach, but chose manual mount: https://community.home-assistant.io/t/shell-command-backup-not-found/273055/8

# Load environment variables (mainly secrets).
if [ -f "/config/.env" ]; then
    export $(cat "/config/.env" | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

# Variables:
config_dir="/config"
base_dir="/config/scripts"
log_dir="/config/logs"
logfile="${log_dir}/copy_backup.log"
logfile_tmp="${log_dir}/copy_backup.tmp"
rsa_file="/config/.ssh/id_rsa"
known_hosts_file="/config/.ssh/known_hosts"

touch ${logfile}

# Check server.
if [ -z "$1" ]; then
    echo "ERROR. Server must be given."
    echo "$(date +%Y%m%d_%H%M%S): ERROR. Server must be given." >> ${logfile}
    exit 1
else
    SERVER="$1"
fi

# Remote dir.
if [ -z "$1" ]; then
    echo "ERROR. Remote directory must be given."
    echo "$(date +%Y%m%d_%H%M%S): ERROR. Remote directory must be given." >> ${logfile}
    exit 1
else
    REMOTEDIR="$2"
fi

echo "" >> ${logfile}
echo "$(date +%Y%m%d_%H%M%S): Starting copy of backup." >> ${logfile}

# We can run this script in differect context, either in shell add-on, or as shell command.
# Therefore we need to check this before we start to copy.
backup_dir="/backup"
if [ ! -d "${backup_dir}" ]; then
    backup_dir="/mnt/data/supervisor/backup"
    echo "$(date +%Y%m%d_%H%M%S): Script triggered as shell_command, mounting ${backup_dir}" >> ${logfile}
    umount /mnt/data 2> /dev/null
    mkdir -p /mnt/data 2>> ${logfile}
    mount /dev/sda8 /mnt/data 2>> ${logfile}
    RESULT_CODE=$?
    if [ ${RESULT_CODE} -ne 0 ]; then
        echo "ERROR. Mount error. Exit code: ${RESULT_CODE}"
        echo "$(date +%Y%m%d_%H%M%S): ERROR. Mount error. Exit code: ${RESULT_CODE}" >> ${logfile}
        exit 1
    fi 
else
    echo "$(date +%Y%m%d_%H%M%S): Script triggered through shell add-on." >> ${logfile}
fi

echo "$(date +%Y%m%d_%H%M%S): Local directory: ${backup_dir}" >> ${logfile}
echo "$(date +%Y%m%d_%H%M%S): Remote directory: ${SERVER}:${REMOTEDIR}" >> ${logfile}

# Since rsync does not exists in HA addon for shell, we need to make exact copy manually.
# Check if all files in remote directory exists locally, if not, they are removed remote.
# We check here if the file size is equal, but do not check hash of file.
FILES_REMOVED=0
FILES=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "ls -1 ${REMOTEDIR} && ls -1 *.tar 2> /dev/null" 2>> ${logfile}`
if [ ! -z "${FILES}" ]; then
    for FILE in ${FILES}; do
        FILE=`basename ${FILE}`
        echo "${FILE}" >> ${logfile}
        if [ ! -z ${FILE} ]; then
            if [ ! -f "${backup_dir}/${FILE}" ]; then
                RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "rm ${REMOTEDIR}/${FILE}" 2>> ${logfile}`
                RESULT_CODE=$?
                if [ ${RESULT_CODE} -ne 0 ]; then
                    echo "$(date +%Y%m%d_%H%M%S): For file ${FILE} does not exists locally, and is removed in remote directory." >> ${logfile}
                    echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}"
                    echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error when removing remote file. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
                    exit 1
                else
                    FILES_REMOVED=$((${FILES_REMOVED}+1))
                    echo "$(date +%Y%m%d_%H%M%S): File ${FILE} does not exists locally, and is removed in remote directory." >> ${logfile}
                fi
            else
                SIZE_REMOTE=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "stat -c %s ${REMOTEDIR}/${FILE}" 2>> ${logfile}`
                RESULT_CODE=$?
                if [ ${RESULT_CODE} -ne 0 ]; then
                    echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${SIZE_REMOTE}"
                    echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error when getting hash for file. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
                    exit 1
                fi
                
                SIZE=`stat -c %s ${backup_dir}/${FILE} 2>> ${logfile}`
                if [ "${SIZE_REMOTE}" == "${SIZE}" ]; then
                    echo "$(date +%Y%m%d_%H%M%S): Remote file ${FILE} exists locally and are equal in size, not required to be transfered." >> ${logfile}
                else
                    RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "rm ${REMOTEDIR}//${FILE}" 2>> ${logfile}`
                    RESULT_CODE=$?
                    if [ ${RESULT_CODE} -ne 0 ]; then
                        echo "$(date +%Y%m%d_%H%M%S): For remote file ${FILE} exists locally but files are not equal in size, therefore removed in remote directory." >> ${logfile}
                        echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}"
                        echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error when removing remote file. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
                        exit 1
                    else
                        FILES_REMOVED=$((${FILES_REMOVED}+1))
                        echo "$(date +%Y%m%d_%H%M%S): Remote file ${FILE} exists locally but files are not equal in size, therefore removed in remote directory." >> ${logfile}
                    fi
                fi
            fi
        fi
    done
else
    echo "$(date +%Y%m%d_%H%M%S): No files in remote directory." >> ${logfile}
fi

# Since rsync does not exists in HA addon for shell, we need to make exact copy manually.
# Check if file exists remotely, if not, transfer.
cd ${backup_dir}
FILES_COPIED=0
FILES=`ls -1 *.tar 2> /dev/null`
if [ ! -z "${FILES}" ]; then
    for FILE in ${FILES}; do
        if [ ! -z ${FILE} ]; then
            CHECK=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "ls -1 ${REMOTEDIR}/${FILE} 2> /dev/null" 2>> ${logfile}`
            if [ -z ${CHECK} ]; then
                echo "$(date +%Y%m%d_%H%M%S): File ${FILE} does not exists remotely, and is being transfered." >> ${logfile}
                RESULT=`scp -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} -p ${backup_dir}/${FILE} ${SERVER}:${REMOTEDIR} 2>> ${logfile}`
                RESULT_CODE=$?
                if [ ${RESULT_CODE} -ne 0 ] 
                then
                    echo "ERROR. SSH command error when transferring file. Exit code: ${RESULT_CODE}: ${RESULT}"
                    echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
                    exit 1
                else
                    FILES_COPIED=$((${FILES_COPIED}+1))
                fi
            fi
        fi
    done
else
    echo "$(date +%Y%m%d_%H%M%S): No files in local directory." >> ${logfile}
fi
# Log, and limit logfile to 1000 rows.
RESULT="$(date +%Y%m%d_%H%M%S): No error. Removed files: ${FILES_REMOVED}. Copied files: ${FILES_COPIED}."
echo "${RESULT}" >> ${logfile}
tail -n1000 ${logfile} > ${logfile_tmp}
rm ${logfile}
mv ${logfile_tmp} ${logfile}

# Show output
echo "${RESULT}"

exit 0