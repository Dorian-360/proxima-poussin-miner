#!/usr/bin/env bash
# Diagnostic : compare l'enchainement des lots GPU (sans noeud). Usage : ./diag-pipeline.sh [secondes, defaut 20]
cd "$(dirname "$0")"; S="${1:-20}"
run() { echo "-- $1"; env $2 ./proxima-poussin-miner --bench "$S" 2>&1 | grep "MH/s |" | tail -1; }
run "synchrone (comme v1.1)"            "POUSSIN_BENCH_SYNC=1"
run "2 lots en vol"                     ""
run "2 lots en vol + flush"             "POUSSIN_FLUSH=1"
run "synchrone + flush"                 "POUSSIN_BENCH_SYNC=1 POUSSIN_FLUSH=1"
run "2 lots en vol + flush (bis)"       "POUSSIN_FLUSH=1"
