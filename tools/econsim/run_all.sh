#!/bin/sh
# Re-run every M1 scenario (results/m1/*.json + logs). ~5 min on 4 cores.
cd "$(dirname "$0")"
N=${1:-30}
for s in "free active" "free casual" "free afk" "free new" "paid active" "paid afk" "whale active"; do
  set -- $s
  python3 m1sim.py $1 $2 200 $N > results/m1/log_$1_$2.txt 2>&1 &
done
wait
python3 m1report.py > results/m1/REPORT.txt
