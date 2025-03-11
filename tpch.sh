#!/bin/bash
set -e

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
VARS_FILE="$PWD/tpch_variables.sh"
FUNCTIONS_FILE="$PWD/functions.sh"

source $VARS_FILE
source $FUNCTIONS_FILE
source_bashrc

export TPC_H_DIR=$(get_pwd ${BASH_SOURCE[0]})

log_time "TPC-H test started"
printf "\n"

# Check that pertinent variables are set in the variable file.
check_variables
# Make sure this is being run as gpadmin
check_admin_user
# Output admin user and multi-user count to standard out
print_header

# run the benchmark
./rollout.sh
