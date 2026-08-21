# gmx-middle-tests

GROMACS middle-scheme integrator test suite archive — **reproducible**:
input scripts, extracted output data, and plots for the water-box
validation of the middle (BAOAB-type) integrator implemented in
[`gromacs_middle`](https://github.com/SXthePhH/gromacs_middle).

## Layout & reproducibility

```
common/                             # shared runner + starting structure
├── test_rules.md                   # user-mandated test rules (the reference)
├── em_tip3p.gro                    # energy-minimized 216 TIP3P starting box
├── run_md_shake.sh                 # NPT runner (generates topol/mdp on the fly)
└── run_nvt.sh                      # NVT runner
```

Each numbered directory is self-contained:

```
N_<test>/
├── README.md        # purpose, data provenance, exact reproduction steps
├── input/           # the launch scripts used to generate the runs
├── data/            # extracted output data (mean ± Err.Est.)
├── <plot>.py        # plotting/analysis scripts
└── plots/           # the published panels
```

Every test: 216 TIP3P, T = 300 K, P = 1 bar (NPT), 2000 ps per run, first
400 ps (20%) discarded, `gmx energy -b 400 -nmol 216`. Binaries are the
`gromacs_middle` variants (mid_v9 / mid_v9_rfirst / mid_fullrattle /
mid_v4 / mid_final1) and the vanilla 2024.1 md-vv build; each launcher
points at its own binary.

## Contents

| dir | test | data |
|---|---|---|
| `0_rattle_position/` | RATTLE position-constraint consistency (mid_v9 vs mid_v9_rfirst) | `data/rattle_position_summary.csv` + 5 panels |
| `1_sampling_after_shake_vs_rattle/` | sampling point: after SHAKE (mid_v4) vs after RATTLE (mid_fullrattle), LV, tau-p = 5.0 matched | `data/frv4_comparison.csv` (32 rows) + 2 panels |
| `2_tau_scan/` | tau-t × tau-p scan of mid_final1 (162 runs, dt6 rigid / dt2 flex) | `data/summary_tau_scan.txt` (162 rows) + `analysis_tables.md` (error-bar tables + conclusions) |
| `3_middle_vs_mdvv/` | middle (mid_final1) vs vanilla md-vv (121 runs) | `data/summary_matrix.txt` + `data/summary_vanilla2.txt` + 12 panels |

## Key results

- **Sampling point**: at matched tau-p = 5.0 ps, after-RATTLE sampling stays
  300 ± 0.6 K up to dt 6 fs rigid; after-SHAKE drifts to ~302 K. The sampling
  location matters at large timesteps.
- **tau scan**: mid_final1 stable over the whole grid at dt6 rigid / dt2
  flex. Rigid T flat over all tau; flex T warms +0.3–0.4 K with tau-t
  250→1000 fs; tau-p is a no-op for T. Density: flex **Langevin is the only
  correct-density thermostat family** at dt 2.0 (≈1009–1011, flat);
  v-rescale/NH creep to 1022–1033. Defaults sit in the good region.
- **middle vs md-vv**: flex dt2 density creep is thermostat-dependent
  (deterministic thermostats accumulate it; Langevin does not); rigid water
  is dt-independent and matches md-vv.

## Reproduce (one line per test)

```bash
# 0) RATTLE position
bash 0_rattle_position/input/mid_v9_launch_npt.sh           # with mid_v9 binary
bash 0_rattle_position/input/mid_v9_rfirst_launch_npt.sh    # with mid_v9_rfirst
python3 0_rattle_position/plot_rattle_position.py

# 1) sampling point
bash 1_sampling_after_shake_vs_rattle/input/mid_fullrattle_launch_npt.sh
bash 1_sampling_after_shake_vs_rattle/input/mid_fullrattle_launch_rigid_taup5.sh
bash 1_sampling_after_shake_vs_rattle/input/mid_fullrattle_launch_flex_taup5.sh
bash 1_sampling_after_shake_vs_rattle/input/mid_v4_launch_npt.sh
python3 1_sampling_after_shake_vs_rattle/plot_compare_frv4.py

# 2) tau scan (162 runs)
bash 2_tau_scan/input/launch_tau_scan.sh                    # mid_final1 binary
python3 2_tau_scan/extract_summary.py && python3 2_tau_scan/analyze.py

# 3) middle vs md-vv
bash 3_middle_vs_mdvv/input/vanilla2_launch_all.sh          # gmx_vanilla binary
bash 3_middle_vs_mdvv/input/mid_final1_launch_matrix.sh     # mid_final1 binary
bash 3_middle_vs_mdvv/input/vanilla2_extract.sh
bash 3_middle_vs_mdvv/input/mid_final1_summary_results.sh
python3 3_middle_vs_mdvv/plot_gmx_compare.py
```

All launchers use `common/run_md_shake.sh` / `common/run_nvt.sh` and
`common/em_tip3p.gro`; run them from the respective test directory so the
`results_*` output lands next to the launcher.
