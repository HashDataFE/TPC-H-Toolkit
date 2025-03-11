# Decision Support Benchmark for HashData database.

This tool is based on the benchmark tool [TPC-H](https://www.tpc.org/tpch/default5.asp).
This repo contains automation of running the TPC-H benchmark on an existing Hashdata cluster.

## Context


### Supported TPC-H Versions

TPC has published the following TPC-H standards over time:
| TPC-H Benchmark Version | Published Date | Standard Specification |
|-|-|-|
| 3.0.0 (latest) | 2021/02/18 | https://tpc.org/TPC_Documents_Current_Versions/pdf/tpc-h_v3.0.0.pdf|


## Setup
### Prerequisites

1. A running HashData Database with `gpadmin` access
2. `gpadmin` database is created
3. `root` access on the master node `mdw` for installing dependencies
4. `ssh` connections between `mdw` and the segment nodes `sdw1..n`

All the following examples are using standard host name convention of HashData using `mdw` for master node, and `sdw1..n` for the segment nodes.

### TPC-H Tools Dependencies

Make sure that gcc and make are intalled on `mdw` for compiling the `dbgen` (data generation) and `qgen` (query generation).

You can install the dependencies on `mdw`:

```bash
ssh root@mdw
yum -y install gcc make
```

The original source code is from http://tpc.org/tpc_documents_current_versions/current_specifications5.asp.

### Download and Install

You can get released version from the .tar file:

```
curl -LO  https://github.com/hashdata-xyz/TPC-H-HashData/archive/refs/tags/v1.4.tar.gz
tar xzf v1.4.tar.gz
mv TPC-H-HashData-1.4 TPC-H-HashData
```

OR get the current version by downloading with git:

```bash
ssh gpadmin@mdw
git clone https://github.com/hashdata-xyz/TPC-H-HashData.git
```

Put the folder under /home/gpadmin/ and change owner to gpadmin.

```
chown -R gpadmin.gpadmin TPC-H-HashData
```


### Execution

To run the benchmark, login as `gpadmin` on `mdw`:

```
ssh gpadmin@mdw
cd ~/TPC-H-HashData
./tpch.sh
```

Or running the benchmark as a background process:

```bash
sh run.sh
```

By default, it will run a scale 1 (1G) and with 2 concurrent users, from data generation to score computation.

### Configuration Options

By changing the `tpch_variables.sh`, we can control how this benchmark will run.

This is the default example at [tpch_variables.sh](https://github.com/RyanWei/TPC-H-HashData/blob/main/tpch_variables.sh)

```shell
# environment options
ADMIN_USER="gpadmin"
BENCH_ROLE="hbench"
SCHEMA_NAME="tpch"
GREENPLUM_PATH=$GPHOME/greenplum_path.sh
CHIP_TYPE="arm"

# benchmark options
GEN_DATA_SCALE="1"
MULTI_USER_COUNT="2"

# step options
RUN_COMPILE_tpch="true"
RUN_GEN_DATA="true"
RUN_INIT="true"
RUN_DDL="true"
RUN_LOAD="true"
RUN_SQL="true"
RUN_SINGLE_USER_REPORTS="true"
RUN_MULTI_USER="true"
RUN_MULTI_USER_REPORTS="true"
RUN_SCORE="true"

# misc options
SINGLE_USER_ITERATIONS="1"
EXPLAIN_ANALYZE="false"
RANDOM_DISTRIBUTION="false"
ORCA_OPTIMIZER="true"
STATEMENT_MEM="2GB"
STATEMENT_MEM_MULTI_USER='1GB'
```

`tpch.sh` will validate existence of those variables.

#### Environment Options

```shell
# environment options
ADMIN_USER="gpadmin"
ADMIN_USER="gpadmin"
BENCH_ROLE="hbench"
SCHEMA_NAME="tpch"
GREENPLUM_PATH=$GPHOME/greenplum_path.sh
CHIP_TYPE="arm"
```

These are the setup related variables:
- `ADMIN_USER`: default `gpadmin`.
  It is the default database administrator account, as well as the user accessible to all `mdw` and `sdw1..n` machines.
- `CHIP_TYPE`: default `arm`, can be set to `x86`. 
  Set this according to the CPU type of the machince running this test. If included binaries works, compiling will be skipped, otherwise, will try to compile from source code. 
  
  Included binaries: x86 on Centos7 and ARM on Centos7.

  Note: The benchmark related files for each segment node are located in the segment's `${PGDATA}/hbenchmark` directory.
  If there isn't enough space in this directory in each segment, you can create a symbolic link to a drive location that does have enough space.

In most cases, we just leave them to the default.

#### Benchmark Options

```shell
# benchmark options
GEN_DATA_SCALE="1"
MULTI_USER_COUNT="2"
```

These are the benchmark controlling variables:
- `GEN_DATA_SCALE`: default `1`.
  Scale 1 is 1G.
- `MULTI_USER_COUNT`: default `2`.
  It's also usually referred as `CU`, i.e. concurrent user.
  It controls how many concurrent streams to run during the throughput run.


If evaluating Greenplum cluster across different platforms, we recommend to change this section to 3TB with 5CU:
```shell
# benchmark options
MULTI_USER_COUNT="5"
GEN_DATA_SCALE="3000"
```
#### Step Options

```shell
# step options
RUN_COMPILE_tpch="true"
RUN_GEN_DATA="true"
RUN_INIT="true"
RUN_DDL="true"
RUN_LOAD="true"
RUN_SQL="true"
RUN_SINGLE_USER_REPORT="true"
RUN_MULTI_USER="true"
RUN_MULTI_USER_REPORTS="true"
RUN_SCORE="true"
```

There are multiple steps running the benchmark and controlled by these variables:
- `RUN_COMPILE_tpch`: default `true`.
  It will compile the `dbgen` and `qgen`.
  Usually we only want to compile those binaries once.
  In the rerun, just set this value to `false`.
- `RUN_GEN_DATA`: default `true`.
  It will use the `dbgen` compiled above to generate the flat files for the benchmark.
  The flat files are generated in parallel on all segment nodes.
  Those files are stored under `${PGDATA}/hbenchmark` directory.
  In the rerun, just set this value to `false`.
- `RUN_INIT`: default `true`.
  It will setup the GUCs for the Greenplum as well as remember the segment configurations.
  It's only required if the Greenplum cluster is reconfigured.
  It can be always `true` to ensure proper Greenplum cluster configuration.
  In the rerun, just set this value to `false`.
- `RUN_DDL`: default `true`.
  It will recreate all the schemas and tables (including external tables for loading).
  If you want to keep the data and just rerun the queries, please set this value to `false`, otherwise all the existing loaded data will be gone.
- `RUN_LOAD`: default `true`.
  It will load data from flat files into tables.
  After the load, the statistics will be computed in this step.
  If you just want to rerun the queries, please set this value to `false`.
- `RUN_SQL`: default `true`.
  It will run the power test of the benchmark.
- `RUN_SINGLE_USER_REPORTS`: default `true`.
  It will upload the results to the Greenplum database `gpadmin` under schema `tpch_reports`.
  These tables are required later on in the `RUN_SCORE` step.
  Recommend to keep it `true` if above step of `RUN_SQL` is `true`.
- `RUN_MULTI_USER`: default `true`.
  It will run the throughput run of the benchmark.
  Before running the queries, multiple streams will be generated by the `qgen`.
  `qgen` will sample the database to find proper filters.
  For very large database and a lot of streams, this process can take a long time (hours) to just generate the queries.
- `RUN_MULTI_USER_REPORTS`: default `true`.
  It will upload the results to the Greenplum database `gpadmin` under schema `tpch_reports`.
  Recommend to keep it `true` if above step of `RUN_MULTI_USER` is `true`.
- `RUN_SCORE`: default `true`.
  Run this step will print summary for this execution.
  todo: It will query the results from `tpch_reports` and compute the `QphDS` based on supported benchmark standard.
  This function is not supported in the current version as this tool currently only support query tests not refresh functions yet. 


If any above variable is missing or invalid, the script will abort and show the missing or invalid variable name.

**WARNING**: Now TPC-H does not rely on the log folder to run or skip the steps. It will only run the steps that are specified explicitly as `true`  in the `tpch_variables.sh`. If any necessary step is speficied as `false` but has never been executed before, the script will abort when it tries to access something that does not exist in the database or under the directory.

#### Miscellaneous Options

```shell
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
```

These are miscellaneous controlling variables:
- `EXPLAIN_ANALYZE`: default `false`.
  If you set to `true`, you can have the queries execute with `EXPLAIN ANALYZE` in order to see exactly the query plan used, the cost, the memory used, etc.
  This option is for debugging purpose only, since collecting those query statistics will disturb the benchmark.
- `RANDOM_DISTRIBUTION`: default `false`.
  If you set to `true`, the fact tables are distributed randomly other than following a pre-defined distribution column.
- `SINGLE_USER_ITERATION`: default `1`.
  This controls how many times the power test will run.
  During the final score computation, the minimal/fastest query elapsed time of multiple runs will be used.
  This can be used to ensure the power test is in a `warm` run environment.
- `STATEMENT_MEM`: default 2GB which set the `statement_mem` parameter for each statement of single user test. Set with `GB` or `MB`. STATEMENT_MEM should be less than gp_vmem_protect_limit.
- `STATEMENT_MEM_MULTI_USER`: default 1GB which set the `statement_mem` parameter for each statement of multiple user test. Set with `GB` or `MB`. Please note that, `STATEMENT_MEM_MULTI_USER` * `MULTI_USER_COUNT` should be less than `gp_vmem_protect_limit`.
- `ENABLE_VECTORIZATION`: set to true to enable vectorization computing for better performance. Feature is suppported as of Lightning 1.5.3. Default is false. Only works for AO with column and PAX table type.


#### Storage Options

Table storage options are defined with following controlling variables for optimal performance.
```shell
# Storage options
## Set to heap/ao_row/ao_column/pax for different table format
export TABLE_ACCESS_METHOD="ao_column"
## Set different storage options for each access method
export TABLE_STORAGE_OPTIONS="appendoptimized=true compresstype=zstd, compresslevel=5, blocksize=1048576"
```
- `TABLE_ACCESS_METHOD`: define the table type for the test, available options are HEAP, AO with row, AO with column and PAX (supported as of Lightning 1.5.3).  
- `TABLE_STORAGE_OPTIONS`: more storage configurations could be defiend, options are different for each table type, refer to docuemntation for more detail.

Table distribution keys are defined in `../03_ddl/distribution.txt`, you can modify tables' distribution keys by changing this file. You can set the distribution method to hash with colunm names or "REPLICATED".

#### Play with different options
- Change different storage options in `functions.sh` to try with different compress options and whether use AO/CO storage.
- Replace some of the tables' DDL with the `*.sql.partition` files in folder `03_ddl` to use partition for some of the non-dimension tables. No partition is used by default.
- Steps `RUN_COMPILE_tpch` and `RUN_GEN_DATA` only need to be executed once. 
- ORCA optimizer can be adjusted by changing the file `../TPC-H-Hashdata/01_gen_data/optimizer.txt`. You can turn ORCA `on` or `off` for all 22 queries by changing appropriate row of this file.


## Benchmark Minor Modifications

### Change to SQL queries that subtracted or added days were modified slightly:

1. Query alternative 15 was used in favor of the original so it is easier to parse in
these scripts.  Performance is essentially the same for both versions.
2. Query 1 documentation doesn't match query provided by TPC.  Range is supposed to be
dynamically set between 60 and 120 days and substitution doesn't seem to be working
with qgen.  So, hard code 90 days until this can be fixed by TPC.
