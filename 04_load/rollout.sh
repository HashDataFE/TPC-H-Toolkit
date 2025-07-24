#!/bin/bash
set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})

step="load"

log_time "Step ${step} started"
printf "\n"

init_log ${step}

ADMIN_HOME=$(eval echo ~$ADMIN_USER)

filter="gpdb"

env_file=""

if [ "$DB_VERSION" = "synxdb_4" ]; then
    env_file="${GPHOME}/cluster_env.sh"
elif [ "$DB_VERSION" = "synxdb_2" ]; then
    env_file="${GPHOME}/synxdb_path.sh"
else
    env_file="${GPHOME}/greenplum_path.sh"
fi

function copy_script()
{
  echo "copy the start and stop scripts to the segment hosts in the cluster"
  for i in $(cat ${TPC_H_DIR}/segment_hosts.txt); do
    echo "scp start_gpfdist.sh stop_gpfdist.sh ${i}:"
    scp ${PWD}/start_gpfdist.sh ${PWD}/stop_gpfdist.sh ${i}: &
  done
  wait
}

function stop_gpfdist()
{
  echo "stop gpfdist on all ports"
  for i in $(cat ${TPC_H_DIR}/segment_hosts.txt); do
    ssh -n $i "bash -c 'cd ~/; ./stop_gpfdist.sh'" &
  done
  wait
}

function start_gpfdist()
{
  stop_gpfdist
  sleep 1
  get_gpfdist_port

  if [ "${VERSION}" == "gpdb_4_3" ] || [ "${VERSION}" == "gpdb_5" ]; then
    SQL_QUERY="select rank() over (partition by g.hostname order by p.fselocation), g.hostname, p.fselocation as path from gp_segment_configuration g join pg_filespace_entry p on g.dbid = p.fsedbid join pg_tablespace t on t.spcfsoid = p.fsefsoid where g.content >= 0 and g.role = '${GPFDIST_LOCATION}' and t.spcname = 'pg_default' order by g.hostname"
  else
    SQL_QUERY="select rank() over(partition by g.hostname order by g.datadir), g.hostname, g.datadir from gp_segment_configuration g where g.content >= 0 and g.role = '${GPFDIST_LOCATION}' order by g.hostname"
  fi
  
  flag=10
  for i in $(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -A -t -c "${SQL_QUERY}"); do
    CHILD=$(echo ${i} | awk -F '|' '{print $1}')
    EXT_HOST=$(echo ${i} | awk -F '|' '{print $2}')
    GEN_DATA_PATH=$(echo ${i} | awk -F '|' '{print $3}' | sed 's#//#/#g')
    GEN_DATA_PATH="${GEN_DATA_PATH}/hbenchmark"
    PORT=$((GPFDIST_PORT + flag))
    let flag=$flag+1
    log_time "ssh -n ${EXT_HOST} \"bash -c 'cd ~${ADMIN_USER}; ./start_gpfdist.sh $PORT ${GEN_DATA_PATH} ${env_file}'\""
    ssh -n ${EXT_HOST} "bash -c 'cd ~${ADMIN_USER}; ./start_gpfdist.sh $PORT ${GEN_DATA_PATH} ${env_file}'" &
  done
  wait
}

if [ "${RUN_MODEL}" == "local" ]; then
  copy_script
  start_gpfdist
fi
# Wait for all gpfidist to start
# sleep 10


# Create FIFO for concurrency control
mkfifo /tmp/$$.fifo
exec 5<> /tmp/$$.fifo
rm -f /tmp/$$.fifo

# Initialize tokens based on the value of LOAD_PARALLEL
for ((i=0; i<${LOAD_PARALLEL}; i++)); do
    echo >&5
done

# Use find to get just filenames, then process each file in numeric order

schema_name=${DB_SCHEMA_NAME}
ext_schema_name="ext_${DB_SCHEMA_NAME}"

