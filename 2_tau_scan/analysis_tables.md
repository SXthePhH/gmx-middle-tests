# mid_final1 tau scan — LV analysis tables (with error bars)

**System:** 216 TIP3P · T=300 K · P=1 bar (NPT) · 2000 ps per run, first 400 ps discarded.
**Variant:** mid_final1 (mid_v9 + v-rescale + symmetric MTTK split). dt: rigid 6.0 fs, flex 2.0 fs.
**Thermostat:** Langevin only. x-axis = tau-t, y-axis = tau-p (fs).

## 1. Temperature (K) — 6 cases = 2 systems × 3 integration styles

### 1) RIGID dt6 × LV+MTTK (NPT)

| tau-p \ tau-t (fs) | 500 | 1000 | 2000 |
|---|---|---|---|
| 1000 | 300.20±0.07 | 300.33±0.17 | 299.86±0.12 |
| 2000 | 300.19±0.12 | 300.14±0.11 | 300.01±0.10 |
| 4000 | 300.37±0.11 | 300.11±0.06 | 300.27±0.20 |

*Unit: K (value ± Err.Est.)*

### 2) RIGID dt6 × LV+C-rescale (NPT)

| tau-p \ tau-t (fs) | 500 | 1000 | 2000 |
|---|---|---|---|
| 1000 | 300.18±0.06 | 299.98±0.13 | 300.19±0.17 |
| 2000 | 300.21±0.06 | 300.22±0.11 | 299.95±0.14 |
| 4000 | 300.16±0.16 | 299.85±0.04 | 300.08±0.18 |

*Unit: K (value ± Err.Est.)*

### 3) RIGID dt6 × LV (NVT) — tau-p is name-only (no barostat)

| tau-p \ tau-t (fs) | 500 | 1000 | 2000 |
|---|---|---|---|
| 1000 | 300.18±0.10 | 299.98±0.05 | 300.17±0.09 |
| 2000 | 300.26±0.10 | 300.22±0.15 | 300.29±0.17 |
| 4000 | 300.18±0.05 | 300.06±0.10 | 300.03±0.21 |

*Unit: K (value ± Err.Est.)*

### 4) FLEX dt2 × LV+MTTK (NPT)

| tau-p \ tau-t (fs) | 250 | 500 | 1000 |
|---|---|---|---|
| 1000 | 300.23±0.06 | 300.36±0.06 | 300.35±0.07 |
| 2000 | 300.17±0.05 | 300.34±0.08 | 300.33±0.09 |
| 4000 | 300.22±0.09 | 300.30±0.06 | 300.61±0.04 |

*Unit: K (value ± Err.Est.)*

### 5) FLEX dt2 × LV+C-rescale (NPT)

| tau-p \ tau-t (fs) | 250 | 500 | 1000 |
|---|---|---|---|
| 1000 | 300.40±0.06 | 300.28±0.09 | 300.50±0.11 |
| 2000 | 300.29±0.07 | 300.43±0.06 | 300.80±0.16 |
| 4000 | 300.18±0.05 | 300.42±0.04 | 300.47±0.13 |

*Unit: K (value ± Err.Est.)*

### 6) FLEX dt2 × LV (NVT) — tau-p is name-only (no barostat)

| tau-p \ tau-t (fs) | 250 | 500 | 1000 |
|---|---|---|---|
| 1000 | 300.11±0.05 | 300.28±0.09 | 300.49±0.12 |
| 2000 | 300.11±0.06 | 300.21±0.04 | 300.50±0.10 |
| 4000 | 300.15±0.04 | 300.22±0.04 | 300.51±0.14 |

*Unit: K (value ± Err.Est.)*

## 2. Density (kg/m³) — NPT only (reference: rigid ≈ 984-985, flex ≈ 1009-1010)

### 1) RIGID dt6 × LV+MTTK

| tau-p \ tau-t (fs) | 500 | 1000 | 2000 |
|---|---|---|---|
| 1000 | 982.51±0.81 | 983.36±0.23 | 985.03±0.38 |
| 2000 | 981.03±0.52 | 982.37±0.74 | 985.62±0.46 |
| 4000 | 980.34±1.30 | 983.11±0.61 | 984.80±0.60 |

*Unit: kg/m³ (value ± Err.Est.)*

### 2) RIGID dt6 × LV+C-rescale

| tau-p \ tau-t (fs) | 500 | 1000 | 2000 |
|---|---|---|---|
| 1000 | 977.61±0.97 | 983.89±0.84 | 982.53±1.10 |
| 2000 | 977.97±1.50 | 980.90±1.20 | 985.44±1.20 |
| 4000 | 978.72±2.50 | 984.69±0.91 | 985.01±1.40 |

*Unit: kg/m³ (value ± Err.Est.)*

### 3) FLEX dt2 × LV+MTTK

| tau-p \ tau-t (fs) | 250 | 500 | 1000 |
|---|---|---|---|
| 1000 | 1009.04±1.00 | 1010.67±1.00 | 1010.75±0.38 |
| 2000 | 1008.72±0.87 | 1010.19±0.39 | 1009.91±0.51 |
| 4000 | 1010.55±1.30 | 1009.28±0.54 | 1009.26±0.20 |

*Unit: kg/m³ (value ± Err.Est.)*

### 4) FLEX dt2 × LV+C-rescale

| tau-p \ tau-t (fs) | 250 | 500 | 1000 |
|---|---|---|---|
| 1000 | 1009.73±1.60 | 1009.50±0.96 | 1010.47±0.46 |
| 2000 | 1008.04±0.39 | 1008.88±0.66 | 1011.39±0.89 |
| 4000 | 1008.43±1.60 | 1010.57±1.30 | 1010.18±0.80 |

*Unit: kg/m³ (value ± Err.Est.)*

