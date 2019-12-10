#!/bin/sh

set -ex

NOW=`date -Iseconds`
CMD="nixops ssh explorer --"

$CMD "pg_dump cexplorer -U cexplorer" > pg_dump-${NOW}.sql
gzip -9v pg_dump-${NOW}.sql
