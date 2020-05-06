#!/bin/sh

nixops ssh explorer -- sh -c "'PGPASSFILE=/var/lib/cexplorer/pgpass psql cexplorer cexplorer'"