for i in $(find "${PWD}" -maxdepth 1 -type f -name "*.${filter}.*.sql" -printf "%f\n" | sort -n); do
# Acquire a token to control concurrency
  read -u 5
  {
    start_log
    id=$(echo ${i} | awk -F '.' '{print $1}')
    table_name=$(echo ${i} | awk -F '.' '{print $3}')
    
    if [ "${RUN_MODEL}" == "cloud" ]; then
      GEN_DATA_PATH=${CLIENT_GEN_PATH}
      tuples=0
      for file in ${GEN_DATA_PATH}/[0-9]*/${table_name}.tbl.[0-9]*; do
        if [ -e "$file" ]; then
          log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -c \"\COPY ${DB_SCHEMA_NAME}.${table_name} FROM PROGRAM 'sed \"s/|$//\" $file' WITH (FORMAT csv, DELIMITER '|', NULL '', ESCAPE E'\\\\\\\\', ENCODING 'LATIN1')\" | grep COPY | awk -F ' ' '{print \$2}'"
          result=$(
            psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -c "\COPY ${DB_SCHEMA_NAME}.${table_name} FROM PROGRAM 'sed \"s/|$//\" $file' WITH (FORMAT csv, DELIMITER '|', NULL '', ESCAPE E'\\\\', ENCODING 'LATIN1')" | grep COPY | awk -F ' ' '{print $2}'
            exit ${PIPESTATUS[0]}
          )
          tuples=$((tuples + result))
        else
          log_time "Found no file: ${file} for ${table_name}"
        fi
      done
    else
      log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -f ${PWD}/${i} -v ext_schema_name=\"$ext_schema_name\" -v DB_SCHEMA_NAME=\"${DB_SCHEMA_NAME}\" | grep INSERT | awk -F ' ' '{print \$3}'"
      tuples=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -f ${PWD}/${i} -v ext_schema_name="$ext_schema_name" -v DB_SCHEMA_NAME="${DB_SCHEMA_NAME}" | grep INSERT | awk -F ' ' '{print $3}'; exit ${PIPESTATUS[0]})
    fi
    print_log ${tuples}
    # Release the token
    echo >&5
  } &
done

wait
# Close the file descriptor
exec 5>&-

log_time "finished loading tables."

log_time "Starting post loading processing..."
log_time " 1. Create indexes and keys"

if [ "${DB_VERSION}" == "postgresql" ]; then
  log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -f ${PWD}/100.postgresql.indexkeys.sql -v DB_SCHEMA_NAME=\"${DB_SCHEMA_NAME}\""
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -f ${PWD}/100.postgresql.indexkeys.sql -v DB_SCHEMA_NAME="${DB_SCHEMA_NAME}"
fi

log_time " 2. Analyze tables"

start_log

schema_name=${DB_SCHEMA_NAME}
table_name="analyzedb"
id=""

if [ "${RUN_ANALYZE}" == "true" ]; then

  log_time "Analyze tables started:"
  log_time "psql ${PSQL_OPTIONS} -t -A -c \"select 'analyze ' ||schemaname||'.'||tablename||';' from pg_tables WHERE schemaname = '${DB_SCHEMA_NAME}' and tablename NOT like '%prt%';\" |xargs -I {} -P ${RUN_ANALYZE_PARALLEL} psql ${PSQL_OPTIONS} -a -A -c \"{}\""
  psql ${PSQL_OPTIONS} -t -A -c "select 'analyze ' ||schemaname||'.'||tablename||';' from pg_tables WHERE schemaname = '${DB_SCHEMA_NAME}' and tablename NOT like '%prt%';" |xargs -I {} -P ${RUN_ANALYZE_PARALLEL} psql ${PSQL_OPTIONS} -a -A -c "{}"

  #make sure root stats are gathered
  if [ "${DB_VERSION}" == "gpdb_4_3" ] || [ "${DB_VERSION}" == "gpdb_5" ] || [ "${DB_VERSION}" == "gpdb_6" ]; then
    SQL_QUERY="select n.nspname, c.relname from pg_class c join pg_namespace n on c.relnamespace = n.oid left outer join (select starelid from pg_statistic group by starelid) s on c.oid = s.starelid join (select tablename from pg_partitions group by tablename) p on p.tablename = c.relname where n.nspname = '${DB_SCHEMA_NAME}' and s.starelid is null order by 1, 2"
  else
    SQL_QUERY="select n.nspname, c.relname from pg_class c join pg_namespace n on c.relnamespace = n.oid left outer join (select starelid from pg_statistic group by starelid) s on c.oid = s.starelid join pg_partitioned_table p on p.partrelid = c.oid where n.nspname = '${DB_SCHEMA_NAME}' and s.starelid is null order by 1, 2"
  fi

  for t in $(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "${SQL_QUERY}"); do
    schema_name=$(echo ${t} | awk -F '|' '{print $1}')
    table_name=$(echo ${t} | awk -F '|' '{print $2}')
    log_time "Missing root stats for ${schema_name}.${table_name}"
    SQL_QUERY="ANALYZE ROOTPARTITION ${schema_name}.${table_name}"
    log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c \"${SQL_QUERY}\""
    psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "${SQL_QUERY}"
  done
  log_time "Analyze tables finished."
else
  echo "AnalyzeDB Skipped..."
fi

tuples="-1"
print_log ${tuples}

log_time " 3. Clean up gpfdist"

if [ "${RUN_MODEL}" == "remote" ]; then
  sh ${PWD}/stop_gpfdist.sh
elif [ "${RUN_MODEL}" == "local" ]; then
  stop_gpfdist
fi

log_time "Step ${step} finished"
printf "\n"