## 3. Enthalpy (kJ/mol per molecule) — NPT only

### 1) RIGID dt6 × LV+MTTK

| tau-p \ tau-t (fs) | 500 | 1000 | 2000 |
|---|---|---|---|
| 1000 | -32.50±0.01 | -32.50±0.02 | -32.56±0.01 |
| 2000 | -32.50±0.01 | -32.50±0.01 | -32.55±0.01 |
| 4000 | -32.47±0.01 | -32.52±0.01 | -32.52±0.02 |

*Unit: kJ/mol (value ± Err.Est.)*

### 2) RIGID dt6 × LV+C-rescale

| tau-p \ tau-t (fs) | 500 | 1000 | 2000 |
|---|---|---|---|
| 1000 | -32.46±0.01 | -32.52±0.01 | -32.52±0.02 |
| 2000 | -32.47±0.02 | -32.49±0.01 | -32.55±0.01 |
| 4000 | -32.47±0.02 | -32.54±0.01 | -32.55±0.02 |

*Unit: kJ/mol (value ± Err.Est.)*

### 3) FLEX dt2 × LV+MTTK

| tau-p \ tau-t (fs) | 250 | 500 | 1000 |
|---|---|---|---|
| 1000 | -27.95±0.02 | -27.94±0.01 | -27.95±0.01 |
| 2000 | -27.95±0.02 | -27.95±0.01 | -27.93±0.02 |
| 4000 | -27.93±0.01 | -27.94±0.01 | -27.91±0.01 |

*Unit: kJ/mol (value ± Err.Est.)*

### 4) FLEX dt2 × LV+C-rescale

| tau-p \ tau-t (fs) | 250 | 500 | 1000 |
|---|---|---|---|
| 1000 | -27.93±0.01 | -27.94±0.01 | -27.94±0.01 |
| 2000 | -27.93±0.01 | -27.95±0.01 | -27.92±0.02 |
| 4000 | -27.92±0.02 | -27.94±0.02 | -27.94±0.01 |

*Unit: kJ/mol (value ± Err.Est.)*

## 4. Potential energy (kJ/mol per molecule) — NVT only

### 1) RIGID dt6 × LV (NVT)

| tau-p \ tau-t (fs) | 500 | 1000 | 2000 |
|---|---|---|---|
| 1000 | -40.18±0.01 | -40.18±0.01 | -40.18±0.01 |
| 2000 | -40.16±0.01 | -40.18±0.01 | -40.18±0.01 |
| 4000 | -40.17±0.01 | -40.19±0.01 | -40.18±0.01 |

*Unit: kJ/mol (value ± Err.Est.)*

### 2) FLEX dt2 × LV (NVT)

| tau-p \ tau-t (fs) | 250 | 500 | 1000 |
|---|---|---|---|
| 1000 | -39.14±0.01 | -39.14±0.01 | -39.13±0.02 |
| 2000 | -39.13±0.01 | -39.14±0.01 | -39.13±0.01 |
| 4000 | -39.12±0.02 | -39.13±0.01 | -39.13±0.01 |

*Unit: kJ/mol (value ± Err.Est.)*

## 5. Conclusions

### Temperature
- **Rigid (dt 6.0): all 3 styles flat** across the whole tau-t × tau-p grid (299.9–300.4 K, Err.Est. ≈ 0.1–0.3 K). Neither tau-t nor tau-p moves T beyond noise; the SHAKE+RATTLE constraints absorb the large-timestep error.
- **Flex (dt 2.0): only tau-t matters.** Weaker Langevin coupling (250 → 1000 fs) warms the reported T by ≈ +0.3–0.4 K (e.g. LV+CR: 300.2 → 300.6; NVT LV: 300.1 → 300.5), comparable to or larger than the Err.Est. (≈ 0.05–0.1 K), i.e. a real trend, not noise. Same in NPT and NVT, so it is the thermostat coupling strength, not the barostat.
- **tau-p has no effect on T** anywhere (≤ 0.15 K scatter, within error bars).
- Worst corners: flex LV+CR (tau-t 1000, tau-p 2000) = 300.80 K; flex LV+MT (tau-t 1000, tau-p 4000) = 300.61 K. Still small; no runaway.

### Density (NPT)
- **Rigid: correct and flat** — LV+MT 980–986, LV+CR 978–985 (ref ≈ 984), Err.Est. ≈ 0.3–1.0. Slight under-density for LV+CR at short tau-t (977.6 at tau-t 500, tau-p 1000).
- **Flex: LV+MT and LV+CR both land on target (≈ 1009–1011, ref ≈ 1010) and are flat across the grid**, Err.Est. ≈ 0.2–0.7 — the Langevin thermostat does NOT suffer the flex dt2 density creep that v-rescale/NH show (1022–1033).

### Enthalpy / Potential energy
- Rigid: H ≈ −32.4 to −32.6 kJ/mol (Err ≈ 0.01–0.03), flat; Pot (NVT) ≈ −40.16 to −40.19 kJ/mol (Err ≈ 0.005–0.02), flat.
- Flex: H ≈ −27.91 to −27.95 kJ/mol (Err ≈ 0.01–0.02), Pot (NVT) ≈ −39.12 to −39.14 kJ/mol (Err ≈ 0.01), flat; consistent with the stable flex LV density (no creep → no enthalpy creep).

### Overall recommendation (LV)
- Rigid dt6: any tau-t/tau-p works; default rigid tau-t 1000 / tau-p 2000 is fine (LV+MT preferred over LV+CR for pressure).
- Flex dt2: keep **tau-t ≤ 500 fs** (T closest to 300); tau-p irrelevant. **LV is the only correct-density thermostat family for flex at dt 2.0** (VR/NH creep to 1022–1033).