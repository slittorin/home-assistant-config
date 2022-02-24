#!/bin/bash
#
# Purpose:
# Retrieve docker volume size information from remote server.
#
# Usage:
# ./remote_docker_volume_size.sh SERVER VOLUME TYPE
#
# Example: ./remote_docker_volume_size.sh pi@192.168.2.30 /var/lib/influxdb2 value
#
# SERVER    - Mandatory. Is the remote server in format: user@NAME/IP.
#             Remember that the server must be able to run commands without password (such as key based login).
# VOLUME    - Mandatory. The docker volume name. Does not need to match the entire volume-name, but give only one result.
# TYPE      - Default will be used if not given or not recognized. The measure, one of the following:
#             value             - The size of the volume in MB [default].
#             datetime          - The datetime, in format YYYYMMDD HHMMSS.

# Load environment variables (mainly secrets).
if [ -f "/config/.env" ]; then
    export $(cat "/config/.env" | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

# Variables:
config_dir="/config"
base_dir="/config/scripts"
log_dir="/config/logs"
logfile="${log_dir}/remote_docker_volume_size.log"
logfile_tmp="${log_dir}/remote_docker_volume_size.tmp"
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

# Check volume.
if [ -z "$2" ]; then
    echo "ERROR. Volume must be given."
    echo "$(date +%Y%m%d_%H%M%S): ERROR. Volume must be given." >> ${logfile}
    exit 1
else
    VOLUME="$2"
fi

# Check type to retrieve.
if [ -z "$3" ]; then
    TYPE="value"
else
    TYPE="$3"
fi

# Set the file to look into.
FILE="/srv/stats/docker_volume_sizes.txt"

# Run command.
RESULT=$(ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "cat ${FILE} | grep ${VOLUME}" 2>> ${logfile})
RESULT_CODE=$?
if [ ${RESULT_CODE} -ne 0 ] 
then
    echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" 
    echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
    exit 1
fi

# We should only get one line.
LINES=$(echo "${RESULT}" | wc -l)
if [ ${LINES} -ne 1 ]; then
    echo "ERROR. Volume name too ambigous, several volumes found."
    echo "$(date +%Y%m%d_%H%M%S): ERROR. Volume name too ambigous, several volumes found." >> ${logfile}
    exit 1
fi

# Get the values.
DATETIME=`echo ${RESULT} | awk -F, '{ print $1 }'i | sed 's/_/ /'`
VALUE=`echo ${RESULT} | awk -F, '{ print $4 }'`

# Show the result
if [ "${TYPE}" == "datetime" ] ;then
    RESULT="${DATETIME}"
else
    RESULT="${VALUE}"
fi

# Log, and limit logfile to 1000 rows.
echo "$(date +%Y%m%d_%H%M%S): INFO. Server: ${SERVER}. File: ${FILE}. Measure: ${MEASURE}. Result: ${RESULT}." >> ${logfile}
tail -n1000 ${logfile} > ${logfile_tmp}
rm ${logfile}
mv ${logfile_tmp} ${logfile}

# Show output
echo "${RESULT}"

exit 0