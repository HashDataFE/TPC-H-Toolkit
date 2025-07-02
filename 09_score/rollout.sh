#!/bin/bash
set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})

step="score"

log_time "Step ${step} started"
printf "\n"

init_log ${step}

LOAD_TIME=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from tpch_reports.load where tuples > 0")
ANALYZE_TIME=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from tpch_reports.sql where tuples = -1")
QUERIES_TIME=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from (SELECT split_part(description, '.', 2) AS id, min(duration) AS duration FROM tpch_reports.sql where tuples >= 0 GROUP BY split_part(description, '.', 2)) as sub")
CONCURRENT_QUERY_TIME=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "select round(sum(extract('epoch' from duration))) from tpch_testing.sql")
THROUGHPUT_ELAPSED_TIME=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "select max(end_epoch_seconds) - min(start_epoch_seconds) from tpch_testing.sql")

S_Q=${MULTI_USER_COUNT}
SF=${GEN_DATA_SCALE}

# Remove legacy score calculation sections (v1.3.1 and v2.2.0)

# Add v3.0.1 score calculations per TPC-H specification
# 1. Calculate Power metric (single stream performance)
# Formula: Power@Size = (22 * SF) / (Query Execution Time in hours)
POWER=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "select cast(22 as decimal) * cast(${SF} as decimal) / (cast(${QUERIES_TIME} as decimal)/3600.0)")

# 2. Calculate Throughput metric (multi-stream performance)
# Formula: Throughput@Size = (S * 22 * 3600) / Ts
# Where: S = number of query streams, Ts = throughput test elapsed time in seconds
THROUGHPUT=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "select cast(${S_Q} as decimal) * 22 * 3600.0 / cast(${THROUGHPUT_ELAPSED_TIME} as decimal)")

# 3. Calculate composite QphH@Size metric
# Formula: QphH@Size = sqrt(Power@Size * Throughput@Size)
QPHH=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "select sqrt(cast(${POWER} as decimal) * cast(${THROUGHPUT} as decimal))")

# 4. Calculate Price/Performance metric
# Formula: $/kQphH@Size = (1000 * Total System Price) / QphH@Size
# Note: TOTAL_PRICE should be set as an environment variable with system cost
PRICE_PER_KQPHH=$(psql -v ON_ERROR_STOP=1 -q -t -A -c "select 1000 * cast(${TOTAL_PRICE} as decimal) / cast(${QPHH} as decimal)")

printf "TPC-H v3.0.1 Performance Metrics\n"
printf "====================================\n"
printf "Power@%dGB\t\t%.1f QphH\n" ${SF} ${POWER}
printf "Throughput@%dGB\t%.1f QphH\n" ${SF} ${THROUGHPUT}
printf "QphH@%dGB\t\t%.1f QphH\n" ${SF} ${QPHH}
printf "Price/kQphH@%dGB\t$%.2f\n" ${SF} ${PRICE_PER_KQPHH}
printf "\n"
printf "Number of Streams (Sq)\t%d\n" "${S_Q}"
printf "Scale Factor (SF)\t%d\n" "${SF}"
printf "Load\t\t\t%d\n" "${LOAD_TIME}"
printf "Analyze\t\t\t%d\n" "${ANALYZE_TIME}"
printf "1 User Queries\t\t%d\n" "${QUERIES_TIME}"
printf "Concurrent Queries\t%d\n" "${CONCURRENT_QUERY_TIME}"
printf "Throughput Test Elapsed Time\t%d\n" "${THROUGHPUT_ELAPSED_TIME}"
printf "\n"

echo "Finished ${step}"

log_time "Step ${step} finished"
printf "\n"
