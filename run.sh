#/bin/bash

logfilename=$(date +%Y%m%d)_$(date +%H%M%S)
nohup sh tpch.sh > tpch.$logfilename.log 2>&1 &

