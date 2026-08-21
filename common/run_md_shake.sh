#!/bin/bash
set -e

# ============================================================
# SHAKE-based MD simulation runner for GROMACS water tests
# ============================================================

GMX="/home/shuaix/PKUresearch/gmx/builds/mid_lmpconst/build/bin/gmx_mpi"
GMX_DATA="/home/shuaix/PKUresearch/gmx/gromacs-2024.1-middle/share/top"
export GMXLIB=$GMX_DATA

# --- Defaults ---
WATER="tip3p"
SYSTEM="rigid"
INTEGRATOR="md-vv"
TCOUPL="v-rescale"
PCOUPL="c-rescale"
CONSTRAINT_ALGO="shake"
TIMESTEP=""
NSTEPS=50000
NSTOUT=500
NTOMP=1
NMPI=1
TAUT="0.1"
TAUT_SET="no"
TAUP="5.0"
TASK="run"
MODE="direct"
ANALYZE="no"

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --water               spce|tip3p (default: $WATER)"
    echo "  --system              rigid|flex (default: $SYSTEM)"
    echo "  --integrator          md|md-vv|md-vv-avek|sd|middle (default: $INTEGRATOR)"
    echo "  --tcoupl              v-rescale|nose-hoover|berendsen|andersen|langevin (default: $TCOUPL)"
    echo "  --pcoupl              c-rescale|berendsen|mttk|parrinello-rahman (default: $PCOUPL)"
    echo "  --constraint-algorithm lincs|shake (default: $CONSTRAINT_ALGO)"
    echo "  --timestep            dt in ps (rigid default: 0.002, flex default: 0.001)"
    echo "  --nsteps              total steps (default: $NSTEPS)"
    echo "  --nstout              output interval in steps (default: $NSTOUT)"
    echo "  --ntomp               OpenMP threads (default: $NTOMP)"
    echo "  --nmpi                MPI ranks (default: $NMPI)"
    echo "  --task                output directory name (default: $TASK)"
    echo "  --tau-t               tau_t for thermostat (default: $TAUT)"
    echo "  --tau-p               tau_p for barostat (default: $TAUP)"
    echo "  --gmx                 path to gmx_mpi binary (default: $GMX)"
    echo "  --tmux                launch in detached tmux session (named after task)"
    echo "  --analyze             run analyze.py after mdrun completes"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --water)                WATER="$2";            shift 2 ;;
        --system)               SYSTEM="$2";           shift 2 ;;
        --integrator)           INTEGRATOR="$2";       shift 2 ;;
        --tcoupl)               TCOUPL="$2";           shift 2 ;;
        --pcoupl)               PCOUPL="$2";           shift 2 ;;
        --constraint-algorithm) CONSTRAINT_ALGO="$2";  shift 2 ;;
        --timestep)             TIMESTEP="$2";         shift 2 ;;
        --nsteps)               NSTEPS="$2";           shift 2 ;;
        --nstout)               NSTOUT="$2";           shift 2 ;;
        --ntomp)                NTOMP="$2";            shift 2 ;;
        --nmpi)                 NMPI="$2";             shift 2 ;;
        --task)                 TASK="$2";             shift 2 ;;
        --tau-t)                TAUT="$2";             TAUT_SET="yes"; shift 2 ;;
        --tau-p)                TAUP="$2";             shift 2 ;;
        --gmx)                  GMX="$2";              shift 2 ;;
        --tmux)                 MODE="tmux";           shift ;;
        --analyze)              ANALYZE="yes";         shift ;;
        -h|--help)              usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done


# Convention (2026-08-14): flexible water + Langevin -> tau-t = 200 fs (0.2 ps)
if [ "$TAUT_SET" = "no" ] && [ "$SYSTEM" = "flex" ] && [ "$TCOUPL" = "langevin" ]; then
    TAUT="0.2"
fi

# --- If tmux mode, re-spawn self in tmux with all current args ---
if [ "$MODE" = "tmux" ]; then
    ARGS=""
    ARGS="$ARGS --water $WATER"
    ARGS="$ARGS --system $SYSTEM"
    ARGS="$ARGS --integrator $INTEGRATOR"
    ARGS="$ARGS --tcoupl $TCOUPL"
    ARGS="$ARGS --pcoupl $PCOUPL"
    ARGS="$ARGS --constraint-algorithm $CONSTRAINT_ALGO"
    ARGS="$ARGS --timestep $TIMESTEP"
    ARGS="$ARGS --nsteps $NSTEPS"
    ARGS="$ARGS --nstout $NSTOUT"
    ARGS="$ARGS --ntomp $NTOMP"
    ARGS="$ARGS --nmpi $NMPI"
    ARGS="$ARGS --task $TASK"
    ARGS="$ARGS --tau-t $TAUT"
    ARGS="$ARGS --tau-p $TAUP"
    ARGS="$ARGS --gmx $GMX"
    [ "$ANALYZE" = "yes" ] && ARGS="$ARGS --analyze"

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    SCRIPT_NAME="$(basename "$0")"
    SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"
    SESSION="${TASK//\//_}"

    RUNNER="/tmp/tmux_${SESSION}.sh"
    cat > "$RUNNER" << RUNNEREOF
