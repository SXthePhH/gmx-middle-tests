#!/bin/bash
# Summarize finished mid_final1 matrix runs: T, P, D, H means over 400-2000 ps
# (discards first 20% equilibration, per skill convention).
GMX=/home/shuaix/PKUresearch/gmx/builds/mid_final1/build/bin/gmx_mpi
export GMX_MAXBACKUP=-1
cd /home/shuaix/PKUresearch/gmx/tests/mid_final1 || exit 1
OUT=summary_matrix.txt
: > "$OUT"

for ens in npt nvt; do
  echo "================ ${ens^^} ================" >> "$OUT"
  for d in results_${ens}/*/; do
    name=$(basename "$d")
    [ -f "$d/md.log" ] && grep -q "Finished mdrun" "$d/md.log" 2>/dev/null || continue
    vals=$(printf "Temperature\nPressure\nDensity\nEnthalpy\nPotential\n0\n" | mpirun -np 1 "$GMX" energy -f "$d/md.edr" -b 400 -nmol 216 -xvg none 2>/dev/null \
      | strings \
      | awk '/^Temperature/{T=$2; Terr=$3} /^Pressure/{P=$2; Perr=$3} /^Density/{D=$2; Derr=$3} /^Enthalpy/{H=$2; Herr=$3} /^Potential/{Pot=$2; Poterr=$3}
             END{printf "T=%.2f Terr=%.3f P=%.2f Perr=%.2f D=%.2f Derr=%.3f H=%.4f Herr=%.4f Pot=%.4f Poterr=%.4f", T, Terr, P, Perr, D, Derr, H, Herr, Pot, Poterr}')
    echo "$name  $vals" >> "$OUT"
  done
done
echo "done -> $OUT"
