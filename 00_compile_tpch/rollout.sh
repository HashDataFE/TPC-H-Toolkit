#!/bin/bash
set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})

step="compile_tpch"

log_time "Step ${step} started"
printf "\n"

init_log ${step}
start_log
schema_name=${SCHEMA_NAME}
table_name="compile"

compile_flag="true"

function make_tpc()
{
  #compile the tools
  cd ${PWD}/dbgen
  rm -f ./*.o
  ADDITIONAL_CFLAGS_OPTION="-g -Wno-unused-function -Wno-unused-but-set-variable -Wno-format -fcommon" make
  cd ..
}

function copy_queries()
{
  rm -rf ${TPC_H_DIR}/*_gen_data/queries
  rm -rf ${TPC_H_DIR}/*_multi_user/queries
  cp -R ${PWD}/dbgen/queries ${TPC_H_DIR}/*_gen_data/
  cp -R ${PWD}/dbgen/queries ${TPC_H_DIR}/*_multi_user/
}

function copy_tpc()
{
  cp ${PWD}/dbgen/qgen ${TPC_H_DIR}/*_gen_data/queries/
  cp ${PWD}/dbgen/qgen ${TPC_H_DIR}/*_multi_user/queries/
  cp ${PWD}/dbgen/dists.dss ${TPC_H_DIR}/*_gen_data/queries/
  cp ${PWD}/dbgen/dists.dss ${TPC_H_DIR}/*_multi_user/queries/

  #copy the compiled dbgen program to the segment nodes
  echo "copy tpch binaries to segment hosts"
  for i in $(cat ${TPC_H_DIR}/segment_hosts.txt); do
    scp ${PWD}/dbgen/dbgen ${PWD}/dbgen/dists.dss ${i}: &
  done
  wait
}

function check_binary() {
  set +e
  
  cd ${PWD}/dbgen/
  cp -f dbgen.${CHIP_TYPE} dbgen
  cp -f qgen.${CHIP_TYPE} qgen
  chmod +x dbgen
  chmod +x qgen

  ./dbgen -h
  if [ $? == 1 ]; then 
    ./qgen -h
    if [ $? == 0 ]; then
      compile_flag="false" 
    fi
  fi
  cd ..
  set -e
}

function check_chip_type() {
  # Get system architecture information
  ARCH=$(uname -m)

  # Determine the architecture type and assign to variable
  if [[ $ARCH == *"x86"* || $ARCH == *"i386"* || $ARCH == *"i686"* ]]; then
    export CHIP_TYPE="x86"
  elif [[ $ARCH == *"arm"* || $ARCH == *"aarch64"* ]]; then
    export CHIP_TYPE="arm"
  else
    export CHIP_TYPE="unknown"
  fi

  # Print the result for verification
  echo "Chip type: $CHIP_TYPE"
}

check_chip_type
check_binary

if [ "${compile_flag}" == "true" ]; then
  make_tpc
else
  echo "Binary works, no compiling needed."
fi

create_hosts_file
copy_queries
copy_tpc
print_log

echo "Finished ${step}"
log_time "Step ${step} finished"
printf "\n"
