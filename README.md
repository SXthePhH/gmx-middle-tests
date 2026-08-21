# gmx-middle-tests

GROMACS middle-scheme integrator test suite archive — scripts and output
data for the water-box validation of the middle (BAOAB-type) integrator
implemented in [`gromacs_middle`](https://github.com/SXthePhH/gromacs_middle).

System: 216 TIP3P water, T = 300 K, P = 1 bar (NPT). All runs 2000 ps,
first 400 ps (20%) discarded, `gmx energy -b 400 -nmol 216`.

## Contents

| dir | test | what's in it |
|---|---|---|
| `0_rattle_position/` | RATTLE position-constraint consistency | `plot_rattle_position.py` + `rattle_position_summary.csv` + per-combo panels (NH/LV × MT/CR + combined) |
| `1_sampling_after_shake_vs_rattle/` | sampling point: **after SHAKE** (mid_v4) vs **after RATTLE** (mid_fullrattle) | `plot_compare_frv4.py` + rigid/flex panels. LV only, tau-p = 5.0 ps on both sides (tau-matched) |
| `2_tau_scan/` | tau-t × tau-p scan of mid_final1 (162 runs) | `launch_tau_scan.sh` (matrix), `extract_summary.py` / `analyze.py`, `summary_tau_scan.txt` (all 162 runs), `analysis_tables.md` (tables with error bars + conclusions), `README.md` |
| `3_middle_vs_mdvv/` | middle (mid_final1) vs vanilla md-vv comparison | `plot_gmx_compare.py` + per-scheme scripts, the two summaries, and the 12 panels (gmx_cmp_*, gmxv2_*, midf1_*) |

## Key results (summary)

- **RATTLE position** (0): position-constraint consistency of the middle
  scheme across thermostats/barostats.
- **Sampling point** (1): at matched tau-p = 5.0 ps, fullrattle's
  after-RATTLE temperature stays within 300 ± 0.6 K up to dt 6 fs rigid,
  while mid_v4's after-SHAKE temperature drifts to ~302 K — the sampling
  location matters at large timesteps (see the panels).
- **tau scan** (2): mid_final1 is stable over the whole grid at dt 6 rigid /
  dt 2 flex. Rigid: temperature flat over all tau; flex: only tau-t moves T
  (+0.3–0.4 K from 250→1000 fs). Density: flex **Langevin is the only
  correct-density thermostat family** at dt 2.0 (≈1009–1011, flat), while
  v-rescale/NH creep to 1022–1033. Defaults (flex tau-t 500 / tau-p 1000,
  rigid 1000/2000 fs) sit in the good region.
- **middle vs md-vv** (3): full 121-run comparison of the middle scheme
  (mid_final1) against stock md-vv across NPT/NVT, rigid/flex, dt scans.

## Reproduce

Each subdirectory contains the plotting/analysis scripts; point them at the
matching GROMACS build (`gromacs_middle`, mid_v4/mid_fullrattle binaries)
and result directories as documented in each script's header.
