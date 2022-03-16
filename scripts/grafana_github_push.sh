#!/bin/bash
#
# Purpose:
# Push Grafana configuration on other server to github.
#
# Usage:
# ./grafana_github_push.sh SERVER HOST COMMENT
#
# SERVER    - Mandatory. Is the remote server in format: user@NAME/IP.
#             Remember that the server must be able to run commands without password (such as key based login).
# HOST      - The Grafana host/IP to connect to, including port.
# COMMENT   - The comment to add to the push-commit.
#             If empty, the default comment will be: "Minor change."
#
# Pre-req. is that the script for pushing Grafana JSON-files to Github exists on the other server as: /srv/grafana-git.sh

# Load environment variables (mainly secrets).
if [ -f "/config/.env" ]; then
    export $(cat "/config/.env" | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

# Variables:
config_dir="/config"
base_dir="/config/scripts"
log_dir="/config/logs"
logfile="${log_dir}/grafana_github_push.log"
logfile_tmp="${log_dir}/grafana_github_push.tmp"

touch ${logfile}

# Check server.
if [ -z "$1" ]; then
    echo "ERROR. Server must be given."
    echo "$(date +%Y%m%d_%H%M%S): ERROR. Server must be given." >> ${logfile}
    exit 1
else
    SERVER="$1"
fi

# Check host.
if [ -z "$2" ]; then
    echo "ERROR. Host must be given."
    echo "$(date +%Y%m%d_%H%M%S): ERROR. Grafana host must be given." >> ${logfile}
    exit 1
else
    HOST="$2"
fi

# Check comment.
if [ -z "$3" ]; then
    NO_COMMENT=1
    COMMENT="Minor change."
else
    NO_COMMENT=0
    COMMENT="$3"
fi

echo "$(date +%Y%m%d_%H%M%S): Starting Grafana Github push." >> ${logfile}

if [ ${NO_COMMENT} -eq 1 ]; then
    echo "$(date +%Y%m%d_%H%M%S): No input given, setting comment to default." >> ${logfile}
fi

# Initialize the remote script.
RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "/srv/grafana-git.sh ${HOST} ${COMMENT}" 2>> ${logfile}`
RESULT_CODE=$?
if [ ${RESULT_CODE} -ne 0 ]; then
    echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}"
    echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error when removing triggering remote script. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
    exit 1
else
    echo "$(date +%Y%m%d_%H%M%S): File ${FILE} remote script triggered." >> ${logfile}
fi

# Get the last row in the log.
RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "tail -1 /srv/grafana-git.log" 2>> ${logfile}`

# Log, and limit logfile to 1000 rows.
echo "${RESULT}" >> ${logfile}
tail -n1000 ${logfile} > ${logfile_tmp}
rm ${logfile}
mv ${logfile_tmp} ${logfile}

# Show output
echo "${RESULT}"

exit 0