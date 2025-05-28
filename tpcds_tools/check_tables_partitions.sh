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

# Initialize counters for summary
total_tables=0
total_all_rows=0

# Print header for table row counts
printf "\n%-40s|%25s |%9s\n" "table_name" "tuples" "seconds"
printf "%-40s+%25s-+%s\n" "$(printf '%0.s-' {1..40})" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..9})"

for z in $(cat ${distkeyfile}); do
  table_name=$(echo ${z} | awk -F '|' '{print $2}')
  
  # Verify if table_name is empty
  if [ -z "${table_name}" ]; then
    log_time "Warning: Skipping empty table name in distribution file"
    continue
  fi
  
  # Get start time
  start_time=$(date +%s)
  
  # Get row count for each table
  row_count=$(psql ${PSQL_OPTIONS} -At -c "SELECT COUNT(*) FROM ${DB_SCHEMA_NAME}.${table_name};")
  
  # Get end time and calculate duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  # If row_count is empty or not a number, set to 0
  if ! [[ "$row_count" =~ ^[0-9]+$ ]]; then
    row_count=0
  fi
  
  # Update counters
  total_tables=$((total_tables + 1))
  total_all_rows=$((total_all_rows + row_count))
  
  # Format with thousands separator
  row_count_fmt=$(printf "%'d" "${row_count}")
  
  # Print with proper alignment
  printf " %-38s |%24s |%8s\n" "${DB_SCHEMA_NAME}.${table_name}" "${row_count_fmt}" "${duration}"
done

# Print summary after all tables
printf "%-40s+%25s-+%s\n" "$(printf '%0.s-' {1..40})" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..9})"
printf " %-38s |%24s |%8s\n" "Total Tables: ${total_tables}" "$(printf "%'d" ${total_all_rows})" "-"

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

log_time "Checking table sizes and uncompressed sizes for all tables in each schema"
#psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select sotdschemaname,pg_size_pretty(sum(sotdsize)+sum(sotdtoastsize)+sum(sotdadditionalsize)) from gp_toolkit.gp_size_of_table_disk group by sotdschemaname;"
#psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select sotuschemaname,pg_size_pretty(sum(sotusize)::numeric) from gp_toolkit.gp_size_of_table_uncompressed group by sotuschemaname;"