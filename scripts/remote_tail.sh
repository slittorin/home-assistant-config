#!/bin/bash
#
# Purpose:
# Retrieve last row of remote file.
#
# Usage:
# ./remote_tail.sh SERVER PATHTOFILE
#
# Example: ./remote_tail.sh pi@192.168.2.30 /srv/backup-to-nas.log
#
# SERVER     - Mandatory. Is the remote server in format: user@NAME/IP.
#              Remember that the server must be able to run commands without password (such as key based login).
# PATHTOFILE - Full path to file.

# Load environment variables (mainly secrets).
if [ -f "/config/.env" ]; then
    export $(cat "/config/.env" | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

# Variables:
config_dir="/config"
base_dir="/config/scripts"
log_dir="/config/logs"
logfile="${log_dir}/remote_tail.log"
logfile_tmp="${log_dir}/remote_tail.tmp"
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

# Check server.
if [ -z "$2" ]; then
    echo "ERROR. Path to file must be given."
    echo "$(date +%Y%m%d_%H%M%S): ERROR. Full path to file must be given." >> ${logfile}
    exit 1
else
    FILE="$2"
fi

# Run command.
RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "tail -1 ${FILE}"`
RESULT_CODE=$?
if [ ${RESULT_CODE} -ne 0 ] 
then
    echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" 
    echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
    exit 1
fi

# Log, and limit logfile to 1000 rows.
echo "$(date +%Y%m%d_%H%M%S): INFO. Server: ${SERVER}. File: ${FILE}. Result: ${RESULT}." >> ${logfile}
tail -n1000 ${logfile} > ${logfile_tmp}
rm ${logfile}
mv ${logfile_tmp} ${logfile}

# Show output
echo "${RESULT}"

exit 0