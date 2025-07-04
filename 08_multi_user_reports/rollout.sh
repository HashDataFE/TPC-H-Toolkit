#!/bin/bash
set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})
step="multi_user_reports"

init_log ${step}

log_time "Step ${step} started"
printf "\n"

get_version
filter="gpdb"

# Process SQL files in numeric order with absolute paths
for i in $(find "${PWD}" -maxdepth 1 -type f -name "*.${filter}.*.sql" -printf "%f\n" | sort -n); do
  log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${PWD}/${i}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f "${PWD}/${i}"
  echo ""
done

# Process copy files in numeric order with absolute paths
for i in $(find "${TPC_H_DIR}/log" -maxdepth 1 -type f -name "rollout_testing_*" -printf "%f\n" | sort -n); do
  logfile="${TPC_H_DIR}/log/${i}"
  loadsql="\COPY tpch_testing.sql FROM '${logfile}' WITH DELIMITER '|';"
  log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -c \"${loadsql}\""
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -c "${loadsql}"
  echo ""
done

psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -c "select 'analyze ' || n.nspname || '.' || c.relname || ';' from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'tpch_testing'" | psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -e

psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/detailed_report.sql
echo ""

echo "Finished ${step}"

log_time "Step ${step} finished"
printf "\n"
