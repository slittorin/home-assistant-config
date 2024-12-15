#!/bin/bash
#
# Purpose:
# Copy home-assistant.log.1 to log-directory, to preserve old logs.
#
# Usage:
# ./copy_logfile.sh
#
# Intended to be triggered by automation after reboot.

# Load environment variables (mainly secrets).
if [ -f "/config/.env" ]; then
    export $(cat "/config/.env" | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

# Variables:
config_dir="/config"
log_dir="/config/logs"
logfile="${log_dir}/copy_logfile.log"
logfile_tmp="${log_dir}/copy_logfile.tmp"
ha_logfile="${config_dir}/home-assistant.log.1"
ha_logfile_copied="${log_dir}/home-assistant/home-assistant.log.$(date +%Y%m%d_%H%M%S)"

touch ${logfile}

echo "" >> ${logfile}
echo "$(date +%Y%m%d_%H%M%S): Starting copy of home assistant logfile." >> ${logfile}

# Copy the file
RESULT=`cp ${ha_logfile} ${ha_logfile_copied} 2>> ${logfile}`
RESULT_CODE=$?
if [ ${RESULT_CODE} -ne 0 ] 
then
    echo "$(date +%Y%m%d_%H%M%S): ERROR. Copy command error from ${ha_logfile} to ${ha_logfile_copied}. Exit code: ${RESULT_CODE}: ${RESULT}" >> ${logfile}
fi

# Log, and limit logfile to 1000 rows.
RESULT="$(date +%Y%m%d_%H%M%S): No error. Copied file ${ha_logfile} to ${ha_logfile_copied}."
echo "${RESULT}" >> ${logfile}
tail -n1000 ${logfile} > ${logfile_tmp}
rm ${logfile}
mv ${logfile_tmp} ${logfile}

exit 0