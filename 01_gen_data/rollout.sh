#!/bin/bash
#set -e

PWD=$(get_pwd ${BASH_SOURCE[0]})

if [ "${GEN_DATA_SCALE}" == "" ]; then
  log_time "You must provide the scale as a parameter in terms of Gigabytes."
  log_time "Example: ./rollout.sh 100"
  log_time "This will create 100 GB of data for this test."
  exit 1
fi

# Handle RNGSEED configuration
if [ "${UNIFY_QGEN_SEED}" == "true" ]; then
  # Use a fixed RNGSEED when unified seed is enabled
  RNGSEED=2016032410
else 
  # Get a random RNGSEED from current time
  RNGSEED=$(date +%s)
fi

function get_count_generate_data() {
  count="0"
  while read -r i; do
    next_count=$(ssh -o ConnectTimeout=0 -o LogLevel=quiet -n -f ${i} "bash -c 'ps -ef | grep generate_data.sh | grep -v grep | wc -l'" 2>&1 || true)
    check="^[0-9]+$"
    if ! [[ ${next_count} =~ ${check} ]]; then
      next_count="1"
    fi
    count=$((count + next_count))
  done < ${TPC_DS_DIR}/segment_hosts.txt
}

function kill_orphaned_data_gen() {
  log_time "kill any orphaned dsdgen processes on segment hosts"
  # always return true even if no processes were killed
  for i in $(cat ${TPC_DS_DIR}/segment_hosts.txt); do
    ssh ${i} "pkill dsdgen" || true &
    ssh ${i} "rm -rf /tmp/tpcds.generate_data.*.log" || true &
  done
  wait
}

function copy_generate_data() {
  log_time "copy generate_data.sh to segment hosts"
  for i in $(cat ${TPC_DS_DIR}/segment_hosts.txt); do
    scp ${PWD}/generate_data.sh ${i}: &
  done
  wait
}

function gen_data() {

  PARALLEL=$(gpstate | grep "Total primary segments" | awk -F '=' '{print $2}')
  if [ "${PARALLEL}" == "" ]; then
    log_time "ERROR: Unable to determine how many primary segments are in the cluster using gpstate."
    exit 1
  fi

  #Actual PARALLEL should be $LOCAL_GEN_PARALLEL*$PARALLEL
  PARALLEL=$((LOCAL_GEN_PARALLEL * PARALLEL))
  
  log_time "Number of Generate Data Parallel Process is: $PARALLEL"

  
  if [ "${DB_VERSION}" == "gpdb_4_3" ] || [ "${DB_VERSION}" == "gpdb_5" ]; then
    SQL_QUERY="select row_number() over(), g.hostname, p.fselocation as path from gp_segment_configuration g join pg_filespace_entry p on g.dbid = p.fsedbid join pg_tablespace t on t.spcfsoid = p.fsefsoid where g.content >= 0 and g.role = '${GPFDIST_LOCATION}' and t.spcname = 'pg_default' order by 1, 2, 3"  
  else
    SQL_QUERY="select row_number() over(), g.hostname, g.datadir from gp_segment_configuration g where g.content >= 0 and g.role = '${GPFDIST_LOCATION}' order by 1, 2, 3"
  
  fi
  
  log_time "Clean up previous data generation folder on segments."
  for h in $(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -A -t -c "${SQL_QUERY}"); do
    EXT_HOST=$(echo ${h} | awk -F '|' '{print $2}')
    SEG_DATA_PATH=$(echo ${h} | awk -F '|' '{print $3}' | sed 's#//#/#g')
    log_time "ssh -n ${EXT_HOST} \"rm -rf ${SEG_DATA_PATH}/dsbenchmark\""
    ssh -n ${EXT_HOST} "rm -rf ${SEG_DATA_PATH}/dsbenchmark"
    log_time "ssh -n ${EXT_HOST} \"mkdir -p ${SEG_DATA_PATH}/dsbenchmark\""
    ssh -n ${EXT_HOST} "mkdir -p ${SEG_DATA_PATH}/dsbenchmark"
  done
  
  CHILD=1
  for i in $(psql ${PSQL_OPTIONS} -v ON_ERROR_STOP=1 -q -A -t -c "${SQL_QUERY}"); do
    EXT_HOST=$(echo ${i} | awk -F '|' '{print $2}')
    SEG_DATA_PATH=$(echo ${i} | awk -F '|' '{print $3}' | sed 's#//#/#g')

    for ((j=1; j<=LOCAL_GEN_PARALLEL; j++)); do
      GEN_DATA_PATH="${SEG_DATA_PATH}/dsbenchmark/${CHILD}"
      log_time "ssh -n ${EXT_HOST} \"bash -c 'cd ~/; ./generate_data.sh ${GEN_DATA_SCALE} ${CHILD} ${PARALLEL} ${GEN_DATA_PATH} ${RNGSEED} > /tmp/tpcds.generate_data.${CHILD}.log 2>&1 &'\""
      ssh -n ${EXT_HOST} "bash -c 'cd ~/; ./generate_data.sh ${GEN_DATA_SCALE} ${CHILD} ${PARALLEL} ${GEN_DATA_PATH} ${RNGSEED} > /tmp/tpcds.generate_data.${CHILD}.log 2>&1 &'" &
      CHILD=$((CHILD + 1))
    done
  done
  wait
}

step="gen_data"

log_time "Step ${step} started"
printf "\n"

init_log ${step}
start_log
schema_name="${DB_VERSION}"
export schema_name
table_name="gen_data"
export table_name

if [ "${GEN_NEW_DATA}" == "true" ]; then
  if [ "${RUN_MODEL}" != "local" ]; then
    PARALLEL=${CLIENT_GEN_PARALLEL}
    CHILD=1
    GEN_DATA_PATH="${CLIENT_GEN_PATH}"

    if [[ ! -d "${GEN_DATA_PATH}" && ! -L "${GEN_DATA_PATH}" ]]; then
      log_time "mkdir ${GEN_DATA_PATH}"
      mkdir ${GEN_DATA_PATH}
    fi
    rm -rf ${GEN_DATA_PATH}/*
    mkdir -p ${GEN_DATA_PATH}/logs
    
    while [ ${CHILD} -le ${PARALLEL} ]; do
      log_time "sh ${PWD}/dsdgen -scale ${GEN_DATA_SCALE} -dir ${GEN_DATA_PATH} -parallel ${PARALLEL} -child ${CHILD} -RNGSEED ${RNGSEED} -terminate n > ${GEN_DATA_PATH}/logs/tpcds.generate_data.${CHILD}.log 2>&1 &"
      cd ${PWD}
      ${PWD}/dsdgen -scale ${GEN_DATA_SCALE} -dir ${GEN_DATA_PATH} -parallel ${PARALLEL} -child ${CHILD} -RNGSEED ${RNGSEED} -terminate n > ${GEN_DATA_PATH}/logs/tpcds.generate_data.${CHILD}.log 2>&1 &
      CHILD=$((CHILD + 1))
    done
    wait
  else
    kill_orphaned_data_gen
    copy_generate_data
    gen_data
    echo ""
    get_count_generate_data
    log_time "Now generating data.  This may take a while."
    seconds=0
    echo -ne "Generating data duration: "
    tput sc
    while [ "$count" -gt "0" ]; do
      tput rc
      echo -ne "${seconds} second(s)"
      sleep 5
      seconds=$((seconds + 5))
      get_count_generate_data
    done
  fi
  echo ""
  log_time "Done generating data"
fi

print_log

log_time "Step ${step} finished"
printf "\n"