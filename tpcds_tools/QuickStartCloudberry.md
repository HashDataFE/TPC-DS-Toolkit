Prerequisites
When running test from master for HashData SynxDB 4（Recommend testing on the master node）
1. Configure environment variables for the gpadmin administrator account (recommended to perform testing using gpadmin user)
2. Since using direct psql login, it's advised to create a gpadmin database
When running test from remote client host for HashData SynxDB 4
1. psql clinet installed with passwordless access for remote cluster (.pgpass setup properly)
2. gpadmin database is created
All the following examples are using standard host name convention of HashData using mdw for master node, and sdw1..n for the segment nodes.
Introduction to TPC-DS
TPC-DS Tool Execution Process:
1.Compile TPC-DS tools
    Build the benchmark toolkit from source code
2.Generate test data
    Create datasets using dsdgen based on specified scale factor
3.Initialize cluster
    Provision and configure the database cluster environment
4.Initialize database objects
    Create schemas, tables, and indexes required for TPC-DS
5.Load data
    Import generated datasets into the database (ETL process)
6.Execute test SQLs
    Run the 99 analytical queries defined in TPC-DS specification
7.Single user reports
    Execute all queries sequentially to measure single-threaded performance
8.Multi user concurrency mode
    Simulate multiple users executing queries simultaneously to test system throughput under high load
9.Multi user reports
    Execute queries concurrently to measure system throughput capacity
10.Final score
    Comprehensive performance metric combining power and throughput tests
Download and Install
Download
Navigate to the web address and download the installation package.
https://github.com/cloudberry-contrib/TPC-DS-Toolkit/archive/refs/tags/v1.0.zip
Or use the following compressed package
暂时无法在飞书文档外展示此内容
Put the folder under /home/gpadmin/ and change owner to gpadmin.
unzip TPC-DS-Toolkit-1.0.zip
mv TPC-DS-Toolkit-1.0 /home/gpadmin/
chown -R gpadmin.gpadmin TPC-DS-Toolkit-1.0
Initialize configuration files and modify cluster parameters.
Modify cluster parameters
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.0/tpcds_tools
vim tpcds_set_gucs.sh

#!/usr/bin/env bash
#gpconfig -c gp_resource_manager -v group
#gpconfig -c gp_resource_group_memory_limit -v 0.9
#gpconfig -c gp_resgroup_memory_policy -v auto
#gpconfig -c gp_workfile_compression -v off

gpconfig -c runaway_detector_activation_percent -v 100
gpconfig -c optimizer_enable_associativity -v on

gpconfig -c gp_interconnect_queue_depth -v 16
gpconfig -c gp_interconnect_snd_queue_depth -v 16

#gp_vmem_protect_limit setting: For example: a host with 128GB memory and eight segments, 
the recommended parameter value is 16GB.
gpconfig -c gp_vmem_protect_limit -v 16384

#max_statement_mem setting: For example: a host with 128GB memory and eight segments, 
the recommended parameter value is 16GB.
gpconfig -c max_statement_mem -v 16384000
#gpconfig -c statement_mem -v 15GB

gpconfig -c work_mem -v 512000

gpconfig -c gp_fts_probe_timeout -v 300
gpconfig -c gp_fts_probe_interval -v 300
gpconfig -c gp_segment_connect_timeout -m 1800 -v 1800

gpconfig -c gp_autostats_mode -v 'none'
gpconfig -c autovacuum -v off
gpconfig -c max_connections -m 100 -v 500
gpconfig -c max_prepared_transactions -v 100


# the following for mirrorless configuration only
# gpconfig -c gp_dispatch_keepalives_idle -v 20
# gpconfig -c gp_dispatch_keepalives_interval -v 20
# gpconfig -c gp_dispatch_keepalives_count -v 44

gpconfig -c gp_enable_runtime_filter_pushdown -v on
#psql ${PSQL_OPTIONS} -f set_resource_group.sql template1

