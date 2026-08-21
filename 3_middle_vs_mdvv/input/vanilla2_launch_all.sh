#!/bin/bash
# ================================================================
# gmx_vanilla2 — vanilla md-vv baseline under the NEW test rules
# (test_rules.md, 2026-08-18):
#   - 5 series: NPT VR-CR, NPT NH-CR, NPT NH-MT,
#     NVT NH, NVT VR  (each 9 runs: rigid 0.5/1/2/4/6 fs + flex
#     0.5/1/1.5/2 fs; NH-MT is flex-only — MTTK+constraints is
#     rejected by vanilla 2024.1)
#   - 2000 ps/run, discard first 20% (400 ps), 20000 points in
#     the remaining 1.6 ns  ->  nstout = round(80/dt_fs)
#   - tau-t: rigid 1.0 ps / flex 0.5 ps; tau-p: rigid 2.0 / flex 1.0
#   - never > MAXPROCS (18) total simulation procs running together
#     (counts our mdrun jobs + any other mdrun + lammps 'lmp' tasks).
#     New runs are launched as soon as slots free up.
# Usage:
#   bash launch_all.sh --plan                 # preview matrix, launch nothing
#   bash launch_all.sh                        # launch everything
#   SERIES="NPT-NH-CR" bash launch_all.sh     # one series
#   DTFILTER="2.0 6.0" bash launch_all.sh     # dt subset
# ================================================================

NVT_RUNNER=/home/shuaix/PKUresearch/gmx/nvttest/run_nvt.sh
NPT_RUNNER=/home/shuaix/PKUresearch/gmx/middletest/run_md_shake.sh
TESTDIR=/home/shuaix/PKUresearch/gmx/tests/gmx_vanilla2
GMX_BIN=/home/shuaix/PKUresearch/gmx/builds/gmx_vanilla/build/bin/gmx_mpi
TOTAL_PS=2000

cd "$TESTDIR" || exit 1
mkdir -p nvt npt

# Total simulation procs allowed at once (our mdrun jobs + other mdrun +
# lammps 'lmp' tasks). Default 18 (user rule, not 16).
MAXPROCS=${MAXPROCS:-18}
DTFILTER=${DTFILTER:-}
SERIES=${SERIES:-}
PLAN=no
[ "$1" = "--plan" ] && PLAN=yes

COUNT=0
SKIPPED=0

ALL_SERIES="NPT-VR-CR NPT-NH-CR NPT-NH-MT NVT-NH NVT-VR"

# rigid dt scan (5) + flex dt scan (4) = 9 per series
RIGID_DTS="0.5 1.0 2.0 4.0 6.0"
FLEX_DTS="0.5 1.0 1.5 2.0"

# Count simulation procs currently using CPUs:
#   ours   = our tmux sessions (covers the brief grompp phase before mdrun starts)
#   md     = any running mdrun (ours + other suites; process may be named
#            'mdrun' or 'gmx_mpi'/'gmx' with 'mdrun' as its first arg)
#   lmp    = lammps tasks
# used = max(ours, md) + lmp   (avoids double counting our own jobs, still
#         counts foreign mdrun), then wait until used < MAXPROCS.
count_mdrun() {
  ps -eo comm,args 2>/dev/null | \
    awk '$1=="mdrun" || (($1=="gmx_mpi" || $1=="gmx") && index($0," mdrun ")>0)' | wc -l
}

count_used() {
  local ours md lmp m
  ours=$(tmux ls 2>/dev/null | grep -cE "nvt_tip3p|npt_tip3p" || true)
  md=$(count_mdrun)
  lmp=$(pgrep -x lmp 2>/dev/null | wc -l)
  m=$ours; [ "$md" -gt "$m" ] && m=$md
  echo $((m + lmp))
}

wait_for_slot() {
  [ "$PLAN" = "yes" ] && return
  while [ "$(count_used)" -ge "$MAXPROCS" ]; do sleep 30; done
}

