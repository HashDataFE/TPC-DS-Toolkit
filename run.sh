#/bin/bash

logfilename=$(date +%Y%m%d)_$(date +%H%M%S)
nohup sh tpcds.sh > tpcds_$logfilename.log 2>&1 &
echo "Benchmark started running in the background, please check tpcds_$logfilename.log for more information."
echo "To stop the benchmark, run: kill \$(ps -ef | grep tpcds.sh | grep -v grep | awk '{print \$2}')"
echo "To check the status of the benchmark, run: tail -f tpcds_$logfilename.log"
