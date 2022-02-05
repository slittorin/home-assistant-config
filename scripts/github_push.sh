#!/bin/bash
#
# Purpose:
# Push configuration to github.
#
# Usage:
# ./github_push.sh COMMENT
#
# COMMENT is the comment to add to the push-commit.
# If empty, the default comment will be: "Minor change."

# Load environment variables (mainly secrets).
if [ -f "/config/.env" ]; then
    export $(cat "/config/.env" | grep -v '#' | sed 's/\r$//' | awk '/=/ {print $1}' )
fi

# Check input.
if [ -z "$1" ]
then
    no_comment=1
    comment="Minor change."
else
    no_comment=0
    comment="$1"
fi

# Variables:
base_dir="/config/scripts"
log_dir="/config/logs"
config_dir="/config"
logfile="${log_dir}/github_push.log"

_initialize() {
    touch "${logfile}"

    echo ""
    echo "----------------------------------------------------------------------------------------------------------------"
    echo "$(date +%Y%m%d_%H%M%S): Starting Github push."

    if [ ${no_comment} -eq 1 ] 
    then
        echo "$(date +%Y%m%d_%H%M%S): No input given, setting comment to default."
    fi
}

_github_push() {
    cd ${config_dir}
    
    exit_code=0
    status_error=""
    
    # Add all in /config dir (according to .gitignore).
    echo "$(date +%Y%m%d_%H%M%S): Added all in base directory"
    git add .
    
    # We also add .storage, but allow .gitignore to only allow whitelisted files.
    # This to be able to add Lovelace files managed by UI.
    echo "$(date +%Y%m%d_%H%M%S): Added directory: .storage/"
    git add .storage/

    # Loop through all directories and add to git (according to .gitignore).
    for dir in */ ; do
        echo "$(date +%Y%m%d_%H%M%S): Added directory: ${dir}"
        git add "${dir}"
    done

    git status
    git_exit_code=$?
    if [ ${git_exit_code} -ne 0 ] 
    then
        exit_code=1
        status_error+=" status (${git_exit_code})"
    fi

    git commit -m "${comment}"
    git_exit_code=$?
    if [ ${git_exit_code} -ne 0 ] 
    then
        exit_code=1
        status_error+=" commit (${git_exit_code})"
    fi

    git push origin master
    git_exit_code=$?
    if [ ${git_exit_code} -ne 0 ] 
    then
        exit_code=1
        status_error+=" push (${git_exit_code})"
    fi

    # Check if error occured with git commands.
    if [ ${exit_code} -eq 0 ] 
    then
        status="No error."
    else
        status="Error in: git${status_error}."
    fi
}

_finalize() {
    echo "$(date +%Y%m%d_%H%M%S): ${status}"
}

# Main
_initialize >> "${logfile}" 2>&1
_github_push >> "${logfile}" 2>&1
_finalize >> "${logfile}" 2>&1
exit ${exit_code}