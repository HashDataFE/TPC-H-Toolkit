#!/bin/bash
set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})
step="multi_user_reports"

init_log ${step}

log_time "Step ${step} started"
printf "\n"

get_version
filter="gpdb"

for i in ${PWD}/*.${filter}.*.sql; do
	log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${i}"
	psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${i}
	echo ""
done

filename=$(ls ${PWD}/*.copy.*.sql)

for i in ${TPC_H_DIR}/log/rollout_testing_*; do
	logfile="'${i}'"
	log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${filename} -v LOGFILE=\"${logfile}\""
	psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${filename} -v LOGFILE="${logfile}"
done

psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -c "select 'analyze ' || n.nspname || '.' || c.relname || ';' from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'tpch_testing'" | psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -e

psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/detailed_report.sql
echo ""

echo "Finished ${step}"

log_time "Step ${step} finished"
printf "\n"
