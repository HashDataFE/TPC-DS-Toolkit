#!/bin/bash

# To run this script, source tpcds_variables.sh and functions.sh.

VARS_FILE="tpcds_variables.sh"
FUNCTIONS_FILE="functions.sh"

current_dir=$(pwd)
parent_dir="${current_dir%/*}"
echo "Parent directory: $parent_dir"

# shellcheck source=tpcds_variables.sh
source $parent_dir/${VARS_FILE}
# shellcheck source=functions.sh
source $parent_dir/${FUNCTIONS_FILE}

PWD=$(get_pwd ${BASH_SOURCE[0]})

get_version
log_time "Current database running this test is:\n${VERSION_FULL}"

if [ "${DB_VERSION}" == "gpdb_4_3" ] || [ "${DB_VERSION}" == "gpdb_5" ]; then
  distkeyfile="$parent_dir/03_ddl/distribution_original.txt"
else
  distkeyfile="$parent_dir/03_ddl/distribution.txt"
fi

for z in $(cat ${distkeyfile}); do
  table_name=$(echo ${z} | awk -F '|' '{print $2}')
  distribution=$(echo ${z} | awk -F '|' '{print $3}')
  # Check total rows for all tables
  log_time "Total rows for table ${DB_SCHEMA_NAME}.${table_name}:"
  sql="SELECT COUNT(*) AS total_rows FROM ${DB_SCHEMA_NAME}.${table_name};"
  psql ${PSQL_OPTIONS} -e -v ON_ERROR_STOP=0 -q -P pager=off -c "${sql}"
done

for i in $parent_dir/03_ddl/*.${filter}.*.partition; do
  id=$(echo ${i} | awk -F '.' '{print $1}')
  export id
  schema_name=${DB_SCHEMA_NAME}
  # schema_name=$(echo ${i} | awk -F '.' '{print $2}')
  table_name=$(echo ${i} | awk -F '.' '{print $3}')

  # Drop existing partition tables if they exist
  SQL_QUERY="SELECT COUNT(*) FROM ${DB_SCHEMA_NAME}.${table_name}"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -A -t -c "${SQL_QUERY}"
done

# Check that the partition tables are correctly set; there should be no rows returned.
log_time "Checking that the partition tables are correctly set; there should be no rows returned."

psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "SELECT MAX(cr_returned_date_sk), MIN(cr_returned_date_sk) FROM ${DB_SCHEMA_NAME}.catalog_returns_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "SELECT MAX(cs_sold_date_sk), MIN(cs_sold_date_sk) FROM ${DB_SCHEMA_NAME}.catalog_sales_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "SELECT MAX(inv_date_sk), MIN(inv_date_sk) FROM ${DB_SCHEMA_NAME}.inventory_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "SELECT MAX(sr_returned_date_sk), MIN(sr_returned_date_sk) FROM ${DB_SCHEMA_NAME}.store_returns_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "SELECT MAX(ss_sold_date_sk), MIN(ss_sold_date_sk) FROM ${DB_SCHEMA_NAME}.store_sales_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "SELECT MAX(wr_returned_date_sk), MIN(wr_returned_date_sk) FROM ${DB_SCHEMA_NAME}.web_returns_1_prt_others;"
psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "SELECT MAX(ws_sold_date_sk), MIN(ws_sold_date_sk) FROM ${DB_SCHEMA_NAME}.web_sales_1_prt_others;"

# List of partitioned tables and their partition key columns
partition_tables=(
  "catalog_returns:cr_returned_date_sk"
  "catalog_sales:cs_sold_date_sk"
  "inventory:inv_date_sk"
  "store_returns:sr_returned_date_sk"
  "store_sales:ss_sold_date_sk"
  "web_returns:wr_returned_date_sk"
  "web_sales:ws_sold_date_sk"
)

for entry in "${partition_tables[@]}"; do
  tbl="${entry%%:*}"
  key="${entry##*:}"
  log_time "Checking partition row distribution for table ${DB_SCHEMA_NAME}.${tbl}"

  # Get all partition tables for this base table
  partitions=$(psql ${PSQL_OPTIONS} -At -c "SELECT tablename FROM pg_tables WHERE schemaname='${DB_SCHEMA_NAME}' AND tablename ~ '^${tbl}_[0-9]+_prt_'")

  row_counts=()
  total_rows=0

  for part in $partitions; do
    row_count=$(psql ${PSQL_OPTIONS} -At -c "SELECT COUNT(*) FROM ${DB_SCHEMA_NAME}.\"${part}\";")
    log_time "Partition: ${part}, Rows: ${row_count}"
    row_counts+=("$row_count")
    total_rows=$((total_rows + row_count))
  done

  if [ "${#row_counts[@]}" -gt 0 ]; then
    min_rows=$(printf "%s\n" "${row_counts[@]}" | sort -n | head -1)
    max_rows=$(printf "%s\n" "${row_counts[@]}" | sort -n | tail -1)
    sum_rows=0
    for n in "${row_counts[@]}"; do sum_rows=$((sum_rows + n)); done
    avg_rows=$((sum_rows / ${#row_counts[@]}))
    if [ "$avg_rows" -ne 0 ]; then
      skew_percent=$(awk "BEGIN {print ((${max_rows} - ${min_rows}) * 100 / ${avg_rows})}")
    else
      skew_percent=0
    fi
    log_time "Partition row count stats for ${tbl}: min=${min_rows}, max=${max_rows}, avg=${avg_rows}, skew=${skew_percent}%"
  else
    log_time "No partitions found for table ${tbl}"
  fi

  # Min/Max for the partition key for the entire table
  log_time "Min/Max for partition key in table ${DB_SCHEMA_NAME}.${tbl}:"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -P pager=off -c \
    "SELECT MIN(${key}) AS min_${key}, MAX(${key}) AS max_${key} FROM ${DB_SCHEMA_NAME}.${tbl};"
done