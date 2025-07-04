#!/bin/bash
set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})

step="ddl"

log_time "Step ${step} started"
printf "\n"

init_log ${step}
get_version

filter="gpdb"
schema_name=${DB_SCHEMA_NAME}
ext_schema_name="ext_${DB_SCHEMA_NAME}"

if [ "${VERSION}" == "gpdb_4_3" ] || [ "${VERSION}" == "gpdb_5" ]; then
  distkeyfile="distribution_original.txt"
else
  distkeyfile="distribution.txt"
fi

if [ "${DROP_EXISTING_TABLES}" == "true" ]; then
  #Create tables
  for i in $(ls ${PWD}/*.${filter}.*.sql); do
    file_name=$(echo ${i} | awk -F '/' '{print $NF}')
    id=$(echo ${file_name} | awk -F '.' '{print $1}')
    table_name=$(echo ${file_name} | awk -F '.' '{print $3}')
    start_log

    if [ "${RANDOM_DISTRIBUTION}" == "true" ]; then
      DISTRIBUTED_BY="DISTRIBUTED RANDOMLY"
    else
      for z in $(cat ${PWD}/${distkeyfile}); do
        table_name2=$(echo ${z} | awk -F '|' '{print $2}')
        if [ "${table_name2}" == "${table_name}" ]; then
          distribution=$(echo ${z} | awk -F '|' '{print $3}')
        fi
      done
      if [ "${distribution^^}" == "REPLICATED" ]; then
        DISTRIBUTED_BY="DISTRIBUTED REPLICATED"
      else
        DISTRIBUTED_BY="DISTRIBUTED BY (${distribution})"
      fi
    fi

    if [ "${DB_VERSION}" == "postgresql" ]; then
      DISTRIBUTED_BY=""
    fi

    log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -q -P pager=off -f ${i} -v STORAGE_OPTIONS=\"${STORAGE_OPTIONS}\" -v DISTRIBUTED_BY=\"${DISTRIBUTED_BY}\" -v ext_schema_name=\"${ext_schema_name}\" -v DB_SCHEMA_NAME=\"${DB_SCHEMA_NAME}\""
    psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -q -P pager=off -f ${i} -v ACCESS_METHOD="${TABLE_ACCESS_METHOD}" -v STORAGE_OPTIONS="${TABLE_STORAGE_OPTIONS}" -v DISTRIBUTED_BY="${DISTRIBUTED_BY}" -v ext_schema_name="${ext_schema_name}" -v DB_SCHEMA_NAME="${DB_SCHEMA_NAME}"
    print_log
  done

  # Process partition files in numeric order
  if [ "${TABLE_USE_PARTITION}" == "true" ]; then
    for i in $(find "${PWD}" -maxdepth 1 -type f -name "*.${filter}.*.partition" -printf "%f\n" | sort -n); do
      start_log
      id=$(echo "${i}" | awk -F '.' '{print $1}')
      export id
      schema_name=${DB_SCHEMA_NAME}
      #schema_name=$(echo ${i} | awk -F '.' '{print $2}')
      export schema_name
      table_name=$(echo ${i} | awk -F '.' '{print $3}')
      export table_name

    if [ "${RANDOM_DISTRIBUTION}" == "true" ]; then
      DISTRIBUTED_BY="DISTRIBUTED RANDOMLY"
    else
      for z in $(cat ${PWD}/${distkeyfile}); do
        table_name2=$(echo ${z} | awk -F '|' '{print $2}')
        if [ "${table_name2}" == "${table_name}" ]; then
          distribution=$(echo ${z} | awk -F '|' '{print $3}')
        fi
      done
      
      if [ "${distribution^^}" == "REPLICATED" ]; then
        DISTRIBUTED_BY="DISTRIBUTED REPLICATED"
      else
        DISTRIBUTED_BY="DISTRIBUTED BY (${distribution})"
      fi
    fi

      #Drop existing partition tables if they exist
      SQL_QUERY="drop table if exists ${DB_SCHEMA_NAME}.${table_name} cascade"
      psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -A -t -c "${SQL_QUERY}"
      
      log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -a -P pager=off -f ${PWD}/${i} -v DB_SCHEMA_NAME=\"${DB_SCHEMA_NAME}\" -v ACCESS_METHOD=\"${TABLE_ACCESS_METHOD}\" -v STORAGE_OPTIONS=\"${TABLE_STORAGE_OPTIONS}\" -v DISTRIBUTED_BY=\"${DISTRIBUTED_BY}\""
      psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -a -P pager=off -f ${PWD}/${i} -v DB_SCHEMA_NAME="${DB_SCHEMA_NAME}" -v ACCESS_METHOD="${TABLE_ACCESS_METHOD}" -v STORAGE_OPTIONS="${TABLE_STORAGE_OPTIONS}" -v DISTRIBUTED_BY="${DISTRIBUTED_BY}"
      print_log
    done
  fi

  #external tables are the same for all gpdb
  get_gpfdist_port

  if [ "${RUN_MODEL}" != "cloud" ]; then
    for i in $(ls ${PWD}/*.ext_tpch.*.sql); do
      start_log
  
      file_name=$(echo ${i} | awk -F '/' '{print $NF}')
      id=$(echo ${file_name} | awk -F '.' '{print $1}')
      schema_name=$(echo ${file_name} | awk -F '.' '{print $2}')
      table_name=$(echo ${file_name} | awk -F '.' '{print $3}')
  
      counter=0
  
      if [ "${VERSION}" == "gpdb_5" ] || [ "${VERSION}" == "gpdb_4_3" ]; then
        SQL_QUERY="select rank() over (partition by g.hostname order by p.fselocation), g.hostname from gp_segment_configuration g join pg_filespace_entry p on g.dbid = p.fsedbid join pg_tablespace t on t.spcfsoid = p.fsefsoid where g.content >= 0 and g.role = '${GPFDIST_LOCATION}' and t.spcname = 'pg_default' order by g.hostname"
      else
        SQL_QUERY="select rank() over(partition by g.hostname order by g.datadir), g.hostname from gp_segment_configuration g where g.content >= 0 and g.role = '${GPFDIST_LOCATION}' order by g.hostname"
      fi
  
      flag=10
      for x in $(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -A -t -c "${SQL_QUERY}"); do
        CHILD=$(echo ${x} | awk -F '|' '{print $1}')
        EXT_HOST=$(echo ${x} | awk -F '|' '{print $2}')
        PORT=$((GPFDIST_PORT + flag))
        let flag=$flag+1
  
        if [ "${counter}" -eq "0" ]; then
          LOCATION="'"
        else
          LOCATION+="', '"
        fi
        LOCATION+="gpfdist://${EXT_HOST}:${PORT}/${table_name}.tbl*"
  
        counter=$((counter + 1))
      done
      LOCATION+="'"
  
      log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -a -P pager=off -f ${i} -v LOCATION=\"${LOCATION}\""
      psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -a -P pager=off -f ${i} -v LOCATION="${LOCATION}" -v ext_schema_name="${ext_schema_name}"
  
      print_log
    done
  fi
fi

DropRoleDenp="drop owned by ${BENCH_ROLE} cascade"
DropRole="DROP ROLE IF EXISTS ${BENCH_ROLE}"
CreateRole="CREATE ROLE ${BENCH_ROLE}"
GrantSchemaPrivileges="GRANT ALL PRIVILEGES ON SCHEMA ${DB_SCHEMA_NAME} TO ${BENCH_ROLE}"
GrantTablePrivileges="GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${DB_SCHEMA_NAME} TO ${BENCH_ROLE}"
echo "rm -f ${PWD}/GrantTablePrivileges.sql"
rm -f ${PWD}/GrantTablePrivileges.sql
psql ${PSQL_OPTIONS} -tc "select \$\$GRANT ALL PRIVILEGES on table ${DB_SCHEMA_NAME}.\$\$||tablename||\$\$ TO ${BENCH_ROLE};\$\$ from pg_tables where schemaname='${DB_SCHEMA_NAME}'" > ${PWD}/GrantTablePrivileges.sql

start_log

if [ "${BENCH_ROLE}" != "gpadmin" ]; then
  set +e
  log_time "Drop role dependencies for ${BENCH_ROLE}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -c "${DropRoleDenp}"
  set -e
  log_time "Drop role ${BENCH_ROLE}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -c "${DropRole}"
  log_time "Creating role ${BENCH_ROLE}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -c "${CreateRole}"
  log_time "Grant schema privileges to role ${BENCH_ROLE}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -c "${GrantSchemaPrivileges}"
  log_time "Grant table privileges to role ${BENCH_ROLE}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -f ${PWD}/GrantTablePrivileges.sql
fi

#log_time "Set search_path for database gpadmin"
#psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -c "${SetSearchPath}"

print_log

echo "Finished ${step}"
log_time "Step ${step} finished"
printf "\n"