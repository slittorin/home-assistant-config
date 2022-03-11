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

echo "$(date +%Y%m%d_%H%M%S): Starting copy of backup." >> ${logfile}

# Run command.
RESULT=`scp -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} -p -r /backup ${SERVER}:${REMOTEDIR} 2>> ${logfile}`
RESULT_CODE=$?
if [ ${RESULT_CODE} -ne 0 ] 
then
    echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" 
    echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
    exit 1
fi

# Log, and limit logfile to 1000 rows.
echo "$(date +%Y%m%d_%H%M%S): INFO. Server: ${SERVER}. File: ${FILE}. Measure: ${MEASURE}. Result: ${RESULT}." >> ${logfile}
tail -n1000 ${logfile} > ${logfile_tmp}
rm ${logfile}
mv ${logfile_tmp} ${logfile}

echo "$(date +%Y%m%d_%H%M%S): Ended copy of backup." >> ${logfile}

# Show output
echo "${RESULT}"

exit 0