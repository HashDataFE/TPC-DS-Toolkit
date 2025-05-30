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

# Print header for table row counts with left-aligned headers
printf "\n%-60s|%25s |%9s\n" "table_name" "tuples" "seconds"
printf "%s+%s+%s\n" "$(printf '%0.s-' {1..60})" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..9})"

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
  row_count=$(psql ${PSQL_OPTIONS} -At -q -c "SELECT COUNT(*) FROM ${DB_SCHEMA_NAME}.${table_name};")
  
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
  
  # Format row count with thousands separator
  row_count_fmt=$(printf "%'d" "${row_count}")
  
  # Print data rows with fixed width and alignment
  printf "%-60s|%25s |%8d\n" "${DB_SCHEMA_NAME}.${table_name}" "${row_count_fmt}" "${duration}"
done

# Print summary line with matching alignment
printf "%s+%s+%s\n" "$(printf '%0.s-' {1..60})" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..9})"
printf "%-60s|%25s |%8s\n" "Total Tables: ${total_tables}" "$(printf "%'d" ${total_all_rows})" "-"


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
  log_time "Checking partition distribution for table ${DB_SCHEMA_NAME}.${tbl}"

  # Get all partition tables for this base table - suppress all notices
  partitions=$(psql ${PSQL_OPTIONS} -At -q -X -c "SET client_min_messages TO WARNING; SELECT tablename FROM pg_tables WHERE schemaname='${DB_SCHEMA_NAME}' AND tablename ~ '^${tbl}_[0-9]+_prt_'" 2>/dev/null)

  row_counts=()
  total_rows=0
  non_empty_partitions=0

  for part in $partitions; do
    # Suppress all notices for row count queries
    row_count=$(psql ${PSQL_OPTIONS} -At -q -X -c "SET client_min_messages TO WARNING; SELECT COUNT(*) FROM ${DB_SCHEMA_NAME}.\"${part}\";" 2>/dev/null)
    # Only include non-zero partitions in statistics
    if [ "$row_count" -gt 0 ]; then
      row_counts+=("$row_count")
      total_rows=$((total_rows + row_count))
      non_empty_partitions=$((non_empty_partitions + 1))
    fi
  done

  if [ "${#row_counts[@]}" -gt 0 ]; then
    min_rows=$(printf "%s\n" "${row_counts[@]}" | sort -n | head -1)
    max_rows=$(printf "%s\n" "${row_counts[@]}" | sort -n | tail -1)
    avg_rows=$((total_rows / non_empty_partitions))
    skew_percent=$(awk "BEGIN {print ((${max_rows} - ${min_rows}) * 100 / ${avg_rows})}")
    
    # Get others partition row count
    others_count=$(psql ${PSQL_OPTIONS} -At -q -c "SELECT COUNT(*) FROM ${DB_SCHEMA_NAME}.${tbl}_1_prt_others;")
    if ! [[ "$others_count" =~ ^[0-9]+$ ]]; then
        others_count=0
    fi
    
    # Summary output
    log_time "Partition summary for ${tbl}:"
    log_time "  Total partitions: $(echo "$partitions" | wc -l)"
    log_time "  Non-empty partitions: ${non_empty_partitions}"
    log_time "  Total rows: $(printf "%'d" ${total_rows})"
    log_time "  Rows in 'others' partition: $(printf "%'d" ${others_count})"
    log_time "  Row distribution: min=$(printf "%'d" ${min_rows}), max=$(printf "%'d" ${max_rows}), avg=$(printf "%'d" ${avg_rows})"
    log_time "  Skew: ${skew_percent}%"
  else
    log_time "No data found in any partition for table ${tbl}"
  fi

  # Min/Max for the partition key for the entire table with notices suppressed
  log_time "Partition key range for ${tbl}:"
  psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -X -P pager=off -c \
    "SET client_min_messages TO WARNING; SELECT MIN(${key}) AS min_${key}, MAX(${key}) AS max_${key} FROM ${DB_SCHEMA_NAME}.${tbl};" 2>/dev/null

done

log_time "Checking table sizes and uncompressed sizes for all tables in each schema"
#psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select sotdschemaname,pg_size_pretty(sum(sotdsize)+sum(sotdtoastsize)+sum(sotdadditionalsize)) from gp_toolkit.gp_size_of_table_disk group by sotdschemaname;"
#psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=0 -q -e -P pager=off -c "select sotuschemaname,pg_size_pretty(sum(sotusize)::numeric) from gp_toolkit.gp_size_of_table_uncompressed group by sotuschemaname;"