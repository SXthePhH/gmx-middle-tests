#!/bin/bash
# ================================================================
# mid_final1 tau-t x tau-p scan (NPT + NVT) — PREPARED, NOT LAUNCHED
#
# mid_final1 = mid_v9 + v-rescale (VR) + symmetric MTTK scaling split.
# Grid (test-rule defaults in bold):
#   flex  (dt 2.0 fs): tau-t 250/**500**/1000 fs, tau-p **1000**/2000/4000 fs
#   rigid (dt 6.0 fs): tau-t 500/**1000**/2000 fs, tau-p 1000/**2000**/4000 fs
#
# NPT (6 combos VR/NH/LV x MT/CR): flex 6x9=54, rigid 6x9=54 -> 108
# NVT (3 combos VR/NH/LV):         flex 3x9=27, rigid 3x9=27 -> 54
#   NOTE: NVT has no barostat, so the tau-p axis is a NO-OP there
#   (kept only for a uniform grid/naming; the 3 tau-p variants are
#   structurally identical — trim to _taup1000 to cut 36 runs).
# TOTAL: 162 runs, 2000 ps each, 216 TIP3P, T=300 K, P=1 bar (NPT).
# nstout = round(80/dt): flex dt2 -> 40, rigid dt6 -> 13.
#
# Naming (tau in fs):
#   npt_tip3p_{flex_dt2p0|rigid_shake_dt6p0}_{TC}_{PC}_taut{TT}_taup{TP}_T300_2000ps
#   nvt_tip3p_{flex_dt2p0|rigid_shake_dt6p0}_{TC}_taut{TT}_taup{TP}_T300_2000ps
# Results -> results_npt_tau/ and results_nvt_tau/.
#
# Usage: cd tests/tau_scan && bash launch_tau_scan.sh      # launch (waves of <=14)
#        DRYRUN=1 bash launch_tau_scan.sh                  # print commands only
# ================================================================

NPTDIR=/home/shuaix/PKUresearch/gmx/middletest
NVTDIR=/home/shuaix/PKUresearch/gmx/nvttest
TESTDIR=/home/shuaix/PKUresearch/gmx/tests/tau_scan
GMX_BIN=/home/shuaix/PKUresearch/gmx/builds/mid_final1/build/bin/gmx_mpi

cd "$TESTDIR" || exit 1
mkdir -p nvt npt
COUNT=0
SKIPPED=0
DRYRUN=${DRYRUN:-0}

# 18 concurrent = one per core (18 cores, ntomp=1 each)
MAXJOBS=${MAXJOBS:-18}

wait_for_slot() {
  local n
  while :; do
    n=$(tmux ls 2>/dev/null | grep -c "tip3p" || true)
    if [ "$n" -lt "$MAXJOBS" ]; then return; fi
    sleep 30
  done
}

is_done() {
  [ -f "results_$1/md.edr" ] && grep -q "Finished mdrun" "results_$1/md.log" 2>/dev/null
}

tc_short() {
  case "$1" in
    v-rescale)    echo VR ;;
    nose-hoover)  echo NH ;;
    langevin)     echo LV ;;
  esac
}

# launch_npt <flex|rigid> <tc_long> <pc_long> <taut_fs> <taup_fs>   (flex dt2 / rigid dt6)
launch_npt() {
  local sys="$1" tc_long="$2" pc_long="$3" taut_fs="$4" taup_fs="$5"
  local tc pc dt_fs ns nstout TASK EXTRA
  tc=$(tc_short "$tc_long"); pc=$([ "$pc_long" = "MTTK" ] && echo MT || echo CR)
  dt_fs=$([ "$sys" = "flex" ] && echo 2.0 || echo 6.0)
  ns=$(python3 -c "print(int(2000000/$dt_fs))")
  nstout=$(python3 -c "print(round(80/$dt_fs))")
  if [ "$sys" = "flex" ]; then
    TASK="npt_tau/npt_tip3p_flex_dt2p0_${tc}_${pc}_taut${taut_fs}_taup${taup_fs}_T300_2000ps"
  else
    TASK="npt_tau/npt_tip3p_rigid_shake_dt6p0_${tc}_${pc}_taut${taut_fs}_taup${taup_fs}_T300_2000ps"
  fi
  if is_done "$TASK"; then
    echo "[skip] $TASK (already done)"; SKIPPED=$((SKIPPED+1)); return
  fi
  EXTRA="--task $TASK --integrator middle --system $sys --tcoupl $tc_long --pcoupl $pc_long --constraint-algorithm shake --timestep $(python3 -c "print($dt_fs/1000)") --nsteps $ns --nstout $nstout --tmux --gmx $GMX_BIN --tau-t $(python3 -c "print($taut_fs/1000)") --tau-p $(python3 -c "print($taup_fs/1000)")"
  if [ "$DRYRUN" = "1" ]; then
    echo "[dry] $EXTRA"; COUNT=$((COUNT+1)); return
  fi
  wait_for_slot
  (bash "$NPTDIR/run_md_shake.sh" $EXTRA)
  COUNT=$((COUNT+1)); echo "[$COUNT/162] NPT $sys dt=${dt_fs}fs ${tc}+${pc} taut=${taut_fs} taup=${taup_fs} -> $TASK"
}

