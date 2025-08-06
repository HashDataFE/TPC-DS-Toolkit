# TPC-DS Benchmark Toolkit Quick Start Guide for Local

This guide provides step-by-step instructions on how to set up and run the TPC-DS benchmark toolkit on a Cloudberry/Greenplum cluster. It also supports products with similar architectures: HashData Lightning, SynxDB 1.x, SynxDB 2.x, SynxDB 3.x, and SynxDB 4.x

## Prerequisites
When you have access to a cluster coordinator node, running the test in "local" mode is recommended to leverage the MPP architecture for faster data generation and loading.

If you don't have access to a cluster coordinator node, the test can also be executed in "Cloud" mode, where data generation and loading occur on the client host. Please refer to [QuickStartCloud.md](tpcds_tools/QuickStartCloud.md) for more details.

### Running Tests on Coordinator Node
1. Configure environment variables for the database administrator account (e.g., gpadmin, used in this guide).
2. Since we'll use direct psql login, we recommend creating a gpadmin database.

> The following conventions are used in this document: mdw for the coordinator node, and sdw1..n for segment nodes.

## Download and Installation

### Download
Download the toolkit package:
https://github.com/cloudberry-contrib/TPC-DS-Toolkit/archive/refs/tags/v1.3.zip

### Installation
Place the folder in the gpadmin home directory and update ownership:

```bash
unzip TPC-DS-Toolkit-1.3.zip
mv TPC-DS-Toolkit-1.3 /home/gpadmin/
chown -R gpadmin.gpadmin TPC-DS-Toolkit-1.3
```

### Configure database parameters

```bash
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.3/tpcds_tools
vim tpcds_set_gucs.sh
```
Following parameters need to reviewed and adjusted based on your cluster configuration:

```bash
#gp_vmem_protect_limit setting, rule of thumb: segment host got 128GB memory with 8 primary segments deployed, this parameter can be set to 16GB.
gpconfig -c gp_vmem_protect_limit -v 16384
#Same values as gp_vmem_protect_limit
gpconfig -c max_statement_mem -v 16384000
```
Execute the following command to make the parameters take effect.

> Please note that, some parameters might not be supported in earlier versions, some parameters might only be supported in SynxDB 4.x and HashData lightning 2.0.

```bash
sh tpcds_set_gucs.sh
gpstop -afr
```

### Configure the toolkit parameter file

Before running the tests, we need to review the parameter file and adjust the parameters as needed.

For example: to run a 1TB Power test(Single user test), with cluster with 8 primary segments and 128GB memory per segment, following parameters need to be modified: 
```bash
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.3
vim tpcds_variables.sh

## Line 25: GEN_DATA_SCALE set to 1000, indicating generation of 1000GB test data
export GEN_DATA_SCALE="1000"

## Line 90: Sets memory per statement for single-user tests (This parameter should be set marginally lower than MAX_STATEMENT_MEM. Given MAX_STATEMENT_MEM=16GB, STATEMENT_MEM can be configured as 15GB.)
export STATEMENT_MEM="15GB"
```

> Please be aware that, default value for these parameters might be changed in different toolkit versions, this guide is based on TPC-DS Toolkit v1.1.

Parameters need to be adjusted to run multi-user tests (Throughput test).
For example: to run a 5 streams throughput test.

```bash
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.3
vim tpcds_variables.sh

## Line 26: Number of concurrent users during throughput tests
export MULTI_USER_COUNT="5"

## Line 75: Runs the throughput test of the benchmark. This generates multiple query streams using `dsqgen`, which samples the database to find proper filters. For very large databases with many streams, this process can take hours just to generate the queries.
export RUN_MULTI_USER="true"

## Line 79: Generate multi-user test results to the database and print out logs.
export RUN_MULTI_USER_REPORTS="true"
## Line 91: Sets memory per statement for multi-user tests, for 5 streams with 16G of max_statement_mem, 3GB is set.
export STATEMENT_MEM_MULTI_USER="3GB"
```

For repeating test runs, the following parameters can be adjusted to skip certain steps to save time.

For example: to skip data generation and data loading steps, set following parameters to false:

```bash
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.3
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
```
For more information, please refer to the [README.md](../README.md).

### Execute the test

To run the benchmark, login as gpadmin on mdw:

```bash
ssh gpadmin@mdw
cd ~/TPC-DS-Toolkit-1.3
./run.sh
```
