#!/bin/bash
#
# Purpose:
# Write to Systemair Save Connect device.
#
# Usage:
#   ./systemair_mwrite.sh IPADDRESS/URL REGISTER VALUE
#   URL is without http:
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
arg_url="$1"
arg_register="$2"
arg_value="$3"
base_dir="/config/scripts"
log_dir="/config/logs"
logfile="${log_dir}/systemair_mwrite.log"
logfile_tmp="${log_dir}/systemair_mwrite.tmp"
# Default exit code and status.
exit_code=1
exit_output=""

_initialize() {
    touch "${logfile}"

    echo ""
    echo "----------------------------------------------------------------------------------------------------------------"
    echo "$(date +%Y%m%d_%H%M%S): Starting to write to Systemair Save Connect device"

    if [ ${no_variables} -eq 1 ] 
    then
        echo "$(date +%Y%m%d_%H%M%S): ERROR. Not enough arguments supplied."
    else
        echo "$(date +%Y%m%d_%H%M%S): URL: ${arg_url}"
        echo "$(date +%Y%m%d_%H%M%S): Register: ${arg_register}"
        echo "$(date +%Y%m%d_%H%M%S): Value: ${arg_value}"
    fi
}

_mwrite() {
    cd ${base_dir}

# curl -i 'http://192.168.4.118/mwrite?\{%222000%22:170\}' -H 'Accept: text/html,application/xhtml+xml' -H 'Accept-Language: en-US' -H 'Connection: close' -H 'Upgrade-Insecure-Requests: 1' -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36' --insecure

    curl_url="http://${arg_url}/mwrite?\{%22${arg_register}%22:${arg_value}\}"
    curl_output=`curl -s -i ${curl_url} -H 'Accept: text/html,application/xhtml+xml' -H 'Accept-Language: en-US' -H 'Connection: close' -H 'Upgrade-Insecure-Requests: 1' -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36' --insecure`
    curl_exit_code=$?

    if [ ${curl_exit_code} -ne 0 ] 
    then
        exit_code=1
        exit_output="ERROR. CURL ended with error code: ${curl_exit_code}."
        echo "$(date +%Y%m%d_%H%M%S): ${exit_output}."
        echo "$(date +%Y%m%d_%H%M%S): CURL output: ${curl_output}"
    else
        # We take the last row as result.
        exit_code=0
        exit_output=`echo "${curl_output}" | sed 's/\r$//' | tail -1`
        echo "$(date +%Y%m%d_%H%M%S): No error from CURL."
        echo "$(date +%Y%m%d_%H%M%S): CURL output: ${curl_output}"
    fi
}

_finalize() {
    echo "$(date +%Y%m%d_%H%M%S): Ending script." >> "${logfile}" 2>&1
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

# Give output to Home Assistant.
echo "${exit_output}"
exit ${exit_code}