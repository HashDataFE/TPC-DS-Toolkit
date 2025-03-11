#!/bin/bash

PWD=$(get_pwd ${BASH_SOURCE[0]})

set -e

query_id=1
file_id=101

if [ "${GEN_DATA_SCALE}" == "" ] || [ "${BENCH_ROLE}" == "" ]; then
  echo "Usage: generate_queries.sh scale rolename"
  echo "Example: ./generate_queries.sh 100 dsbench"
  echo "This creates queries for 100GB of data."
  exit 1
fi

#!/bin/bash

# define data loding log file
LOG_FILE="${TPC_DS_DIR}/log/rollout_load.log"

# get the Load Test End timestamp from the log file for RNGSEED
if [[ -f "$LOG_FILE" ]]; then
  RNGSEED=$(tail -n 1 "$LOG_FILE" | cut -d '|' -f 6)
else
  RNGSEED=12345
fi

rm -f ${PWD}/query_0.sql

log_time "${PWD}/dsqgen -input ${PWD}/query_templates/templates.lst -directory ${PWD}/query_templates -dialect hashdata -scale ${GEN_DATA_SCALE} -RNGSEED ${RNGSEED} -verbose y -output ${PWD}"
${PWD}/dsqgen -input ${PWD}/query_templates/templates.lst -directory ${PWD}/query_templates -dialect hashdata -scale ${GEN_DATA_SCALE} -RNGSEED ${RNGSEED} -verbose y -output ${PWD}

rm -f ${TPC_DS_DIR}/05_sql/*.${BENCH_ROLE}.*.sql*

for p in $(seq 1 99); do
  q=$(printf %02d ${query_id})
  filename=${file_id}.${BENCH_ROLE}.${q}.sql
  template_filename=query${p}.tpl
  start_position=""
  end_position=""
  for pos in $(grep -n ${template_filename} ${PWD}/query_0.sql | awk -F ':' '{print $1}'); do
    if [ "${start_position}" == "" ]; then
      start_position=${pos}
    else
      end_position=${pos}
    fi
  done

	log_time "Creating: ${TPC_DS_DIR}/05_sql/${filename}"
	printf "set role ${BENCH_ROLE};\nset search_path=${SCHEMA_NAME},public;\n" > ${TPC_DS_DIR}/05_sql/${filename}

	for o in $(cat ${TPC_DS_DIR}/01_gen_data/optimizer.txt); do
        q2=$(echo ${o} | awk -F '|' '{print $1}')
        if [ "${p}" == "${q2}" ]; then
          optimizer=$(echo ${o} | awk -F '|' '{print $2}')
        fi
    done
	printf "set optimizer=${optimizer};\n" >> ${TPC_DS_DIR}/05_sql/${filename}
	printf "set statement_mem=\"${STATEMENT_MEM}\";\n" >> ${TPC_DS_DIR}/05_sql/${filename}

  if [ "${ENABLE_VECTORIZATION}" = "on" ]; then
    printf "set vector.enable_vectorization=${ENABLE_VECTORIZATION};\n" >> ${TPC_DS_DIR}/05_sql/${filename}
  fi

  printf ":EXPLAIN_ANALYZE\n" >> ${TPC_DS_DIR}/05_sql/${filename}
	
  sed -n ${start_position},${end_position}p ${PWD}/query_0.sql >> ${TPC_DS_DIR}/05_sql/${filename}
	query_id=$((query_id + 1))
	file_id=$((file_id + 1))
	echo "Completed: ${TPC_DS_DIR}/05_sql/${filename}"
done

echo ""
echo "queries 114, 123, 124, and 139 have 2 queries in each file.  Need to add :EXPLAIN_ANALYZE to second query in these files"
echo ""
arr=("114.${BENCH_ROLE}.14.sql" "123.${BENCH_ROLE}.23.sql" "124.${BENCH_ROLE}.24.sql" "139.${BENCH_ROLE}.39.sql")

for z in "${arr[@]}"; do
	myfilename=${TPC_DS_DIR}/05_sql/${z}
	echo "Modifying: ${myfilename}"
  
  if [ "${ENABLE_VECTORIZATION}" = "on" ]; then
    pos=$(grep -n ";" ${myfilename} | awk -F ':' ' { if (NR > 5) print $1 }' | head -1)
  else
    pos=$(grep -n ";" ${myfilename} | awk -F ':' ' { if (NR > 4) print $1 }' | head -1)  
  fi

	pos=$((pos + 1))
	sed -i ''${pos}'i\'$'\n'':EXPLAIN_ANALYZE'$'\n' ${myfilename}
	echo "Modified: ${myfilename}"
done

log_time "COMPLETE: dsqgen scale ${GEN_DATA_SCALE} with RNGSEED ${RNGSEED}"