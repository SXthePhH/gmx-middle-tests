#!/bin/bash
# ================================================================
# mid_fullrattle rigid SHAKE+RATTLE NPT at tau-p = 5.0 ps (all dt)
#
# Motivation: match mid_v4's tau-p = 5.0 ps for the rigid comparison
# (v4 ran its whole suite at 5.0 ps; fullrattle main suite is 2.0 ps).
#   dt 0.5, 1.0, 2.0, 4.0, 6.0 fs x NH/LV x MTTK/C-rescale = 20 runs
# Already-finished runs are skipped, so re-running only fills the gap
# (dt 0.5/1.0 were added later; dt 2.0/4.0/6.0 are already done).
# tau-t: NH = 1.0 ps, LV = 1000 x dt (as in both suites).
# All 2000 ps, 216 TIP3P, T=300 K, P=1 bar, nstout=500.
# Usage: cd tests/mid_fullrattle && bash launch_rigid_taup5.sh
# Results go to results_npt/ (names carry _taup5p0_). Skips done runs.
# ================================================================

NPTDIR=/home/shuaix/PKUresearch/gmx/middletest
TESTDIR=/home/shuaix/PKUresearch/gmx/tests/mid_fullrattle
GMX_BIN=/home/shuaix/PKUresearch/gmx/builds/mid_fullrattle/build/bin/gmx_mpi

cd "$TESTDIR" || exit 1
mkdir -p nvt npt
COUNT=0
SKIPPED=0

# Respect global concurrency: count ALL npt_tip3p tmux sessions (any suite)
MAXJOBS=${MAXJOBS:-14}
# Optional: launch only these dt values, e.g. DTFILTER="4.0 6.0"
DTFILTER=${DTFILTER:-}

wait_for_slot() {
  local n
  while :; do
    n=$(tmux ls 2>/dev/null | grep -c "npt_tip3p" || true)
    if [ "$n" -lt "$MAXJOBS" ]; then return; fi
    sleep 30
  done
}

is_done() {
  [ -f "results_$1/md.edr" ] && grep -q "Finished mdrun" "results_$1/md.log" 2>/dev/null
}

launch() {
  local dt_fs="$1" tc="$2" pc="$3"
  local d dt ns tcs pcs TAUS TASK EXTRA TAU_T
  d=$(echo "$dt_fs" | sed 's/\./p/')
  dt=$(python3 -c "print($dt_fs/1000)")
  ns=$(python3 -c "print(int(2000000/$dt_fs))")
  if [ -n "$DTFILTER" ] && [[ " $DTFILTER " != *" $dt_fs "* ]]; then
    return
  fi
  if [ "$tc" = "nose-hoover" ]; then tcs="NH"; TAU_T="1.0"; else tcs="LV"; TAU_T="$dt_fs"; fi
  if [ "$pc" = "MTTK" ]; then pcs="MT"; else pcs="CR"; fi
  # LV carries _tau{d} (tau-t = 1000 x dt); all carry _taup5p0
  TAUS=$([ "$tc" = "langevin" ] && echo "_tau${d}" || echo "")
  TASK="npt/npt_tip3p_rigid_shake_dt${d}_${tcs}${TAUS}_taup5p0_${pcs}_T300_2000ps"
  if is_done "$TASK"; then
    echo "[skip] $TASK (already done)"; SKIPPED=$((SKIPPED+1)); return
  fi
  EXTRA="--task $TASK --integrator middle --system rigid --tcoupl $tc --pcoupl $pc --constraint-algorithm shake --timestep $dt --nsteps $ns --nstout 500 --tmux --gmx $GMX_BIN --tau-t $TAU_T --tau-p 5.0"
  wait_for_slot
  (bash "$NPTDIR/run_md_shake.sh" $EXTRA)
  COUNT=$((COUNT+1)); echo "[$COUNT/20] NPT rigid dt=${dt_fs}fs ${tcs}${TAUS}+${pcs} taup5.0 -> $TASK"
}

echo "Launching mid_fullrattle rigid tau-p=5.0 NPT tests (dt 0.5-6.0)..."
echo ""

# ===== NPT rigid: dt 0.5,1.0,2.0,4.0,6.0 x NH,LV x MT,CR (20, done skipped) =====
for dt in 0.5 1.0 2.0 4.0 6.0; do
  for tc in nose-hoover langevin; do
    for pc in MTTK C-rescale; do
      launch $dt $tc $pc
    done
  done
done

echo ""
echo "All rigid taup5.0 NPT tests launched (launched=$COUNT, skipped=$SKIPPED). Monitor:"
echo "  tmux ls"
echo "  while tmux ls | grep -q tip3p; do sleep 30; done; echo 'ALL DONE'"