Execute the following command to make the parameters take effect.
sh tpcds_set_gucs.sh
gpstop -afr
Modify the configuration file
Before running tests, we need to check the configuration file and modify the corresponding parameter values as needed.
Parameters requiring modification.
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.0
vim tpcds_variables.sh

## Line 25: GEN_DATA_SCALE set to 1000, indicating generation of 1000GB test data
export GEN_DATA_SCALE="1000"

## Line 90: Sets memory per statement for single-user tests (This parameter should be set marginally lower than MAX_STATEMENT_MEM.Given MAX_STATEMENT_MEM=16GB, STATEMENT_MEM can be configured as 15GB.)
export STATEMENT_MEM="15GB"

Parameters requiring inspection.
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.0
vim tpcds_variables.sh

## Line 7: RUN_MODEL Set to "local" to run the benchmark on the COORDINATOR host or "cloud" to run the benchmark from a remote client.Recommend setting it to "local"
Moreover, their data loading approaches differ:  
In **cloud** mode (for HashData Enterprise 4X):  
  Data is generated locally on the master node and loaded using the `COPY` command.  
In **local** mode: 
  Data splits are generated distributively across segments and loaded via `gpfdist` - delivering superior throughput performance. 
export RUN_MODEL="local"

##Line 39: Generates flat files for the benchmark in parallel on all segment nodes. Files are stored under the `${PGDATA}/dsbenchmark` directory
export RUN_GEN_DATA="true"
export GEN_NEW_DATA="true"

## Line 50: Recreates all schemas and tables (including external tables for loading). Set to `false` to keep existing data.
export RUN_DDL="true"
export DROP_EXISTING_TABLES="true"

## Line 54: Loads data from flat files into tables and computes statistics.
export RUN_LOAD="true"

## Line 82: If we need to calculate the composite score, set RUN_SCORE to true; otherwise, leave it at the default value false
 export RUN_SCORE="false"

## Line 87: When set to `true`, fact tables are distributed randomly rather than using pre-defined distribution columns. Recommended for HashData Enterprise 4X.while synxdb remains the default value false.
export RANDOM_DISTRIBUTION="false"

Parameters requiring modification in parallel execution.
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.0
vim tpcds_variables.sh

## Line 26: Number of concurrent users during throughput tests
export MULTI_USER_COUNT="5"

## Line 59: Runs the power test of the benchmark,During parallel execution,RUN_SQL must be set to "false".
export RUN_SQL="false"

## Line 72: Uploads results to the database under the schema `tpcds_reports`. Required for the `RUN_SCORE` step. During parallel execution, RUN_SINGLE_USER_REPORTS can be set to "false".
export RUN_SINGLE_USER_REPORTS="false"

## Line 75: Runs the throughput test of the benchmark. This generates multiple query streams using `dsqgen`, which samples the database to find proper filters. For very large databases with many streams, this process can take hours just to generate the queries.
export RUN_MULTI_USER="true"

## Line 79: Uploads multi-user results to the database
export RUN_MULTI_USER_REPORTS="true"
If repeating SQL tests, the following parameters should be set to false
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.0
vim tpcds_variables.sh

## Line 39: Generates flat files for the benchmark in parallel on all segment nodes. Files are stored under the `${PGDATA}/dsbenchmark` directory
export RUN_GEN_DATA="false"
export GEN_NEW_DATA="false"

## Line 43: Sets up GUCs for the database and records segment configurations. Only required if the cluster is reconfigured
export RUN_INIT="false"

## Line 50: Recreates all schemas and tables (including external tables for loading). Set to `false` to keep existing data.
export RUN_DDL="false"
export DROP_EXISTING_TABLES="false"

## Line 54: Loads data from flat files into tables and computes statistics
export RUN_LOAD="false"
For information on other parameters, please refer to the README.md file.
暂时无法在飞书文档外展示此内容
Usage
To run the benchmark, login as gpadmin on mdw:
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.0
./run.sh
