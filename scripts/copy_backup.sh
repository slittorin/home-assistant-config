#!/bin/bash
#
# Purpose:
# Retrieve statistics from remote server.
#
# Usage:
# ./remote_command.sh SERVER STAT TYPE
#
# Example: ./remote_command.sh pi@192.168.2.30 cpu_temp value
#
# SERVER    - Mandatory. Is the remote server in format: user@NAME/IP.
#             Remember that the server must be able to run commands without password (such as key based login).
# STAT      - Default will be used if not given or not recognized. The statistics to retrieve, one of the following:
#             cpu_used_pct      - CPU utilization in percentage over 15 minutes [default].
#             cpu_temp          - CPU temperature in degrees celcius.
#             disk_used_pct     - Disk utilization in percent.
#             mem_used_pct      - RAM utilization in percent.
#             swap_used_pct     - Swap utilization in percent.
#             uptime            - Uptime (last reboot).
# TYPE      - Default will be used if not given or not recognized. The measure, one of the following:
#             value             - The value [default].
#             datetime          - The datetime, in format YYYYMMDD HHMMSS.

# Load environment variables (mainly secrets).
if [ -f "/config/.env" ]; then
    export $(cat "/config/.env" | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

# Variables:
config_dir="/config"
base_dir="/config/scripts"
log_dir="/config/logs"
logfile="${log_dir}/remote_stats.log"
logfile_tmp="${log_dir}/remote_stats.tmp"
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

# Check statistics to retrieve.
if [ -z "$2" ]; then
    STATISTICS="cpu_used_pct"
else
    STATISTICS="$2"
fi

# Check type to retrieve.
if [ -z "$3" ]; then
    TYPE="value"
else
    TYPE="$3"
fi

# Different type of statistics
if [ "${STATISTICS}" == "cpu_temp" ] ;then
    FILE="/srv/stats/cpu_temp.txt "
elif [ "${STATISTICS}" == "disk_used_pct" ] ;then
    FILE="/srv/stats/disk_used_pct.txt"
elif [ "${STATISTICS}" == "mem_used_pct" ] ;then
    FILE="/srv/stats/mem_used_pct.txt"
elif [ "${STATISTICS}" == "swap_used_pct" ] ;then
    FILE="/srv/stats/swap_used_pct.txt"
elif [ "${STATISTICS}" == "uptime" ] ;then
    FILE="/srv/stats/uptime.txt"
else
    FILE="/srv/stats/cpu_used_pct.txt"
fi

# Run command.
RESULT=`ssh -o BatchMode=yes -o UserKnownHostsFile=${known_hosts_file} -i ${rsa_file} ${SERVER} "cat ${FILE}" 2>> ${logfile}`
RESULT_CODE=$?
if [ ${RESULT_CODE} -ne 0 ] 
then
    echo "ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" 
    echo "$(date +%Y%m%d_%H%M%S): ERROR. SSH command error. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
    exit 1
fi

# Get the values.
DATETIME=`echo ${RESULT} | awk -F, '{ print $1 }'i | sed 's/_/ /'`
VALUE=`echo ${RESULT} | awk -F, '{ print $2 }'`

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