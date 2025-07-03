# environment options
export ADMIN_USER="gpadmin"
export BENCH_ROLE="hbench"
export DB_SCHEMA_NAME="tpch"

## Set to "local" to run the benchmark on the COORDINATOR host or "cloud" to run the benchmark from a remote client.
export RUN_MODEL="local"

## Default port is configured via the env setting of $PGPORT for user $ADMIN_USER
## Configure the host/port/user to connect to the cluster running the test. Can be left empty when running in local mode with gpadmin.
export PSQL_OPTIONS="-h 2f445c57-c838-4038-a410-50ee36f9461d.cloud.hashdata.ai -p 5432"

## The following variables only take effect when RUN_MODEL is set to "cloud".
### Default path to store the generated benchmark data
export CLIENT_GEN_PATH="/tmp/dsbenchmark"
### How many parallel processes to run on the client to generate data
export CLIENT_GEN_PARALLEL="2"

## The following variables only take effect when RUN_MODEL is set to "local".
### How many parallel processes to run on each segment to generate data in local mode
export LOCAL_GEN_PARALLEL="1"

# benchmark options
export GEN_DATA_SCALE="1"
export MULTI_USER_COUNT="2"

# step options
# step 00_compile_tpch
export RUN_COMPILE_TPCH="true"

# step 01_gen_data
# To run another TPC-H with a different BENCH_ROLE using existing tables and data
# the queries need to be regenerated with the new role
# change BENCH_ROLE and set RUN_GEN_DATA to true and GEN_NEW_DATA to false
# GEN_NEW_DATA only takes affect when RUN_GEN_DATA is true, and the default setting
# should true under normal circumstances
export RUN_GEN_DATA="true"
export GEN_NEW_DATA="true"

# step 02_init
export RUN_INIT="true"

# step 03_ddl
# To run another TPC-H with a different BENCH_ROLE using existing tables and data
# change BENCH_ROLE and set RUN_DDL to true and DROP_EXISTING_TABLES to false
# DROP_EXISTING_TABLES only takes affect when RUN_DDL is true, and the default setting
# should true under normal circumstances
export RUN_DDL="true"
export DROP_EXISTING_TABLES="true"

# step 04_load
export RUN_LOAD="true"
### How many parallel processes to load data, default is 2, max is 24.
export LOAD_PARALLEL="2"


# step 05_sql
export RUN_SQL="true"
export RUN_ANALYZE="true"
export RUN_ANALYZE_PARALLEL="5"
## Set to true to generate queries for the TPC-DS benchmark.
export RUN_QGEN="true"
#set wait time between each query execution
export QUERY_INTERVAL="0"
#Set to 1 if you want to stop when error occurs
export ON_ERROR_STOP="0"

# step 06_single_user_reports
export RUN_SINGLE_USER_REPORTS="true"

# step 07_multi_user
export RUN_MULTI_USER="false"
export RUN_MULTI_USER_QGEN="true"

# step 08_multi_user_reports
export RUN_MULTI_USER_REPORTS="false"

# step 09_score
export RUN_SCORE="false"

# Misc options
export SINGLE_USER_ITERATIONS="1"
export EXPLAIN_ANALYZE="false"
export ENABLE_VECTORIZATION="off"
export RANDOM_DISTRIBUTION="false"
export STATEMENT_MEM="1.9GB"
export STATEMENT_MEM_MULTI_USER="1GB"
## Set gpfdist location where gpfdist will run p (primary) or m (mirror)
export GPFDIST_LOCATION="p"
export OSVERSION=$(uname)
export ADMIN_USER=$(whoami)
export ADMIN_HOME=$(eval echo ${HOME}/${ADMIN_USER})
export MASTER_HOST=$(hostname -s)
export DB_SCHEMA_NAME="$(echo "${DB_SCHEMA_NAME}" | tr '[:upper:]' '[:lower:]')"

# Storage options
## Support TABLE_ACCESS_METHOD as ao_row / ao_column / heap in both GPDB 7 / CBDB
## Support TABLE_ACCESS_METHOD as "PAX" for PAX table format and remove blocksize option in TABLE_STORAGE_OPTIONS for CBDB 2.0 only.
## TABLE_ACCESS_METHOD only works for Cloudberry and Greenplum 7.0 or later.
# export TABLE_ACCESS_METHOD="USING ao_column"
## Set different storage options for each access method
## Set to use partition for the following tables:
## catalog_returns / catalog_sales / inventory / store_returns / store_sales / web_returns / web_sales
# export TABLE_USE_PARTITION="true"
## SET TABLE_STORAGE_OPTIONS with different options in GP/CBDB/Cloud "appendoptimized=true, orientation=column, compresstype=zstd, compresslevel=5, blocksize=1048576"
export TABLE_STORAGE_OPTIONS="WITH (appendonly=true, orientation=column, compresstype=zstd, compresslevel=5, blocksize=1048576)"

