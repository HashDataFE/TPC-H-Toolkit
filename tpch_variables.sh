# environment options
export ADMIN_USER="gpadmin"
export BENCH_ROLE="hbench"
export SCHEMA_NAME="tpch"
export GREENPLUM_PATH=$GPHOME/greenplum_path.sh
export CHIP_TYPE="x86"

# to connect directly to GP
export PSQL_OPTIONS="-p 5432"
# to connect through pgbouncer
#export PSQL_OPTIONS="-p 6543 -U dsbench"

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
# set this to true if binary location changed
export RESET_ENV_ON_SEGMENT='false'

# step 03_ddl
# To run another TPC-H with a different BENCH_ROLE using existing tables and data
# change BENCH_ROLE and set RUN_DDL to true and DROP_EXISTING_TABLES to false
# DROP_EXISTING_TABLES only takes affect when RUN_DDL is true, and the default setting
# should true under normal circumstances
export RUN_DDL="true"
export DROP_EXISTING_TABLES="true"

# step 04_load
export RUN_LOAD="true"

# step 05_sql
export RUN_SQL="true"
export RUN_ANALYZE="true"
#set wait time between each query execution
export QUERY_INTERVAL="0"
#Set to 1 if you want to stop when error occurs
export ON_ERROR_STOP="0"

# step 06_single_user_reports
export RUN_SINGLE_USER_REPORTS="true"

# step 07_multi_user
export RUN_MULTI_USER="false"
export RUN_QGEN="true"

# step 08_multi_user_reports
export RUN_MULTI_USER_REPORTS="false"

# step 09_score
export RUN_SCORE="false"

# Misc options
export SINGLE_USER_ITERATIONS="1"
export EXPLAIN_ANALYZE="false"
export ENABLE_VECTORIZATION="off"
export RANDOM_DISTRIBUTION="false"
export STATEMENT_MEM="2GB"
export STATEMENT_MEM_MULTI_USER="1GB"
## Set gpfdist location where gpfdist will run p (primary) or m (mirror)
export GPFDIST_LOCATION="p"
export OSVERSION=$(uname)
export ADMIN_USER=$(whoami)
export ADMIN_HOME=$(eval echo ${HOME}/${ADMIN_USER})
export MASTER_HOST=$(hostname -s)
export LD_PRELOAD=/lib64/libz.so.1 ps

# Storage options
## Set to ”USING PAX“ for PAX table format and remove blocksize option in TABLE_STORAGE_OPTIONS. 
## Supported in Lightning only.
#export TABLE_ACCESS_METHOD="USING PAX"

## Set different storage options for each access method
export TABLE_STORAGE_OPTIONS="appendonly=true, orientation=column, compresstype=zstd, compresslevel=5, blocksize=1048576"
