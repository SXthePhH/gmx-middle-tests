#!/bin/bash
# Extract T/P/D/H/Pot stats (mean ± Err.Est.) for all gmx_vanilla2 runs
# using NAME-based gmx energy selection (robust to per-run term layouts).
set -u
cd /home/shuaix/PKUresearch/gmx/tests/gmx_vanilla2
GMX=/home/shuaix/PKUresearch/gmx/builds/gmx_vanilla/build/bin/gmx_mpi
export GMX_MAXBACKUP=-1
OUT=summary_vanilla2.txt
echo -e "run\tT\tTerr\tP\tPerr\tD\tDerr\tH\tHerr\tPot\tPoterr" > "$OUT"
n=0
for d in results_npt/* results_nvt/*; do
  [ -f "$d/md.edr" ] || continue
  n=$((n+1))
  name=$(basename "$d")
  raw=$(printf "Potential\nTemperature\nPressure\nDensity\nEnthalpy\n0\n" \
    | $GMX energy -f "$d/md.edr" -b 400 -nmol 216 -xvg none 2>/dev/null)
  get() { echo "$raw" | awk -v k="$1" '$1==k{printf "%s %s", $2, $3}'; }
  T=$(get Temperature);  P=$(get Pressure);  D=$(get Density)
  H=$(get Enthalpy);     Pot=$(get Potential)
  # keep values on one tab-separated line
  vals=("$name" ${T:-"- -"} ${P:-"- -"} ${D:-"- -"} ${H:-"- -"} ${Pot:-"- -"})
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${vals[@]}" | tr ' ' '\t' >> "$OUT"
  echo "[$n] $name"
done
echo "DONE $n runs -> $OUT"
