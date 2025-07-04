#!/bin/bash
set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})

step="single_user_reports"

log_time "Step ${step} started"
printf "\n"

init_log ${step}

SF=${GEN_DATA_SCALE}
report_schema="tpch_reports"
filter="gpdb"

# Process SQL files in numeric order, using absolute paths
for i in $(find "${PWD}" -maxdepth 1 -type f -name "*.${filter}.*.sql" -printf "%f\n" | sort -n); do
  log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f ${PWD}/${i} -v report_schema=${report_schema}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -f "${PWD}/${i}" -v report_schema=${report_schema}
  echo ""
done

# Process copy files in numeric order, using absolute paths
for i in $(find "${PWD}" -maxdepth 1 -type f -name "*.copy.*.sql" -printf "%f\n" | sort -n); do
  logstep=$(echo "${i}" | awk -F 'copy.' '{print $2}' | awk -F '.' '{print $1}')
  logfile="${TPC_H_DIR}/log/rollout_${logstep}.log"
  loadsql="\COPY ${report_schema}.${logstep} FROM '${logfile}' WITH DELIMITER '|';"
  log_time "psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -c \"${loadsql}\""
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -a -c "${loadsql}"
  echo ""
done



log_time "psql ${PSQL_OPTIONS} -t -A -c \"select 'analyze ' ||schemaname||'.'||tablename||';' from pg_tables WHERE schemaname = '${report_schema}';\" |xargs -I {} -P 5 psql ${PSQL_OPTIONS} -a -A -c \"{}\""
psql ${PSQL_OPTIONS} -t -A -c "select 'analyze ' ||schemaname||'.'||tablename||';' from pg_tables WHERE schemaname = '${report_schema}';" |xargs -I {} -P 5 psql ${PSQL_OPTIONS} -a -A -c "{}"

#psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select 'analyze ' || n.nspname || '.' || c.relname || ';' from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = '${report_schema}'" | psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -t -A -e

echo "********************************************************************************"
echo "Generate Data"
echo "********************************************************************************"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/gen_data_report.sql -v report_schema=${report_schema}
echo ""
echo "********************************************************************************"
echo "Data Loads"
echo "********************************************************************************"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/loads_report.sql -v report_schema=${report_schema}
echo ""
echo "********************************************************************************"
echo "Analyze"
echo "********************************************************************************"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/analyze_report.sql -v report_schema=${report_schema}
echo ""
echo ""
echo "********************************************************************************"
echo "Queries"
echo "********************************************************************************"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -P pager=off -f ${PWD}/queries_report.sql -v report_schema=${report_schema}
echo ""

echo "********************************************************************************"
echo "Summary"
echo "********************************************************************************"
echo ""

GEN_TIME=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select round(extract('epoch' from duration)) from ${report_schema}.gen_data")
LOAD_TIME_SERIAL=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from ${report_schema}.load where tuples > 0")
LOAD_TIME_PARALLEL=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "SELECT ROUND(MAX(end_epoch_seconds) - MIN(start_epoch_seconds)) FROM ${report_schema}.load WHERE tuples > 0")
ANALYZE_TIME=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from ${report_schema}.sql where id = 1")
QUERIES_TIME=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from (SELECT split_part(description, '.', 2) AS id, min(duration) AS duration FROM ${report_schema}.sql where tuples >= 0 GROUP BY split_part(description, '.', 2)) as sub")
SUCCESS_QUERY=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select count(*) from ${report_schema}.sql where tuples >= 0")
FAILD_QUERY=$(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -t -A -c "select count(*) from ${report_schema}.sql where tuples < 0 and id > 1")

printf "Scale Factor (SF)\t\t\t%d\n" "${SF}"
printf "Generate Data (seconds)\t\t\t%d\n" "${GEN_TIME}"
printf "Load SERIAL (seconds)\t\t\t%d\n" "${LOAD_TIME_SERIAL}"
printf "Load PARALLEL (seconds)\t\t\t%d\n" "${LOAD_TIME_PARALLEL}"
printf "Analyze (seconds)\t\t\t%d\n" "${ANALYZE_TIME}"
printf "1 User Queries (seconds)\t\t%d\tFor %d success queries and %d failed queries\n" "${QUERIES_TIME}" "${SUCCESS_QUERY}" "${FAILD_QUERY}"
echo ""
echo "********************************************************************************"

echo "Finished ${step}"
log_time "Step ${step} finished"
printf "\n"
