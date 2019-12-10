#!/bin/sh

set -xe

# Retrieve benchmarking results

CORE_NODES="a b c"

TIMESTAMP=$(date "+%Y-%m-%d-%H%M%S")
DIR_ON_STAGING_FOR_RESULTS=/tmp/benchmarking-results-$TIMESTAMP

## Create temporary directory for results
mkdir -p ${DIR_ON_STAGING_FOR_RESULTS}/a
mkdir -p ${DIR_ON_STAGING_FOR_RESULTS}/b
mkdir -p ${DIR_ON_STAGING_FOR_RESULTS}/c
mkdir -p ${DIR_ON_STAGING_FOR_RESULTS}/explorer
mkdir -p ${DIR_ON_STAGING_FOR_RESULTS}/node-on-explorer
mkdir -p ${DIR_ON_STAGING_FOR_RESULTS}/generator

## Get and download JSON logs from all core nodes.
for N in $CORE_NODES
do
nixops scp --from $N /var/lib/cardano-node/logs/node-\*.json ${DIR_ON_STAGING_FOR_RESULTS}/${N}/
done

## Get and download JSON log from the cardano-node working on explorer machine.
nixops scp --from explorer /var/lib/cardano-node/logs/node-\*.json ${DIR_ON_STAGING_FOR_RESULTS}/node-on-explorer/

## Get and download JSON log from tx generator.
nixops scp --from explorer /tmp/tx-gen-\*.json ${DIR_ON_STAGING_FOR_RESULTS}/generator/

## Get and download an output from analyse-blocks.sh script.
CMD="nixops ssh explorer --"
$CMD "./analyse-blocks.sh" > ${DIR_ON_STAGING_FOR_RESULTS}/explorer/analyse.txt

## Get and download SQL-dump of explorer's database.
CMD="nixops ssh explorer --"
$CMD "pg_dump cexplorer -U cexplorer" > ${DIR_ON_STAGING_FOR_RESULTS}/explorer/pg_cexplorer.sql
gzip -9v ${DIR_ON_STAGING_FOR_RESULTS}/explorer/pg_cexplorer.sql

## Copy revision file
cp nix/sources.json $DIR_ON_STAGING_FOR_RESULTS/

## Create an archive with results, for more convenient downloading from staging machine.
tar czf benchmarking-results-${TIMESTAMP}.tgz -C /tmp benchmarking-results-${TIMESTAMP}
