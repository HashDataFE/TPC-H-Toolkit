#!/bin/bash
set -e

if [ "$(alias | grep -wc grep)" -gt 0 ]; then
  unalias grep
fi
if [ "$(alias | grep -wc ls)" -gt 0 ]; then
  unalias ls
fi

################################################################################
####  Unexported functions  ####################################################
################################################################################
function check_variable() {
  local var_name="${1}"
  shift

  if [ ! -n "${!var_name}" ]; then
    echo "${var_name} is not defined in ${VARS_FILE}. Exiting."
    exit 1
  fi
}

function check_variables() {
  echo "############################################################################"
  echo "Sourcing ${VARS_FILE}"
  echo "############################################################################"
  echo ""
  # shellcheck source=tpch_variables.sh
  source ./${VARS_FILE} 2> /dev/null
  if [ $? -ne 0 ]; then
    echo "./${VARS_FILE} does not exist. Please ensure that this file exists before running TPC-H. Exiting."
    exit 1
  fi

  # Extract all exported variable names from non-commented lines
  local missing_vars=()
  local var_names
  var_names=$(grep -E '^[[:space:]]*export[[:space:]]+' ./${VARS_FILE} | grep -v '^[[:space:]]*#' | awk '{print $2}' | cut -d= -f1)

  for var in $var_names; do
    if [ "$var" = "PSQL_OPTIONS" ]; then
      # Allow PSQL_OPTIONS to be empty
      continue
    fi
    if [ -z "${!var}" ]; then
      echo "ERROR: Variable '$var' is not set or is empty in ${VARS_FILE}."
      missing_vars+=("$var")
    fi
  done

  if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "The following required variables are missing or empty: ${missing_vars[*]}"
    exit 1
  fi
}

function check_admin_user() {
  echo "############################################################################"
  echo "Ensure ${ADMIN_USER} is executing this script."
  echo "############################################################################"
  echo ""
  if [ "$(whoami)" != "${ADMIN_USER}" ]; then
    echo "Script must be executed as ${ADMIN_USER}!"
    exit 1
  fi
}

function print_header() {
  echo "############################################################################"
  echo "ADMIN_USER: ${ADMIN_USER}"
  echo "MULTI_USER_COUNT: ${MULTI_USER_COUNT}"
  echo "############################################################################"
  echo ""
}

# we need to declare this outside, otherwise, the declare will wipe out the
# value within a function
declare startup_file
startup_file=${HOME}/.bashrc
function source_bashrc() {
  if [ -f ${startup_file} ]; then
    # don't fail if an error is happening in the admin's profile
    # shellcheck disable=SC1090
    source ${startup_file} || true
    # Check if GPHOME is set and not empty
    if [ -z "$GPHOME" ]; then
      echo "Error: \$GPHOME is not found. Please set .bashrc correctly for ${ADMIN_USER} to source the database environment.Exiting."
      exit 1
    fi
  else
    echo "Error: ${startup_file} does not exist. Please ensure that this file is correctly set before running TPC-H. Exiting."
    exit 1
  fi
}

################################################################################
####  Exported functions  ######################################################
################################################################################
function get_pwd() {
  # Handle relative vs absolute path
  [ ${1:0:1} == '/' ] && x=${1} || x=$PWD/${1}
  # Change to dirname of x
  cd ${x%/*}
  # Combine new pwd with basename of x
  echo "$(dirname "$(pwd -P)/${x##*/}")"
  cd ${OLDPWD}
}
export -f get_pwd

function get_gpfdist_port() {
  
  if [ "$RUN_MODEL" == "local" ]; then
    all_ports=$(psql ${PSQL_OPTIONS} -t -A -c "select min(case when role = 'p' then port else 999999 end), min(case when role = 'm' then port else 999999 end) from gp_segment_configuration where content >= 0")
    primary_base=$(echo ${all_ports} | awk -F '|' '{print $1}' | head -c1)
    mirror_base=$(echo $all_ports | awk -F '|' '{print $2}' | head -c1)

    for i in $(seq 3 6); do
      if [ "${primary_base}" -ne "${i}" ] && [ "$mirror_base" -ne "${i}" ]; then
        GPFDIST_PORT="${i}666"
        export GPFDIST_PORT
        break
      fi
    done
  fi
}
export -f get_gpfdist_port

