#!/bin/bash
# ================================================================
# mid_fullrattle flex NPT at tau-p = 5.0 ps (dt 0.5 and 1.0 fs only)
#
# Completes the flex tau-p=5.0 coverage: the existing suite has
# taup5p0 flex runs only at dt=2.0 (LV_tau2p0_taup5p0_{CR,MT}).
# These 4 runs fill dt 0.5/1.0 x LV x MTTK/C-rescale so the flex
# mid_fullrattle vs mid_v4 comparison is fully tau-p matched (5.0 ps).
# tau-t = 1000 x dt (LV convention); 2000 ps, nstout=500, 216 TIP3P.
# Usage: cd tests/mid_fullrattle && bash launch_flex_taup5.sh
# ================================================================

NPTDIR=/home/shuaix/PKUresearch/gmx/middletest
TESTDIR=/home/shuaix/PKUresearch/gmx/tests/mid_fullrattle
GMX_BIN=/home/shuaix/PKUresearch/gmx/builds/mid_fullrattle/build/bin/gmx_mpi

cd "$TESTDIR" || exit 1
COUNT=0
SKIPPED=0

wait_for_slot() {
  local n
  while :; do
    n=$(tmux ls 2>/dev/null | grep -c "npt_tip3p" || true)
    if [ "$n" -lt "${MAXJOBS:-14}" ]; then return; fi
    sleep 30
  done
}

is_done() {
  [ -f "results_$1/md.edr" ] && grep -q "Finished mdrun" "results_$1/md.log" 2>/dev/null
}

launch() {
  local dt_fs="$1" pc="$2"
  local d dt ns TASK EXTRA
  d=$(echo "$dt_fs" | sed 's/\./p/')
  dt=$(python3 -c "print($dt_fs/1000)")
  ns=$(python3 -c "print(int(2000000/$dt_fs))")
  pcs=$([ "$pc" = "MTTK" ] && echo "MT" || echo "CR")
  TASK="npt/npt_tip3p_flex_dt${d}_LV_tau${d}_taup5p0_${pcs}_T300_2000ps"
  if is_done "$TASK"; then
    echo "[skip] $TASK (already done)"; SKIPPED=$((SKIPPED+1)); return
  fi
  EXTRA="--task $TASK --integrator middle --system flex --tcoupl langevin --pcoupl $pc --timestep $dt --nsteps $ns --nstout 500 --tmux --gmx $GMX_BIN --tau-t $dt_fs --tau-p 5.0"
  wait_for_slot
  (bash "$NPTDIR/run_md_shake.sh" $EXTRA)
  COUNT=$((COUNT+1)); echo "[$COUNT/4] NPT flex dt=${dt_fs}fs LV+${pcs} taup5.0 -> $TASK"
}

echo "Launching mid_fullrattle flex tau-p=5.0 runs (dt 0.5, 1.0)..."
for dt in 0.5 1.0; do
  for pc in MTTK C-rescale; do
    launch $dt $pc
  done
done

echo ""
echo "All flex taup5 runs launched (launched=$COUNT, skipped=$SKIPPED). Monitor:"
echo "  tmux ls"
echo "  while tmux ls | grep -q tip3p; do sleep 30; done; echo 'ALL DONE'"