# launch_nvt <flex|rigid> <tc_long> <taut_fs> <taup_fs>   (tau-p in name only; no barostat)
launch_nvt() {
  local sys="$1" tc_long="$2" taut_fs="$3" taup_fs="$4"
  local tc dt_fs ns nstout TASK EXTRA
  tc=$(tc_short "$tc_long")
  dt_fs=$([ "$sys" = "flex" ] && echo 2.0 || echo 6.0)
  ns=$(python3 -c "print(int(2000000/$dt_fs))")
  nstout=$(python3 -c "print(round(80/$dt_fs))")
  if [ "$sys" = "flex" ]; then
    TASK="nvt_tau/nvt_tip3p_flex_dt2p0_${tc}_taut${taut_fs}_taup${taup_fs}_T300_2000ps"
  else
    TASK="nvt_tau/nvt_tip3p_rigid_shake_dt6p0_${tc}_taut${taut_fs}_taup${taup_fs}_T300_2000ps"
  fi
  if is_done "$TASK"; then
    echo "[skip] $TASK (already done)"; SKIPPED=$((SKIPPED+1)); return
  fi
  EXTRA="--task $TASK --integrator middle --system $sys --tcoupl $tc_long --constraint-algorithm shake --timestep $(python3 -c "print($dt_fs/1000)") --nsteps $ns --nstout $nstout --tmux --gmx $GMX_BIN --tau-t $(python3 -c "print($taut_fs/1000)")"
  if [ "$DRYRUN" = "1" ]; then
    echo "[dry] $EXTRA"; COUNT=$((COUNT+1)); return
  fi
  wait_for_slot
  (bash "$NVTDIR/run_nvt.sh" $EXTRA)
  COUNT=$((COUNT+1)); echo "[$COUNT/162] NVT $sys dt=${dt_fs}fs ${tc} taut=${taut_fs} taup=${taup_fs}(no-op) -> $TASK"
}

echo "mid_final1 tau scan (NPT 108 + NVT 54 = 162 runs) — preparing..."
echo ""

# ================= NPT =================
# flex dt2: tau-t 250/500/1000 x tau-p 1000/2000/4000 x 6 combos = 54
for taut in 250 500 1000; do
  for taup in 1000 2000 4000; do
    for tc in v-rescale nose-hoover langevin; do
      for pc in MTTK C-rescale; do
        launch_npt flex "$tc" "$pc" $taut $taup
      done
    done
  done
done
# rigid dt6: tau-t 500/1000/2000 x tau-p 1000/2000/4000 x 6 combos = 54
for taut in 500 1000 2000; do
  for taup in 1000 2000 4000; do
    for tc in v-rescale nose-hoover langevin; do
      for pc in MTTK C-rescale; do
        launch_npt rigid "$tc" "$pc" $taut $taup
      done
    done
  done
done

# ================= NVT (tau-p is name-only, no barostat) =================
# flex dt2: tau-t 250/500/1000 x tau-p 1000/2000/4000 x 3 thermostats = 27
for taut in 250 500 1000; do
  for taup in 1000 2000 4000; do
    for tc in v-rescale nose-hoover langevin; do
      launch_nvt flex "$tc" $taut $taup
    done
  done
done
# rigid dt6: tau-t 500/1000/2000 x tau-p 1000/2000/4000 x 3 thermostats = 27
for taut in 500 1000 2000; do
  for taup in 1000 2000 4000; do
    for tc in v-rescale nose-hoover langevin; do
      launch_nvt rigid "$tc" $taut $taup
    done
  done
done

echo ""
echo "Total launched=$COUNT skipped=$SKIPPED (expected 162 when dry-running). Monitor:"
echo "  tmux ls"
echo "  while tmux ls | grep -q tip3p; do sleep 30; done; echo 'ALL DONE'"
