#!/bin/bash

PWD=$(get_pwd ${BASH_SOURCE[0]})
set -e

query_id=1

if [ "${GEN_DATA_SCALE}" == "" ] || [ "${BENCH_ROLE}" == "" ]; then
	echo "Usage: generate_queries.sh scale rolename"
	echo "Example: ./generate_queries.sh 100 hbench"
	echo "This creates queries for 100GB of data."
	exit 1
fi

# Clean up previous SQL files
rm -f ${TPC_H_DIR}/05_sql/*.${BENCH_ROLE}.*.sql*

cd $PWD/queries

for i in $(ls $PWD/*.sql |  xargs -n 1 basename); do
	q=$(echo $i | awk -F '.' '{print $1}')
	id=$(printf %02d $q)
	file_id="1""$id"
	filename=${file_id}.${BENCH_ROLE}.${id}.sql

	echo "echo \":EXPLAIN_ANALYZE\" > $PWD/../../05_sql/$filename"

	printf "set role ${BENCH_ROLE};\nset search_path=${DB_SCHEMA_NAME},public;\n" > ${TPC_H_DIR}/05_sql/${filename}

	for o in $(cat ${TPC_H_DIR}/01_gen_data/optimizer.txt); do
        q2=$(echo ${o} | awk -F '|' '{print $1}')
        if [ "${id}" == "${q2}" ]; then
          optimizer=$(echo ${o} | awk -F '|' '{print $2}')
        fi
    done
	printf "set optimizer=${optimizer};\n" >> ${TPC_H_DIR}/05_sql/${filename}
	printf "set statement_mem=\"${STATEMENT_MEM}\";\n" >> ${TPC_H_DIR}/05_sql/${filename}

	if [ "${ENABLE_VECTORIZATION}" = "on" ]; then
	  printf "set vector.enable_vectorization=${ENABLE_VECTORIZATION};\n" >> ${TPC_H_DIR}/05_sql/${filename}
    fi
	
	printf ":EXPLAIN_ANALYZE\n" >> ${TPC_H_DIR}/05_sql/${filename}
	
	echo "./qgen -d -s ${GEN_DATA_SCALE} $q >> $PWD/../../05_sql/$filename"
	$PWD/qgen -d -s ${GEN_DATA_SCALE} $q >> $PWD/../../05_sql/$filename
done

cd ..

echo "COMPLETE: qgen scale ${GEN_DATA_SCALE}"
