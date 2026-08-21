#!/bin/bash
# ================================================================
# NPT tests for mid_v9_rfirst — middle integrator with RATTLE
# after the FIRST velocity update (v after VelocityHalfStep1),
# instead of mid_v9's placement after the SECOND update.
#
# 2000 ps per run, 216 TIP3P rigid, T=300 K, P=1 bar, tau-p=5.0.
# Matrix (same as mid_v9 rigid): dt {0.5,1,2,4,6} fs
#   x {NH, LV} x {MTTK, C-rescale} = 20 runs
# LV tau-t = 1000 x dt (dt_fs ps); NH tau-t = 1.0 ps.
# Usage: cd tests/mid_v9_rfirst && bash launch_npt.sh
# Results go to results_npt/. Already-finished runs are skipped.
# ================================================================

NPTDIR=/home/shuaix/PKUresearch/gmx/middletest
TESTDIR=/home/shuaix/PKUresearch/gmx/tests/mid_v9_rfirst
GMX_BIN=/home/shuaix/PKUresearch/gmx/builds/mid_v9_rfirst/build/bin/gmx_mpi

cd "$TESTDIR" || exit 1
mkdir -p npt
COUNT=0
SKIPPED=0

MAXJOBS=${MAXJOBS:-16}
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
  local d dt ns tcs pcs TAUS TASK EXTRA
  d=$(echo "$dt_fs" | sed 's/\./p/')
  dt=$(python3 -c "print($dt_fs/1000)")
  ns=$(python3 -c "print(int(2000000/$dt_fs))")
  if [ -n "$DTFILTER" ] && [[ " $DTFILTER " != *" $dt_fs "* ]]; then
    return
  fi
  if [ "$tc" = "nose-hoover" ]; then tcs="NH"; else tcs="LV"; fi
  if [ "$pc" = "MTTK" ]; then pcs="MT"; else pcs="CR"; fi
  if [ "$tc" = "langevin" ]; then TAUS="_tau${d}"; else TAUS=""; fi
  TASK="npt/npt_tip3p_rigid_shake_dt${d}_${tcs}${TAUS}_${pcs}_T300_2000ps"
  if is_done "$TASK"; then
    echo "[skip] $TASK (already done)"; SKIPPED=$((SKIPPED+1)); return
  fi
  EXTRA="--task $TASK --integrator middle --system rigid --tcoupl $tc --pcoupl $pc --constraint-algorithm shake --timestep $dt --nsteps $ns --nstout 500 --tmux --gmx $GMX_BIN"
  # tau-t: LV = 1000 x dt (dt_fs ps), NH = 1.0 ps
  if [ "$tc" = "langevin" ]; then
    EXTRA="$EXTRA --tau-t $dt_fs"
  else
    EXTRA="$EXTRA --tau-t 1.0"
  fi
  # tau-p fixed at 5.0 ps
  EXTRA="$EXTRA --tau-p 5.0"
  wait_for_slot
  (bash "$NPTDIR/run_md_shake.sh" $EXTRA)
  COUNT=$((COUNT+1)); echo "[$COUNT/20] NPT rigid dt=${dt_fs}fs ${tcs}${TAUS}+${pcs} -> $TASK"
}

echo "Launching mid_v9_rfirst NPT tests (2000 ps per run)..."
echo ""

for dt_fs in 0.5 1.0 2.0 4.0 6.0; do
  for tc in nose-hoover langevin; do
    for pc in MTTK C-rescale; do
      launch "$dt_fs" "$tc" "$pc"
    done
  done
done

echo ""
echo "All NPT tests launched (launched=$COUNT, skipped=$SKIPPED). Monitor:"
echo "  tmux ls"
echo "  while tmux ls | grep -q tip3p; do sleep 30; done; echo 'ALL DONE'"
