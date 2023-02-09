#!/bin/bash
#
# Purpose:
# Push Server1 configuration on other server to github.
#
# Usage:
# ./server1_github_push.sh SERVER HOST COMMENT
#
# SERVER    - Mandatory. Is the remote server in format: user@NAME/IP.
#             Remember that the server must be able to run commands without password (such as key based login).
# COMMENT   - The comment to add to the push-commit.
#             If empty, the default comment will be: "Minor change."
#
# Pre-req. is that the script for pushing Server1 JSON-files to Github exists on the other server as: /srv/server1-git.sh

# Load environment variables (mainly secrets).
if [ -f "/config/.env" ]; then
    export $(cat "/config/.env" | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

# Variables:
config_dir="/config"
base_dir="/config/scripts"
log_dir="/config/logs"
logfile="${log_dir}/server1_github_push.log"
logfile_tmp="${log_dir}/server1_github_push.tmp"
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

# Check comment.
if [ -z "$2" ]; then
    NO_COMMENT=1
    COMMENT="Minor change."
else
    NO_COMMENT=0
    COMMENT="$2"
fi

echo "$(date +%Y%m%d_%H%M%S): Starting Server1 Github push." >> ${logfile}
echo "$(date +%Y%m%d_%H%M%S): Server: ${SERVER}" >> ${logfile}

if [ ${NO_COMMENT} -eq 1 ]; then
    echo "$(date +%Y%m%d_%H%M%S): No comment given, setting comment to default." >> ${logfile}
fi

# Initialize the remote script.
RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "sudo /srv/server1-git.sh '${COMMENT}'" 2>> ${logfile}`
RESULT_CODE=$?
if [ ${RESULT_CODE} -ne 0 ]; then
    echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}"
    echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error when removing triggering remote script. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
    exit 1
else
    echo "$(date +%Y%m%d_%H%M%S): File ${FILE} remote script triggered." >> ${logfile}
fi

# Get the last row in the log.
RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "tail -1 /srv/log/server1-git.log" 2>> ${logfile}`

# Log, and limit logfile to 1000 rows.
echo "${RESULT}" >> ${logfile}
tail -n1000 ${logfile} > ${logfile_tmp}
rm ${logfile}
mv ${logfile_tmp} ${logfile}

# Show output
echo "${RESULT}"

exit 0