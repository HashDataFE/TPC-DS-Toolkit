# Decision Support Benchmark for HashData Database

[![TPC-DS](https://img.shields.io/badge/TPC--DS-v3.2.0-blue)](http://www.tpc.org/tpcds/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

A comprehensive tool for running TPC-DS benchmarks on Cloudberry / HashData / Greenplum clusters. Originally from [Pivotal TPC-DS](https://github.com/pivotal/TPC-DS).

## Overview

This tool provides:
- Automated TPC-DS benchmark execution
- Support for both local and cloud deployments
- Configurable data generation (1GB to 100TB)
- Customizable query execution parameters
- Detailed performance reporting

## Table of Contents
- [Quick Start](#quick-start)
- [Supported TPC-DS Versions](#supported-tpc-ds-versions)
- [Prerequisites](#prerequisites) 
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Performance Tuning](#performance-tuning)
- [Benchmark Modifications](#benchmark-modifications)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Quick Start

```bash
# 1. Clone the repository
git clone git@github.com:HashDataFE/TPC-DS-CBDB.git
cd TPC-DS-CBDB

# 2. Configure your environment
cp tpcds_variables.sh.template tpcds_variables.sh
vim tpcds_variables.sh

# 3. Run the benchmark
./run.sh
```

## Supported TPC-DS Versions

| Version | Date | Specification |
|---------|------|---------------|
| 3.2.0 | 2021/06/15 | [PDF](http://www.tpc.org/tpc_documents_current_versions/pdf/tpc-ds_v3.2.0.pdf) |
| 2.1.0 | 2015/11/12 | [PDF](http://www.tpc.org/tpc_documents_current_versions/pdf/tpc-ds_v2.1.0.pdf) |
| 1.3.1 | 2015/02/19 | [PDF](http://www.tpc.org/tpc_documents_current_versions/pdf/tpc-ds_v1.3.1.pdf) |

This tool uses TPC-DS 3.2.0 as of version 1.2.

## Prerequisites
This tool is build with shell scripts and only tested on CentOS based Operaing Systems.
To adapted with different products, there are many options available to choose storage type /  partitions / optimizer / distribution policies etc, please review the tpcds_variables.sh for more detail configuration options for different models and products.
Tested products:
Cloudberry 1.x / Cloudberry 2.X
Hashdata Enterprise / HashData Lightning 
Greenplum 4.x / Greenplum 5.x / Greenplum 6.x / Greenplum 7.x


### Local Cluster Setup
For running tests on the coordinator host:
This mode will leverage the MPP architeture to use data directories of segment nodes to generate data and load data with 'gpfdist' protocol.
More resources will be used for data generating and loading to accerlarate the test process.

1. Set `RUN_MODEL="local"` in `tpcds_variables.sh`
2. Ensure running HashData Database with `gpadmin` access
3. Create `gpadmin` database
4. Configure password-less `ssh` between `mdw` and segment nodes (`sdw1..n`)

### Remote Client Setup  
For running tests from a remote client:
With this mode, all data will be generated on the clients, data will be imported into database with `copy` command.
This mode works for HashData cloud / Cloudberry / Greenpplum / HashData lightning and should work for other Postgresql compatible products, however, it is recommended to use `local` mode for non-Cloud MPP products.

1. Set `RUN_MODEL="cloud"` in `tpcds_variables.sh`
2. Install `psql` client with passwordless access (`.pgpass`)
3. Create `gpadmin` database with:
   ```sql
   ALTER ROLE gpadmin SET warehouse=testforcloud;
   ```
4. Configure required variables in tpcds_variables.sh and follow the instructions.
   ```bash
   export RANDOM_DISTRIBUTION="true"
   export TABLE_STORAGE_OPTIONS="compresstype=zstd, compresslevel=5"
   export CLIENT_GEN_PATH="/tmp/dsbenchmark" 
   export CLIENT_GEN_PARALLEL="2"
   ```

All the following examples are using standard host name convention of HashData using `mdw` for master node, and `sdw1..n` for the segment nodes.

### TPC-DS Tools Dependencies

Install the dependencies on `mdw` for compiling the `dsdgen` (data generation) and `dsqgen` (query generation).

```bash
ssh root@mdw
yum -y install gcc make byacc
```

The original source code is from http://tpc.org/tpc_documents_current_versions/current_specifications5.asp.

## Installation

Just clone the repo with GIT or download source code from github.

```bash
ssh gpadmin@mdw
git clone git@github.com:HashDataFE/TPC-DS-CBDB.git
```
Put the folder under /home/gpadmin/ and change owner to gpadmin.

```bash
chown -R gpadmin.gpadmin TPC-DS-HashData
```

## Usage

To run the benchmark, login as `gpadmin` on `mdw`:

```bash
ssh gpadmin@mdw
cd ~/TPC-DS-HashData
./run.sh
```

By default, it will run a scale 1 (1G) and with 1 concurrent users from data generation to score computation in the background.
Log will be stored with name `tpcds_<time_stamp>.log` in ~/TPC-DS-HashData.

## Configuration

The benchmark is controlled through `tpcds_variables.sh`. Key configuration sections:

### Environment Options
```bash
# Core settings
export ADMIN_USER="gpadmin"
export BENCH_ROLE="dsbench" 
export SCHEMA_NAME="tpcds"
export CHIP_TYPE="x86"      # arm or x86
export RUN_MODEL="cloud"    # local or cloud

# Remote cluster connection
export PSQL_OPTIONS="-h <host> -p <port>"
export CLIENT_GEN_PATH="/tmp/dsbenchmark"  # Location for data generation
export CLIENT_GEN_PARALLEL="2"             # Number of parallel data generation processes
```

### Benchmark Options
```bash
# Scale and concurrency 
export GEN_DATA_SCALE="1"    # 1 = 1GB, 1000 = 1TB, 3000 = 3TB
export MULTI_USER_COUNT="2"  # Number of concurrent users during throughput tests

# For large scale tests, consider:
# - 3TB: GEN_DATA_SCALE="3000" with MULTI_USER_COUNT="5"
# - 10TB: GEN_DATA_SCALE="10000" with MULTI_USER_COUNT="7"
# - 30TB: GEN_DATA_SCALE="30000" with MULTI_USER_COUNT="10"
```

### Storage Options  
```bash
# Table format and compression options
export TABLE_ACCESS_METHOD="USING ao_column"  # Available options:
                                       # - heap: Classic row storage
                                       # - ao_row: Append-optimized row storage
                                       # - ao_column: Append-optimized columnar storage
                                       # - pax: PAX storage format

export TABLE_STORAGE_OPTIONS="WITH (compresstype=zstd, compresslevel=5)"  # Compression settings:
                                                                         # - zstd: Best compression ratio
                                                                         # - compresslevel: 1-19 (higher=better compression)
```

### Step Control Options
```bash
# Benchmark execution steps
# 1. Setup and compilation
export RUN_COMPILE_TPCDS="true"  # Compile data/query generators (one-time)
export RUN_INIT="true"           # Initialize cluster settings

# 2. Data generation and loading
export RUN_GEN_DATA="true"       # Generate test data
export RUN_DDL="true"            # Create database schemas/tables
export RUN_LOAD="true"           # Load generated data

# 3. Query execution
export RUN_SQL="true"            # Run power test queries
export RUN_SINGLE_USER_REPORTS="true"  # Upload single user test results
export RUN_MULTI_USER="false"    # Run throughput test queries
export RUN_MULTI_USER_REPORTS="false"  # Upload multi-user test results
export RUN_SCORE="false"         # Compute final benchmark score
```

There are multiple steps running the benchmark and controlled by these variables:
- `RUN_COMPILE_TPCDS`: default `true`.
  It will compile the `dsdgen` and `dsqgen`.
  Usually we only want to compile those binaries once.
  In the rerun, just set this value to `false`.
- `RUN_GEN_DATA`: default `true`.
  It will use the `dsdgen` compiled above to generate the flat files for the benchmark.
  The flat files are generated in parallel on all segment nodes.
  Those files are stored under `${PGDATA}/dsbenchmark` directory.
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
  It will upload the results to the Greenplum database `gpadmin` under schema `tpcds_reports`.
  These tables are required later on in the `RUN_SCORE` step.
  Recommend to keep it `true` if above step of `RUN_SQL` is `true`.
- `RUN_MULTI_USER`: default `true`.
  It will run the throughput run of the benchmark.
  Before running the queries, multiple streams will be generated by the `dsqgen`.
  `dsqgen` will sample the database to find proper filters.
  For very large database and a lot of streams, this process can take a long time (hours) to just generate the queries.
- `RUN_MULTI_USER_REPORTS`: default `true`.
  It will upload the results to the Greenplum database `gpadmin` under schema `tpcds_reports`.
  Recommend to keep it `true` if above step of `RUN_MULTI_USER` is `true`.
- `RUN_SCORE`: default `true`.
  It will query the results from `tpcds_reports` and compute the `QphDS` based on supported benchmark standard.
  Recommend to keep it `true` if you want to see the final score of the run.

If any above variable is missing or invalid, the script will abort and show the missing or invalid variable name.

**WARNING**: Now TPC-DS does not rely on the log folder to run or skip the steps. It will only run the steps that are specified explicitly as `true`  in the `tpcds_variables.sh`. If any necessary step is speficied as `false` but has never been executed before, the script will abort when it tries to access something that does not exist in the database or under the directory.

### Miscellaneous Options

```bash
# Misc options
export SINGLE_USER_ITERATIONS="1"
export EXPLAIN_ANALYZE="false"
export RANDOM_DISTRIBUTION="false"
## Set to on/off to enable vectorization
export ENABLE_VECTORIZATION="off"
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
  If you set to `true`, the fact tables are distributed randomly other than following a pre-defined distribution column. Random distribution shold be used for Cloud products. 
  Pre-defined table distribution policies are in: TPC-DS-CBDB/03_ddl/distribution.txt with `REPLICATED` policy supported product, 14 tables are using `REPLICATED` distribution policy by default.  TPC-DS-CBDB/03_ddl/distribution_original.txt are for early Greenplum products without `REPLICATED` policy supported.
- `SINGLE_USER_ITERATION`: default `1`.
  This controls how many times the power test will run.
  During the final score computation, the minimal/fastest query elapsed time of multiple runs will be used.
  This can be used to ensure the power test is in a `warm` run environment.
- `STATEMENT_MEM`: default 2GB which set the `statement_mem` parameter for each statement of single user test. Set with `GB` or `MB`. STATEMENT_MEM should be less than gp_vmem_protect_limit.
- `STATEMENT_MEM_MULTI_USER`: default 1GB which set the `statement_mem` parameter for each statement of multiple user test. Set with `GB` or `MB`. Please note that, `STATEMENT_MEM_MULTI_USER` * `MULTI_USER_COUNT` should be less than `gp_vmem_protect_limit`.
- `ENABLE_VECTORIZATION`: set to true to enable vectorization computing for better performance. Feature is suppported as of Lightning 1.5.3. Default is false. Only works for AO with column and PAX table type.

### Storage Options
```bash
# Storage options
## Support TABLE_ACCESS_METHOD to ao_row / ao_column / heap in both GPDB 7 / CBDB
## Support TABLE_ACCESS_METHOD to ”PAX“ for PAX table format and remove blocksize option in TABLE_STORAGE_OPTIONS for CBDB 2.0 only.
## DO NOT set TABLE_ACCESS_METHOD for Cloud
# export TABLE_ACCESS_METHOD="USING ao_column"
## Set different storage options for each access method
## Set to use partitione for following tables:
## catalog_returns / catalog_sales / inventory / store_returns / store_sales / web_returns / web_sales
# export TABLE_USE_PARTITION="true"
## SET TABLE_STORAGE_OPTIONS wiht different options in GP/CBDB/Cloud "appendoptimized=true compresstype=zstd, compresslevel=5, blocksize=1048576"
export TABLE_STORAGE_OPTIONS="WITH (compresstype=zstd, compresslevel=5)"
```
- `TABLE_ACCESS_METHOD`: Default to non-value to compatible with HashDataCloud and early Greenplum versions, should be set to `USING ao_column` for Cloudbery or Greenplum. `USING PAX` is available for Cloudberry 2.0 and HashData Lightning.
- `TABLE_USE_PARTITION`: Set this to `true` will use table partitions for 7 large tables, this should improve performance for Cloudberry / Greenplum. All table DDL scripts are localed in TPC-DS-CBDB/03_ddl/. Partition table DDL ends with *.sql.partition.
- `TABLE_STORAGE_OPTIONS`: if `TABLE_ACCESS_METHOD` are not supported in early Greenplum products, use full options `appendoptimized=true, orientation=column, compresstype=zlib, compresslevel=5, blocksize=1048576`

## Performance Tuning

For optimal performance:

1. **Memory Settings**
   ```bash
   # Recommended for 100GB+ RAM systems
   export STATEMENT_MEM="8GB"
   export STATEMENT_MEM_MULTI_USER="4GB"
   ```

2. **Storage Optimization**
   ```bash
   # For best compression ratio
   export TABLE_ACCESS_METHOD="USING ao_column"
   export TABLE_STORAGE_OPTIONS="WITH (compresstype=zstd, compresslevel=9)"
   export TABLE_USE_PARTITION="true"

3. **Concurrency Tuning**
   ```bash
   # Adjust based on available CPU cores
   export CLIENT_GEN_PARALLEL="$(nproc)"
   export MULTI_USER_COUNT="$(( $(nproc) / 2 ))"
   ```

## Benchmark Modifications

### 1. Change to SQL queries that subtracted or added days were modified slightly:

Old:
```sql
and (cast('2000-02-28' as date) + 30 days)
```

New:

```sql
and (cast('2000-02-28' as date) + '30 days'::interval)
```

This was done on queries: 5, 12, 16, 20, 21, 32, 37, 40, 77, 80, 82, 92, 94, 95, and 98.

### 2. Change to queries with ORDER BY on column alias to use sub-select.

Old:
```sql
select  
    sum(ss_net_profit) as total_sum
   ,s_state
   ,s_county
   ,grouping(s_state)+grouping(s_county) as lochierarchy
   ,rank() over (
 	partition by grouping(s_state)+grouping(s_county),
 	case when grouping(s_county) = 0 then s_state end 
 	order by sum(ss_net_profit) desc) as rank_within_parent
 from
    store_sales
   ,date_dim       d1
   ,store
 where
    d1.d_month_seq between 1212 and 1212+11
 and d1.d_date_sk = ss_sold_date_sk
 and s_store_sk  = ss_store_sk
 and s_state in
             ( select s_state
               from  (select s_state as s_state,
 			    rank() over ( partition by s_state order by sum(ss_net_profit) desc) as ranking
                      from   store_sales, store, date_dim
                      where  d_month_seq between 1212 and 1212+11
 			    and d_date_sk = ss_sold_date_sk
 			    and s_store_sk  = ss_store_sk
                      group by s_state
                     ) tmp1 
               where ranking <= 5
             )
 group by rollup(s_state,s_county)
 order by
   lochierarchy desc
  ,case when lochierarchy = 0 then s_state end
  ,rank_within_parent
 limit 100;
```

New:
```sql
select * from ( --new
select  
    sum(ss_net_profit) as total_sum
   ,s_state
   ,s_county
   ,grouping(s_state)+grouping(s_county) as lochierarchy
   ,rank() over (
 	partition by grouping(s_state)+grouping(s_county),
 	case when grouping(s_county) = 0 then s_state end 
 	order by sum(ss_net_profit) desc) as rank_within_parent
 from
    store_sales
   ,date_dim       d1
   ,store
 where
    d1.d_month_seq between 1212 and 1212+11
 and d1.d_date_sk = ss_sold_date_sk
 and s_store_sk  = ss_store_sk
 and s_state in
             ( select s_state
               from  (select s_state as s_state,
 			    rank() over ( partition by s_state order by sum(ss_net_profit) desc) as ranking
                      from   store_sales, store, date_dim
                      where  d_month_seq between 1212 and 1212+11
 			    and d_date_sk = ss_sold_date_sk
 			    and s_store_sk  = ss_store_sk
                      group by s_state
                     ) tmp1 
               where ranking <= 5
             )
 group by rollup(s_state,s_county)
) AS sub --new
 order by
   lochierarchy desc
  ,case when lochierarchy = 0 then s_state end
  ,rank_within_parent
 limit 100;
```

This was done on queries: 36 and 70.

### 3. Query templates were modified to exclude columns not found in the query.

In these cases, the common table expression used aliased columns but the dynamic filters included both the alias name as well as the original name.
Referencing the original column name instead of the alias causes the query parser to not find the column.

This was done on query 86.

### 4. Added table aliases.
This was done on queries: 2, 14, and 23.

### 5. Added `limit 100` to very large result set queries.
For the larger tests (e.g. 15TB), a few of the TPC-DS queries can output a very large number of rows which are just discarded.

This was done on queries: 64, 34, and 71.

## Troubleshooting

### Common Issues and Solutions

1. **Missing or Invalid Environment Variables**  
   Ensure all required environment variables in `tpcds_variables.sh` are set correctly. If any variable is missing or invalid, the script will abort and display the problematic variable name. Double-check the following key variables:
   - `RUN_MODEL`
   - `GEN_DATA_SCALE`
   - `TABLE_ACCESS_METHOD`
   - `PSQL_OPTIONS`

2. **Permission Errors**  
   If you encounter permission errors during installation or execution:
   - Verify that the `TPC-DS-HashData` folder is owned by `gpadmin`:
     ```bash
     chown -R gpadmin.gpadmin /home/gpadmin/TPC-DS-HashData
     ```
   - Ensure `gpadmin` has the necessary access to the database and directories.

3. **Data Generation Fails**  
   If data generation fails:
   - Confirm that `dsdgen` is compiled successfully.
   - Check the `CLIENT_GEN_PATH` variable to ensure it points to a valid directory.

4. **Query Execution Errors**  
   If queries fail to execute:
   - Verify that all required tables and schemas are created by ensuring `RUN_DDL` is set to `true` during the initial run.
   - Check for syntax errors in modified queries.

5. **Performance Issues**  
   For performance-related concerns:
   - Adjust `STATEMENT_MEM` and `STATEMENT_MEM_MULTI_USER` based on the available system memory.
   - Enable vectorization by setting `ENABLE_VECTORIZATION="on"` if supported.

### Additional Resources
For further assistance, refer to the [TPC-DS Specification](http://www.tpc.org/tpc_documents_current_versions/pdf/tpc-ds_v3.2.0.pdf) or contact the HashData support team.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
