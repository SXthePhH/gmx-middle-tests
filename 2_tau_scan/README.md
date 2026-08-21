# mid_final1 tau-t × tau-p scan (NPT + NVT)

**Prepared but NOT launched** (2026-08-20). Lives in its own folder
`gmx/tests/tau_scan/`.

## Variant

`mid_final1` = `mid_v9` (two-half MTTK box scaling, second half before
SHAKE) + v-rescale thermostat (Bussi–Donadio–Parrinello, merged from
`mid_v91`) + symmetric pre1/post2 MTTK scaling split.

Binary: `builds/mid_final1/build/bin/gmx_mpi`

## Grid (test-rule defaults in bold)

| system | dt (fs) | tau-t scan (fs) | tau-p scan (fs) |
|--------|---------|-----------------|-----------------|
| flex | 2.0 | 250 / **500** / 1000 | **1000** / 2000 / 4000 |
| rigid (SHAKE+RATTLE) | 6.0 | 500 / **1000** / 2000 | 1000 / **2000** / 4000 |

## Run count (162)

| ensemble | combos | flex | rigid | total |
|----------|--------|------|-------|-------|
| NPT | VR/NH/LV × MT/CR (6) | 6×9 = 54 | 6×9 = 54 | 108 |
| NVT | VR/NH/LV (3) | 3×9 = 27 | 3×9 = 27 | 54 |

> **NVT caveat**: NVT has no barostat, so the tau-p axis is a **no-op**
> there — the 3 tau-p variants are structurally identical (tau-p kept in
> the name only, for a uniform grid). To skip the redundancy, keep only
> `_taup1000` NVT runs → NVT drops to 18, total 126.

All runs: 2000 ps, 216 TIP3P, T = 300 K, P = 1 bar (NPT), nstout =
round(80/dt) = 40 (dt 2.0) / 13 (dt 6.0).

## Naming

```
npt_tip3p_{flex_dt2p0|rigid_shake_dt6p0}_{TC}_{PC}_taut{TT}_taup{TP}_T300_2000ps
nvt_tip3p_{flex_dt2p0|rigid_shake_dt6p0}_{TC}_taut{TT}_taup{TP}_T300_2000ps
```
TC = VR|NH|LV, PC = MT|CR, TT/TP = tau in fs. Results →
`results_npt_tau/` and `results_nvt_tau/`.

## Launch

```bash
cd tests/tau_scan
DRYRUN=1 bash launch_tau_scan.sh        # print the 162 commands, launch nothing
bash launch_tau_scan.sh                 # launch (waves of <=14 tmux sessions)
# or detached:
tmux new-session -d -s mf1_tauscan "bash tests/tau_scan/launch_tau_scan.sh"
```

Skips already-finished runs. Monitor:
`tmux ls` / `while tmux ls | grep -q tip3p; do sleep 30; done`

## Notes

- tau-t is the explicit scan value for ALL thermostats (VR/NH/LV); the
  old "LV tau-t = 1000×dt" convention is not applied here.
- VR + MTTK: barostat DOF remain thermostatted by the middle NH chains
  (v-rescale cannot act on barostat DOF — same as stock VV+MTTK+VR).