is_done() {
  [ -f "results_$1/md.edr" ] && grep -q "Finished mdrun" "results_$1/md.log" 2>/dev/null
}

tc_short() {
  case "$1" in
    nose-hoover) echo "NH" ;;
    v-rescale)   echo "VR" ;;
    *)           echo "$1" ;;
  esac
}

pc_short() {
  case "$1" in
    MTTK)              echo "MT" ;;
    C-rescale)         echo "CR" ;;
    Parrinello-Rahman) echo "PR" ;;
    *)                 echo "$1" ;;
  esac
}

launch_npt() {
  local sys="$1" dt_fs="$2" tc="$3" pc="$4"
  local d dt ns nso tcs pcs taut taup tautag TASK EXTRA
  if [ -n "$DTFILTER" ] && [[ " $DTFILTER " != *" $dt_fs "* ]]; then return; fi
  d=$(echo "$dt_fs" | sed 's/\./p/')
  dt=$(python3 -c "print($dt_fs/1000)")
  ns=$(python3 -c "print(int($TOTAL_PS*1000/$dt_fs))")
  nso=$(python3 -c "print(int(round(80/$dt_fs)))")
  tcs=$(tc_short "$tc")
  pcs=$(pc_short "$pc")
  if [ "$sys" = "rigid" ]; then taut="1.0"; taup="2.0"; else taut="0.5"; taup="1.0"; fi
  tautag=$(echo "$taut" | sed 's/\./p/')
  if [ "$sys" = "rigid" ]; then
    TASK="npt/npt_tip3p_rigid_shake_dt${d}_${tcs}_${pcs}_tau${tautag}_T300_${TOTAL_PS}ps"
  else
    TASK="npt/npt_tip3p_flex_dt${d}_${tcs}_${pcs}_tau${tautag}_T300_${TOTAL_PS}ps"
  fi
  if [ "$PLAN" = "yes" ]; then
    echo "  $TASK   (md-vv ${tc} + ${pc}, tau-t ${taut} ps, tau-p ${taup} ps, nstout ${nso})"
    COUNT=$((COUNT+1)); return
  fi
  if is_done "$TASK"; then
    echo "[skip] $TASK (already done)"; SKIPPED=$((SKIPPED+1)); return
  fi
  EXTRA="--task $TASK --integrator md-vv --system $sys --tcoupl $tc --pcoupl $pc --constraint-algorithm shake --timestep $dt --nsteps $ns --nstout $nso --tau-t $taut --tau-p $taup --tmux --gmx $GMX_BIN"
  wait_for_slot
  (bash "$NPT_RUNNER" $EXTRA)
  COUNT=$((COUNT+1)); echo "[$COUNT] NPT $sys dt=${dt_fs}fs ${tcs}+${pcs} tau-t=${taut}ps -> $TASK"
}