function get_version() {
  # Note: Call source_bashrc first to ensure environment is set up

  VERSION=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -c "
    SELECT 
      CASE 
        WHEN POSITION('greenplum database 4.3' IN version) > 0 THEN 'gpdb_4_3'
        WHEN POSITION('greenplum database 5' IN version) > 0 AND 
             POSITION('synxdb' IN version) = 0 THEN 'gpdb_5'
        WHEN POSITION('greenplum database 6' IN version) > 0 AND
             POSITION('synxdb' IN version) = 0 THEN 'gpdb_6'
        WHEN POSITION('greenplum database 7' IN version) > 0 AND
             POSITION('synxdb' IN version) = 0 THEN 'gpdb_7'
        WHEN POSITION('greenplum database 5' IN version) > 0 AND 
             POSITION('synxdb' IN version) > 0 THEN 'synxdb_1'
        WHEN POSITION('greenplum database 6' IN version) > 0 AND
             POSITION('synxdb' IN version) > 0 THEN 'synxdb_2'
        WHEN POSITION('greenplum database 7' IN version) > 0 AND
             POSITION('synxdb' IN version) > 0 THEN 'synxdb_3'
        WHEN POSITION('cloudberry' IN version) > 0 AND 
             POSITION('lightning' IN version) > 0 THEN 'lightning'
        WHEN POSITION('cloudberry' IN version) > 0 AND 
             POSITION('synxdb' IN version) > 0 THEN 'synxdb_4'
        WHEN POSITION('cloudberry' IN version) > 0 AND
             POSITION('synxdb' IN version) = 0 AND 
             POSITION('lightning' IN version) = 0 THEN 'cbdb'
        WHEN POSITION('postgresql' IN version) > 0 AND 
             POSITION('greenplum' IN version) = 0 AND 
             POSITION('cloudberry' IN version) = 0 AND
             POSITION('lightning' IN version) = 0 AND
             POSITION('synxdb' IN version) = 0 THEN 'postgresql'
        ELSE 'unknown'
      END 
    FROM lower(version()) as version;
  ")

  VERSION_FULL=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -c "SELECT version();")
}
export -f get_version

function init_log() {
  logfile=rollout_${1}.log
  rm -f ${TPC_H_DIR}/log/${logfile}
}
export -f init_log

function start_log() {
  T_START="$(date +%s)"
}
export -f start_log

# we need to declare this outside, otherwise, the declare will wipe out the
# value within a function
declare schema_name
declare table_name
function print_log() {
  #duration
  T_END="$(date +%s)"
  T_DURATION="$((T_END - T_START))"
  S_DURATION=${T_DURATION}

  #this is done for steps that don't have id values
  if [ "${id}" == "" ]; then
    id="1"
  else
    id=$(basename ${i} | awk -F '.' '{print $1}')
  fi

  tuples=${1}
  if [ "${tuples}" == "" ]; then
    tuples="0"
  fi

  # calling function adds schema_name and table_name
  printf "%s|%s.%s|%s|%02d:%02d:%02d|%d|%d\n" ${id} ${schema_name} ${table_name} ${tuples} "$((S_DURATION / 3600 % 24))" "$((S_DURATION / 60 % 60))" "$((S_DURATION % 60))" "${T_START}" "${T_END}" >> ${TPC_H_DIR}/log/${logfile}
}
export -f print_log

function end_step() {
  local logfile=end_${1}.log
  touch ${TPC_H_DIR}/log/${logfile}
}
export -f end_step

function log_time() {
  printf "[%s] %b\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}
export -f log_time

function create_hosts_file() {
  # not used for this function
  # get_version

  if [ "$RUN_MODEL" == "local" ]; then
    SQL_QUERY="SELECT DISTINCT hostname FROM gp_segment_configuration WHERE role = '${GPFDIST_LOCATION}' AND content >= 0"
    psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -c "${SQL_QUERY}" -o ${TPC_H_DIR}/segment_hosts.txt
  fi
}
export -f create_hosts_file
