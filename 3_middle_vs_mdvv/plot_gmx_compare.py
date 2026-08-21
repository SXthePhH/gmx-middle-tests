#!/usr/bin/env python3
"""Combined GROMACS panels: md-vv (gmx_vanilla2) + middle (mid_final1) together.

Same style as before (500 dpi, large fonts, error bars, fixed T range).
Scheme encoded by line style: middle = solid, md-vv = dashed.
Color encodes the coupling combo. Outputs gmx_cmp_* panels into gmx_mdvv_middle/.
"""
import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path("/home/shuaix/PKUresearch/gmx/tests")
OUT = ROOT / "gmx_mdvv_middle"
OUT.mkdir(exist_ok=True)

plt.rcParams.update({
    "font.size": 15,
    "axes.labelsize": 16,
    "axes.titlesize": 16,
    "xtick.labelsize": 14,
    "ytick.labelsize": 14,
    "legend.fontsize": 9,
    "figure.titlesize": 24,
})

NPT_COMBOS = ["VR-MT", "VR-CR", "LV-MT", "LV-CR", "NH-MT", "NH-CR"]
NVT_COMBOS = ["VR", "LV", "NH"]
# color = thermostat (same thermostat -> same color across schemes/barostats)
COLORS = {"VR": "#1f77b4", "LV": "#2ca02c", "NH": "#d62728"}
# marker = barostat (NVT has no barostat -> circle)
MARKERS = {"MT": "o", "CR": "s", None: "o"}
LS = {"middle": "-", "md-vv": "--"}


def combo_parts(combo):
    """('VR-MT') -> ('VR','MT'); ('NH') -> ('NH', None)."""
    if "-" in combo:
        tc, bc = combo.split("-")
        return tc, bc
    return combo, None

QNPT = {"T": ("Temperature (K)", lambda r: r["T"], lambda r: r["Terr"]),
        "D": ("Density (g/cm^3)", lambda r: r["D"] / 1000.0, lambda r: r["Derr"] / 1000.0),
        "H": ("Enthalpy (kJ/mol)", lambda r: r["H"], lambda r: r["Herr"])}
QNVT = {"T": ("Temperature (K)", lambda r: r["T"], lambda r: r["Terr"]),
        "Pot": ("Potential energy (kJ/mol)", lambda r: r["Pot"], lambda r: r["Poterr"]),
        "P": ("Pressure (bar)", lambda r: r["P"], lambda r: r["Perr"])}


def load_vanilla():
    rows = []
    for line in (ROOT / "gmx_vanilla2" / "summary_vanilla2.txt").read_text().splitlines():
        p = line.split("\t")
        if len(p) != 11 or p[0] == "run":
            continue

        def f(i):
            try:
                return float(p[i])
            except ValueError:
                return None
        name = p[0]
        ens = "nvt" if name.startswith("nvt_") else "npt"
        sys = "flex" if "flex" in name else "rigid"
        combos = NVT_COMBOS if ens == "nvt" else NPT_COMBOS
        combo = next((c for c in combos if f"_{c.replace('-', '_')}_" in name), None)
        m = re.search(r"dt(\d)p(\d)", name)
        dt = float(f"{m.group(1)}.{m.group(2)}")
        rows.append(dict(scheme="md-vv", ens=ens, sys=sys, combo=combo, dt=dt,
                         T=f(1), Terr=f(2), P=f(3), Perr=f(4), D=f(5), Derr=f(6),
                         H=f(7), Herr=f(8), Pot=f(9), Poterr=f(10)))
    return rows


def load_mid():
    rows = []
    pat = re.compile(r"^(\S+)\s+T=([-\d.]+) Terr=([-\d.]+) P=([-\d.]+) Perr=([-\d.]+)"
                     r" D=([-\d.]+) Derr=([-\d.]+) H=([-\d.]+) Herr=([-\d.]+)"
                     r" Pot=([-\d.]+) Poterr=([-\d.]+)$")
    for line in (ROOT / "mid_final1" / "summary_matrix.txt").read_text().splitlines():
        m = pat.match(line)
        if not m:
            continue
        g = m.groups()
        name = g[0]
        ens = "nvt" if name.startswith("nvt_") else "npt"
        sys = "flex" if "flex" in name else "rigid"
        combos = NVT_COMBOS if ens == "nvt" else NPT_COMBOS
        combo = next((c for c in combos if f"_{c.replace('-', '_')}_" in name), None)
        m2 = re.search(r"dt(\d)p(\d)", name)
        dt = float(f"{m2.group(1)}.{m2.group(2)}")
        v = [float(x) for x in g[1:]]
        rows.append(dict(scheme="middle", ens=ens, sys=sys, combo=combo, dt=dt,
                         T=v[0], Terr=v[1], P=v[2], Perr=v[3], D=v[4], Derr=v[5],
                         H=v[6], Herr=v[7], Pot=v[8], Poterr=v[9]))
    return rows


def plot_panel(runs, ens, sys):
    quals = QNPT if ens == "npt" else QNVT
    combos = NPT_COMBOS if ens == "npt" else NVT_COMBOS
    fig, axes = plt.subplots(1, 3, figsize=(18, 5.6))
    for ax, (key, (ylab, ykey, yerr)) in zip(axes, quals.items()):
        for scheme in ("middle", "md-vv"):
            for combo in combos:
                pts = sorted([r for r in runs if r["ens"] == ens and r["sys"] == sys
                              and r["scheme"] == scheme and r["combo"] == combo],
                             key=lambda r: r["dt"])
                if not pts:
                    continue
                tc, bc = combo_parts(combo)
                ax.errorbar([p["dt"] for p in pts], [ykey(p) for p in pts],
                            yerr=[yerr(p) for p in pts], color=COLORS[tc],
                            ls=LS[scheme], marker=MARKERS[bc], ms=5, lw=1.4,
                            capsize=2.5, capthick=1.2, elinewidth=1.0,
                            label=f"{scheme} {combo}")
        ax.set_xlabel("dt (fs)")
        ax.set_ylabel(ylab)
        ax.set_title(f"{ens.upper()} {sys}: {ylab} vs dt")
        if ylab.startswith("Temperature"):
            ax.set_ylim(297, 303)
        if ylab.startswith("Density") and sys == "rigid":
            ax.set_ylim(0.980, 0.995)
        if ylab.startswith("Density") and sys == "flex":
            ax.set_ylim(1.00, 1.06)
        ax.grid(alpha=0.3)
        ax.legend(loc="best", ncol=1, fontsize=9)
    fig.suptitle(f"GROMACS md-vv vs middle — {ens.upper()} {sys} water"
                 + (" (216 TIP3P, T = 300 K, P = 1 bar)"
                    if ens == "npt" else " (216 TIP3P, T = 300 K, fixed volume)"),
                 y=0.985)
    fig.tight_layout(rect=[0, 0, 1, 0.955])
    fig.savefig(OUT / f"gmx_cmp_{ens}_{sys}_panel.png", dpi=500,
                bbox_inches="tight")
    plt.close(fig)


def main():
    runs = load_vanilla() + load_mid()
    assert len(runs) == 40 + 81, f"expected 121 runs, got {len(runs)}"
    for ens in ("npt", "nvt"):
        for sys in ("flex", "rigid"):
            plot_panel(runs, ens, sys)
    print("wrote:", sorted(str(p) for p in OUT.glob("gmx_cmp*.png")))


if __name__ == "__main__":
    main()
