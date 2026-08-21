#!/bin/bash
# ================================================================
# Full test matrix for mid_final1 (symmetric MTTK split + v-rescale)
#
# Skill conventions (2026-08-18):
#   - serious runs = 2000 ps (2 ns), discard first 20% (400 ps) for sampling;
#     sampled 1.6 ns yields 20000 points -> nstout = round(80 / dt_fs)
#   - coupling: rigid  tau-t = 1.0 ps, tau-p = 2.0 ps
#               flex   tau-t = 0.5 ps, tau-p = 1.0 ps
#   - 9 tests per set: rigid dt 0.5/1.0/2.0/4.0/6.0 fs (5)
#                      + flex  dt 0.5/1.0/1.5/2.0 fs (4)
#
# Sets (9): NPT {VR, LV, NH} x {MTTK, C-rescale} = 6
#           NVT {VR, LV, NH}                      = 3
# Total 9 x 9 = 81 runs, 216 TIP3P, T=300 K, P=1 bar.
#
# MAXJOBS=18 (user mandate: keep 18 tests on the CPU; each run uses
# NTOMP=1/NMPI=1 -> 18 cores busy). Skill default was 16.
#
# Launch order = shortest wall time first: coarse dt before fine dt
# (dt 6.0 -> 0.5 fs is 12x fewer steps), flex before rigid at equal
# steps (no constraints -> faster per step), so the fast tests drain
# early and the machine stays full with the long tails.
#
# Usage: cd tests/mid_final1 && bash launch_matrix.sh
# Results: results_npt/ and results_nvt/. Already-finished runs skipped.
# Env: MAXJOBS (default 18)
# ================================================================

NPTDIR=/home/shuaix/PKUresearch/gmx/middletest
NVTDIR=/home/shuaix/PKUresearch/gmx/nvttest
TESTDIR=/home/shuaix/PKUresearch/gmx/tests/mid_final1
GMX_BIN=/home/shuaix/PKUresearch/gmx/builds/mid_final1/build/bin/gmx_mpi

cd "$TESTDIR" || exit 1
mkdir -p nvt npt results_npt results_nvt
COUNT=0
SKIPPED=0

# Max concurrent mdrun jobs (tmux sessions)
MAXJOBS=${MAXJOBS:-18}

wait_for_slot() {
  local n
  while :; do
    n=$(tmux ls 2>/dev/null | grep -c "tip3p" || true)
    if [ "$n" -lt "$MAXJOBS" ]; then return; fi
    sleep 20
  done
}

is_done() {
  [ -f "results_$1/md.edr" ] && grep -q "Finished mdrun" "results_$1/md.log" 2>/dev/null
}

# Skip tasks whose tmux session is currently running (restart-safe)
is_running() {
  local sess="${1//\//_}"
  tmux ls 2>/dev/null | grep -q "^${sess}:"
}

# launch <ens> <sys> <dt_fs> <tcoupl> <tc_code> [pcoupl pc_code]
launch() {
  local ens="$1" sys="$2" dt_fs="$3" tc="$4" tcs="$5" pc="$6" pcs="$7"
  local d dt ns nstout taut taup TASK EXTRA
  d=$(echo "$dt_fs" | sed 's/\./p/')
  dt=$(python3 -c "print($dt_fs/1000)")
  ns=$(python3 -c "print(int(2000000/$dt_fs))")
  nstout=$(python3 -c "print(int(round(80/$dt_fs)))")
  if [ "$sys" = "rigid" ]; then taut=1.0; taup=2.0; else taut=0.5; taup=1.0; fi

  if [ "$ens" = "npt" ]; then
    TASK="npt/npt_tip3p_${sys}_shake_dt${d}_${tcs}_${pcs}_T300_2000ps"
    [ "$sys" = "flex" ] && TASK="npt/npt_tip3p_flex_dt${d}_${tcs}_${pcs}_T300_2000ps"
  else
    TASK="nvt/nvt_tip3p_${sys}_shake_dt${d}_${tcs}_T300_2000ps"
    [ "$sys" = "flex" ] && TASK="nvt/nvt_tip3p_flex_dt${d}_${tcs}_T300_2000ps"
  fi

  if is_done "$TASK"; then
    echo "[skip] $TASK (already done)"; SKIPPED=$((SKIPPED+1)); return
  fi
  if is_running "$TASK"; then
    echo "[skip] $TASK (already running)"; SKIPPED=$((SKIPPED+1)); return
  fi

  if [ "$ens" = "npt" ]; then
    EXTRA="--task $TASK --integrator middle --system $sys --tcoupl $tc --pcoupl $pc --constraint-algorithm shake --timestep $dt --nsteps $ns --nstout $nstout --tau-t $taut --tau-p $taup --tmux --gmx $GMX_BIN"
  else
    EXTRA="--task $TASK --integrator middle --system $sys --tcoupl $tc --constraint-algorithm shake --timestep $dt --nsteps $ns --nstout $nstout --tau-t $taut --tmux --gmx $GMX_BIN"
  fi

  wait_for_slot
  if [ "$ens" = "npt" ]; then
    (bash "$NPTDIR/run_md_shake.sh" $EXTRA)
  else
    # NVT mdp emits verlet-buffer-tolerance only when VERLET_TOL is set;
    # without it grompp's default buffer overflows the small starting box.
    (VERLET_TOL=0.02 bash "$NVTDIR/run_nvt.sh" $EXTRA)
  fi
  COUNT=$((COUNT+1)); echo "[$COUNT/81] $ens ${sys} dt=${dt_fs}fs ${tcs}+${pcs} -> $TASK"
}

echo "Launching mid_final1 matrix (81 runs, 2000 ps each, MAXJOBS=$MAXJOBS)..."
echo ""

# 9 sets, in user's order: NPT {VR,LV,NH}x{CR,MT}, NVT {VR,NH,LV}
# dt order = shortest wall time first (coarse -> fine; flex before rigid at equal steps)
for spec in "rigid 6.0" "rigid 4.0" "rigid 2.0" "flex 2.0" "flex 1.5" "rigid 1.0" "flex 1.0" "rigid 0.5" "flex 0.5"; do
  sys=$(echo $spec | cut -d' ' -f1); dtfs=$(echo $spec | cut -d' ' -f2)
  for combo in \
      "npt v-rescale VR mttk MT" \
      "npt v-rescale VR c-rescale CR" \
      "npt langevin LV mttk MT" \
      "npt langevin LV c-rescale CR" \
      "npt nose-hoover NH mttk MT" \
      "npt nose-hoover NH c-rescale CR" \
      "nvt v-rescale VR" \
      "nvt nose-hoover NH" \
      "nvt langevin LV"; do
    set -- $combo
    if [ "$1" = "npt" ]; then
      launch "$1" "$sys" "$dtfs" "$2" "$3" "$4" "$5"
    else
      launch "$1" "$sys" "$dtfs" "$2" "$3"
    fi
  done
done

echo ""
echo "All tests launched (launched=$COUNT, skipped=$SKIPPED)."
echo "Monitor: tmux ls | grep tip3p"
echo "Wait:    while tmux ls | grep -q tip3p; do sleep 60; done; echo ALL_DONE"
