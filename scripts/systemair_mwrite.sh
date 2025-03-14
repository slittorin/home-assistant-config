#!/bin/bash
#
# Purpose:
# Write to Systemair Save Connect device.
#
# Usage:
#   ./systemair_mwrite.sh IPADDRESS REGISTER VALUE
# Example to set temperature setpoint to 17 degrees celcius.
#   ./systemair_mwrite.sh 192.168.4.118 2000 170

# Load environment variables (mainly secrets).
if [ -f "/config/.env" ]; then
    export $(cat "/config/.env" | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

# Check input.
if [ $# -lt 3 ]
then
    no_variables=1
    echo "ERROR. Not enough arguments supplied."
else
    no_variables=0
fi

# Variables:
arg_ip="$1"
arg_register="$3"
arg_value="$3"
base_dir="/config/scripts"
log_dir="/config/logs"
logfile="${log_dir}/systemair_mwrite.log"
logfile_tmp="${log_dir}/systemair_mwrite.tmp"
# Default exit code and status.
exit_code=1
status="Ending script."

_initialize() {
    touch "${logfile}"

    echo ""
    echo "----------------------------------------------------------------------------------------------------------------"
    echo "$(date +%Y%m%d_%H%M%S): Starting to Systemair Save Connect device"

    if [ ${no_variables} -eq 1 ] 
    then
        echo "$(date +%Y%m%d_%H%M%S): ERROR. Not enough arguments supplied."
    fi
}

_mwrite() {
    cd ${base_dir}
    
    status_error=""

    url="http://" + arg_ip + "/mwrite?{%22" + arg_register + "%22:" + arg_value + "}"
    curl_output=`curl ${url}`
    curl_exit_code=$?

    if [ ${curl_exit_code} -ne 0 ] 
    then
        exit_code=1
        status="Curl ended with error code: ${curl_exit_code}"
    else
        exit_code=0
        status="No error."

        # Give output from curl to Home Assistant.
        echo ${curl_output}
    fi
}

_finalize() {
    echo "$(date +%Y%m%d_%H%M%S): ${status}"
}

# Main
_initialize >> "${logfile}" 2>&1
if [ ${no_variables} -eq 0 ] 
then
    _mwrite >> "${logfile}" 2>&1
fi
_finalize >> "${logfile}" 2>&1

# Limit the number of rows in the logfile
tail -n1000 ${logfile} > ${logfile_tmp}
rm ${logfile}
mv ${logfile_tmp} ${logfile}

exit ${exit_code}