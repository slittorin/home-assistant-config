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
#
# Updates:
# 20250805: Added so that files with special characters (such as '&') can be managed, this as scp has problem with those.
# 20250808: Changed so that files with special-characters, such as '&' in: Terminal_&_SSH_9.17.0_2025-06-25_13.57_50594240.tar, are better managed.
#           I.e. workaround.
#           Limitations: Do not manage filenames with newlines or similar, and do not check if sanitized file already exists.

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

# Since scp has problem with special-characters, and I could not isolate how to ensure that file-names where properly created on remote server,
# I added code instead to change filenames with special-characters
echo "$(date +%Y%m%d_%H%M%S): Check if filenames contains special-characters, if so replace with '_' instead." >> ${logfile}
cd ${backup_dir} || exit 1
LOCAL_FILES=`ls -1 *.tar 2> /dev/null`
if [ ! -z "${LOCAL_FILES}" ]; then
    for LOCAL_FILE in ${LOCAL_FILES}; do
       SANITIZED_LOCAL_FILE=$(echo "${LOCAL_FILE}" | sed 's/[^A-Za-z0-9._-]/_/g')
        if [ "${LOCAL_FILE}" != "${SANITIZED_LOCAL_FILE}" ]; then
            mv "${LOCAL_FILE}" "${SANITIZED_LOCAL_FILE}"
            echo "  $(date +%Y%m%d_%H%M%S): ${LOCAL_FILE}: Contained special characters and was sanitized." >> ${logfile}
        fi
    done
fi

# Since rsync does not exists in HA addon for shell, we need to make exact copy manually.
# Check if all files in remote directory exists locally, if not, they are removed remote.
# We check here if the file size is equal, but do not check hash of file.
echo "$(date +%Y%m%d_%H%M%S): Check files in remote directory exists locally, if not, they are removed remote." >> ${logfile}
FILES_REMOVED=0
REMOTE_FILES=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "ls -1 ${REMOTEDIR} && ls -1 *.tar 2> /dev/null" 2>> ${logfile}`
if [ ! -z "${REMOTE_FILES}" ]; then
    for REMOTE_FILE in ${REMOTE_FILES}; do
        REMOTE_FILE=`basename ${REMOTE_FILE}`
        if [ ! -z ${REMOTE_FILE} ]; then
            if [ ! -f "${backup_dir}/${REMOTE_FILE}" ]; then
                RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "rm ${REMOTEDIR}/${REMOTE_FILE}" 2>> ${logfile}`
                RESULT_CODE=$?
                if [ ${RESULT_CODE} -ne 0 ]; then
                    echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}"
                    echo "  $(date +%Y%m%d_%H%M%S): ERROR. SSH command error when removing remote file: ${REMOTE_FILE}. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
                    echo "  $(date +%Y%m%d_%H%M%S): Script ending prematurely." >> ${logfile}
                    exit 1
                else
                    FILES_REMOVED=$((${FILES_REMOVED}+1))
                    echo "  $(date +%Y%m%d_%H%M%S): ${REMOTE_FILE}: Does not exists locally, and is removed in remote directory." >> ${logfile}
                fi
            else
                SIZE_REMOTE=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "stat -c %s ${REMOTEDIR}/${REMOTE_FILE}" 2>> ${logfile}`
                RESULT_CODE=$?
                if [ ${RESULT_CODE} -ne 0 ]; then
                    echo "  ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${SIZE_REMOTE}"
                    echo "  $(date +%Y%m%d_%H%M%S): ERROR. SSH command error when getting size of remote file: ${REMOTE_FILE}. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
                    echo "  $(date +%Y%m%d_%H%M%S): Script ending prematurely." >> ${logfile}
                    exit 1
                fi
                
                SIZE=`stat -c %s ${backup_dir}/${REMOTE_FILE} 2>> ${logfile}`
                if [ "${SIZE_REMOTE}" == "${SIZE}" ]; then
                    echo "  $(date +%Y%m%d_%H%M%S): ${REMOTE_FILE}: Remote file exists locally and are equal in size, not required to be transfered." >> ${logfile}
                else
                    RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "rm ${REMOTEDIR}/${REMOTE_FILE}" 2>> ${logfile}`
                    RESULT_CODE=$?
                    if [ ${RESULT_CODE} -ne 0 ]; then
                        echo "  ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}"
                        echo "  $(date +%Y%m%d_%H%M%S): ERROR. SSH command error when removing remote file: ${REMOTE_FILE}. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
                        echo "  $(date +%Y%m%d_%H%M%S): Script ending prematurely." >> ${logfile}
                        exit 1
                    else
                        FILES_REMOVED=$((${FILES_REMOVED}+1))
                        echo "  $(date +%Y%m%d_%H%M%S): ${REMOTE_FILE}: Remote file exists locally but files are not equal in size, therefore removed in remote directory." >> ${logfile}
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
echo "$(date +%Y%m%d_%H%M%S): Check if files exists remotely, if not, transfer." >> ${logfile}
cd ${backup_dir} || exit 1
FILES_COPIED=0
LOCAL_FILES=`ls -1 *.tar 2> /dev/null`
if [ ! -z "${LOCAL_FILES}" ]; then
    for LOCAL_FILE in ${LOCAL_FILES}; do
        if [ ! -z ${LOCAL_FILE} ]; then
            CHECK=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "ls -1 \"${REMOTEDIR}/${LOCAL_FILE}\" 2> /dev/null" 2>> ${logfile}`
            if [ -z ${CHECK} ]; then
                echo "  $(date +%Y%m%d_%H%M%S): ${LOCAL_FILE}: Local file does not exists remotely, and is being transfered." >> ${logfile}
                RESULT=`scp -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} -p "${backup_dir}/${LOCAL_FILE}" "${SERVER}:${REMOTEDIR}/" 2>> ${logfile}`
                RESULT_CODE=$?
                if [ ${RESULT_CODE} -ne 0 ] 
                then
                    echo "  ERROR. SSH command error when transferring file: ${LOCAL_FILE}. Exit code: ${RESULT_CODE}: ${RESULT}"
                    echo "  $(date +%Y%m%d_%H%M%S): ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
                    echo "  $(date +%Y%m%d_%H%M%S): Script ending prematurely." >> ${logfile}
                    exit 1
                else
                    FILES_COPIED=$((${FILES_COPIED}+1))
                fi
            else
               echo "  $(date +%Y%m%d_%H%M%S): ${LOCAL_FILE}: Local file exists remotely, no need to transfer." >> ${logfile}
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