#!/bin/bash
cd "$(pwd)"
bash "$SCRIPT_PATH" $ARGS
RUNNEREOF
    chmod +x "$RUNNER"

    tmux kill-session -t "$SESSION" 2>/dev/null || true
    tmux new-session -d -s "$SESSION" "$RUNNER"
    echo "tmux session '$SESSION' started (attach: tmux attach -t $SESSION)"
    exit 0
fi

# --- Validate water model ---
case $WATER in
    spce)  WATER_ITP="gromos54a7.ff/spce.itp"; FF="gromos54a7.ff" ;;
    tip3p) WATER_ITP="amber99sb.ff/tip3p.itp"; FF="amber99sb.ff" ;;
    *) echo "ERROR: --water must be 'spce' or 'tip3p'"; exit 1 ;;
esac

GRO=/home/shuaix/PKUresearch/gmx/middletest/em_${WATER}.gro

# --- Set system-specific defaults ---
case $SYSTEM in
    rigid)
        [[ -z "$TIMESTEP" ]] && TIMESTEP=0.002
        FLEXIBLE_DEFINE=""
        CONSTRAINT_LINES="constraints     = all-bonds
constraint-algorithm = ${CONSTRAINT_ALGO}"
        ;;
    flex)
        [[ -z "$TIMESTEP" ]] && TIMESTEP=0.001
        FLEXIBLE_DEFINE="#define FLEXIBLE"
        CONSTRAINT_LINES=""
        ;;
    *) echo "ERROR: --system must be 'rigid' or 'flex'"; exit 1 ;;
esac

# --- Create output directory ---
OUTDIR="results_${TASK}"
mkdir -p "$OUTDIR"

# --- Generate topology ---
TOPOL="${OUTDIR}/topol.top"
cat > "$TOPOL" << TOPEOF
${FLEXIBLE_DEFINE}
#include "${FF}/forcefield.itp"
#include "${WATER_ITP}"

[ system ]
216 ${SYSTEM} ${WATER^^} water molecules

[ molecules ]
SOL     216
TOPEOF

# --- Generate MDP ---
MDP="${OUTDIR}/md.mdp"
cat > "$MDP" << MDPEOF
integrator      = ${INTEGRATOR}
nsteps          = ${NSTEPS}
dt              = ${TIMESTEP}
nstxout-compressed = ${NSTOUT}
nstvout         = ${NSTOUT}
nstlog          = ${NSTOUT}
nstenergy       = ${NSTOUT}
nstlist         = 10
verlet-buffer-tolerance = 0.02
cutoff-scheme   = Verlet
rlist           = 0.9
coulombtype     = PME
rcoulomb        = 0.9
vdwtype         = Cut-off
rvdw            = 0.9
pbc             = xyz
nstcomm         = 1
DispCorr        = EnerPres
tcoupl          = ${TCOUPL}
tc-grps         = System
tau-t           = ${TAUT}
ref-t           = 300
pcoupl          = ${PCOUPL}
pcoupltype      = isotropic
tau-p           = ${TAUP}
ref-p           = 1.0
compressibility = 4.5e-5
nsttcouple      = 1
nstpcouple      = 1
${CONSTRAINT_LINES}
continuation    = no
gen-vel         = yes
gen-temp        = 300
gen-seed        = -1
MDPEOF

# --- Run ---
echo "=============================================="
echo " Task:                $TASK"
echo " Water:               ${WATER^^}"
echo " System:              $SYSTEM"
echo " Integrator:          $INTEGRATOR"
echo " T-coupling:          $TCOUPL"
echo " P-coupling:          $PCOUPL"
echo " Constraint algorithm: $CONSTRAINT_ALGO"
echo " Time step:           ${TIMESTEP} ps"
echo " Steps:               $NSTEPS"
echo " Length:              $(python3 -c "print(${NSTEPS}*${TIMESTEP})") ps"
echo " Output dir:          $OUTDIR"
echo "=============================================="

echo "[1/2] grompp ..."
$GMX grompp -f "$MDP" -c "$GRO" -p "$TOPOL" -o "${OUTDIR}/md.tpr" -maxwarn 5 \
    -po "${OUTDIR}/mdout.mdp" 2>&1 | tail -3

echo "[2/2] mdrun (nmpi=$NMPI, ntomp=$NTOMP) ..."
if [ "$NMPI" -gt 1 ]; then
    mpirun -np "$NMPI" $GMX mdrun -deffnm "${OUTDIR}/md" -v -ntomp "$NTOMP"
else
    $GMX mdrun -deffnm "${OUTDIR}/md" -v -ntomp "$NTOMP"
fi

echo ""
echo "Done. Output in $OUTDIR/"
if [ "$ANALYZE" = "yes" ]; then
    python3 "$(dirname "$0")/analyze.py" "$OUTDIR" --begin 400 --gmx "$GMX"
else
    echo "Analyze with: python3 analyze.py $OUTDIR"
fi
