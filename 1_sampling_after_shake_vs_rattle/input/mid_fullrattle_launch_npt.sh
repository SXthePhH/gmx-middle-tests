#!/bin/bash
# ================================================================
# NPT tests for mid_fullrattle (ORIGINAL paper middle scheme:
# full RATTLE velocity constraints + SHAKE position constraints,
# constraint virial 50/50 split, single ComputeGlobals).
#
# Identical test matrix to tests/mid_v1 (baseline for mid_v1's
# 3x-ComputeGlobals sampling change):
#   rigid: 5 dt (0.5,1.0,2.0,4.0,6.0 fs) x NH/LV x MTTK/C-rescale = 20 runs
#   flex:  3 dt (0.5,1.0,2.0 fs)     x NH/LV x MTTK/C-rescale = 12 runs
# All 2000 ps, 216 TIP3P, T=300 K, P=1 bar, tau-p=5.0, nstout=500.
# NEW tau convention: LV tau-t = 1000 x dt (dt_fs ps, encoded in name);
# NH tau-t fixed at 1.0 ps (no suffix). tau-p fixed at 5.0 ps for all.
# Usage: cd tests/mid_fullrattle && bash launch_npt.sh
# Results go to results_npt/. Already-finished runs are skipped.
# ================================================================

NPTDIR=/home/shuaix/PKUresearch/gmx/middletest
TESTDIR=/home/shuaix/PKUresearch/gmx/tests/mid_fullrattle
GMX_BIN=/home/shuaix/PKUresearch/gmx/builds/mid_fullrattle/build/bin/gmx_mpi

cd "$TESTDIR" || exit 1
mkdir -p nvt npt
COUNT=0
SKIPPED=0

# Max concurrent mdrun jobs: 16 per round (18 procs -> 16 concurrent, 2 idle)
MAXJOBS=${MAXJOBS:-16}
# Optional: launch only these dt values, e.g. DTFILTER="2.0 4.0"
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
  local sys="$1" dt_fs="$2" tc="$3" pc="$4"
  local d dt ns tcs pcs TAUS TASK EXTRA
  d=$(echo "$dt_fs" | sed 's/\./p/')
  dt=$(python3 -c "print($dt_fs/1000)")
  ns=$(python3 -c "print(int(2000000/$dt_fs))")
  if [ -n "$DTFILTER" ] && [[ " $DTFILTER " != *" $dt_fs "* ]]; then
    return
  fi
  if [ "$tc" = "nose-hoover" ]; then tcs="NH"; else tcs="LV"; fi
  if [ "$pc" = "MTTK" ]; then pcs="MT"; else pcs="CR"; fi
  # LV: tau-t = 1000 x dt -> tau(ps) = dt(fs), encode in name for all systems
  # NH: tau-t fixed at 1.0 ps, no suffix
  if [ "$tc" = "langevin" ]; then TAUS="_tau${d}"; else TAUS=""; fi
  if [ "$sys" = "rigid" ]; then
    TASK="npt/npt_tip3p_rigid_shake_dt${d}_${tcs}${TAUS}_${pcs}_T300_2000ps"
  else
    TASK="npt/npt_tip3p_flex_dt${d}_${tcs}${TAUS}_${pcs}_T300_2000ps"
  fi
  if is_done "$TASK"; then
    echo "[skip] $TASK (already done)"; SKIPPED=$((SKIPPED+1)); return
  fi
  EXTRA="--task $TASK --integrator middle --system $sys --tcoupl $tc --pcoupl $pc --constraint-algorithm shake --timestep $dt --nsteps $ns --nstout 500 --tmux --gmx $GMX_BIN"
  # tau-t: LV = 1000 x dt (dt_fs ps), NH = 1.0 ps
  if [ "$tc" = "langevin" ]; then
    EXTRA="$EXTRA --tau-t $dt_fs"
  else
    EXTRA="$EXTRA --tau-t 1.0"
  fi
  # tau-p fixed at 5.0 ps (5000 fs) for all barostats
  EXTRA="$EXTRA --tau-p 5.0"
  wait_for_slot
  (bash "$NPTDIR/run_md_shake.sh" $EXTRA)
  COUNT=$((COUNT+1)); echo "[$COUNT/32] NPT $sys dt=${dt_fs}fs ${tcs}${TAUS}+${pcs} -> $TASK"
}

echo "Launching mid_fullrattle NPT tests..."
echo ""

# ===== Two rounds of 16 runs, parallel within each round =====
# Round 1: rigid 6.0, 4.0, 2.0 + flex 2.0  (16)
# Round 2: rigid 0.5, 1.0 + flex 0.5, 1.0   (16)
for pair in "rigid 6.0" "rigid 4.0" "rigid 2.0" "flex 2.0" "rigid 0.5" "rigid 1.0" "flex 0.5" "flex 1.0"; do
  for tc in nose-hoover langevin; do
    for pc in MTTK C-rescale; do
      launch $pair $tc $pc
    done
  done
done

echo ""
echo "All NPT tests launched (launched=$COUNT, skipped=$SKIPPED). Monitor:"
echo "  tmux ls"
echo "  while tmux ls | grep -q tip3p; do sleep 30; done; echo 'ALL DONE'"