launch_nvt() {
  local sys="$1" dt_fs="$2" tc="$3"
  local d dt ns nso tcs taut tautag TASK EXTRA
  if [ -n "$DTFILTER" ] && [[ " $DTFILTER " != *" $dt_fs "* ]]; then return; fi
  d=$(echo "$dt_fs" | sed 's/\./p/')
  dt=$(python3 -c "print($dt_fs/1000)")
  ns=$(python3 -c "print(int($TOTAL_PS*1000/$dt_fs))")
  nso=$(python3 -c "print(int(round(80/$dt_fs)))")
  tcs=$(tc_short "$tc")
  if [ "$sys" = "rigid" ]; then taut="1.0"; else taut="0.5"; fi
  tautag=$(echo "$taut" | sed 's/\./p/')
  if [ "$sys" = "rigid" ]; then
    TASK="nvt/nvt_tip3p_rigid_shake_dt${d}_${tcs}_tau${tautag}_T300_${TOTAL_PS}ps"
  else
    TASK="nvt/nvt_tip3p_flex_dt${d}_${tcs}_tau${tautag}_T300_${TOTAL_PS}ps"
  fi
  if [ "$PLAN" = "yes" ]; then
    echo "  $TASK   (md-vv ${tc}, tau-t ${taut} ps, nstout ${nso})"
    COUNT=$((COUNT+1)); return
  fi
  if is_done "$TASK"; then
    echo "[skip] $TASK (already done)"; SKIPPED=$((SKIPPED+1)); return
  fi
  # verlet-buffer-tolerance 0.02 needed so rlist fits the box at rigid dt 6.0
  EXTRA="--task $TASK --integrator md-vv --system $sys --tcoupl $tc --constraint-algorithm shake --timestep $dt --nsteps $ns --nstout $nso --tau-t $taut --verlet-buffer-tolerance 0.02 --tmux --gmx $GMX_BIN"
  wait_for_slot
  (bash "$NVT_RUNNER" $EXTRA)
  COUNT=$((COUNT+1)); echo "[$COUNT] NVT $sys dt=${dt_fs}fs ${tcs} tau-t=${taut}ps -> $TASK"
}

run_series() {
  local series="$1"
  echo "== Series: $series =="
  case "$series" in
    NPT-VR-CR) for sys in rigid flex; do
                 for dt_fs in $([ "$sys" = rigid ] && echo "$RIGID_DTS" || echo "$FLEX_DTS"); do
                   launch_npt "$sys" "$dt_fs" v-rescale C-rescale
                 done; done ;;
    NPT-NH-CR) for sys in rigid flex; do
                 for dt_fs in $([ "$sys" = rigid ] && echo "$RIGID_DTS" || echo "$FLEX_DTS"); do
                   launch_npt "$sys" "$dt_fs" nose-hoover C-rescale
                 done; done ;;
    NPT-NH-MT) for sys in flex; do     # rigid+MTTK rejected by vanilla 2024.1
                 for dt_fs in $FLEX_DTS; do
                   launch_npt "$sys" "$dt_fs" nose-hoover MTTK
                 done; done ;;
    NVT-NH)    for sys in rigid flex; do
                 for dt_fs in $([ "$sys" = rigid ] && echo "$RIGID_DTS" || echo "$FLEX_DTS"); do
                   launch_nvt "$sys" "$dt_fs" nose-hoover
                 done; done ;;
    NVT-VR)    for sys in rigid flex; do
                 for dt_fs in $([ "$sys" = rigid ] && echo "$RIGID_DTS" || echo "$FLEX_DTS"); do
                   launch_nvt "$sys" "$dt_fs" v-rescale
                 done; done ;;
    *) echo "Unknown SERIES=$series (valid: $ALL_SERIES)"; exit 1 ;;
  esac
}

if [ "$PLAN" = "yes" ]; then
  echo "gmx_vanilla2 PLAN — vanilla md-vv, ${TOTAL_PS} ps/run, new test rules"
  echo "tau-t: rigid 1.0 ps / flex 0.5 ps; tau-p: rigid 2.0 / flex 1.0 (NPT)"
  echo "nstout = round(80/dt_fs) -> 20000 pts over 1.6 ns sampling window"
  echo ""
fi

for s in $ALL_SERIES; do
  if [ -n "$SERIES" ] && [ "$s" != "$SERIES" ]; then continue; fi
  run_series "$s"
done

echo ""
if [ "$PLAN" = "yes" ]; then
  echo "PLAN TOTAL: $COUNT runs"
else
  echo "Done: launched=$COUNT, skipped=$SKIPPED (all ${TOTAL_PS} ps runs, MAXPROCS=$MAXPROCS total sim procs)."
  echo "Monitor: tmux ls  |  while tmux ls | grep -qE 'nvt_tip3p|npt_tip3p'; do sleep 30; done; echo ALL_DONE"
fi
