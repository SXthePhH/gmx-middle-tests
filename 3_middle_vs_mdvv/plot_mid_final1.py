#!/usr/bin/env python3
"""Plot the mid_final1 matrix (middle integrator, 81 runs, 2026-08-18).

Same style as the gmx_vanilla2 panels (500 dpi, large fonts, fixed T range).
Flex and rigid are SEPARATE figures; each figure plots ALL coupling combos
together.

NPT (6 combos): Temperature / Density / Enthalpy vs dt
NVT (3 combos): Temperature / Potential energy / Pressure vs dt
"""
import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = Path("/home/shuaix/PKUresearch/gmx/tests/mid_final1")
OUT = BASE / "plots_mid_final1"
OUT.mkdir(exist_ok=True)

plt.rcParams.update({
    "font.size": 15,
    "axes.labelsize": 16,
    "axes.titlesize": 16,
    "xtick.labelsize": 14,
    "ytick.labelsize": 14,
    "legend.fontsize": 15,
    "figure.titlesize": 24,
})

NPT_COMBOS = ["VR-MT", "VR-CR", "LV-MT", "LV-CR", "NH-MT", "NH-CR"]
NVT_COMBOS = ["VR", "LV", "NH"]
COLORS = {"VR-MT": "#1f77b4", "VR-CR": "#ff7f0e", "LV-MT": "#2ca02c",
          "LV-CR": "#d62728", "NH-MT": "#9467bd", "NH-CR": "#8c564b",
          "VR": "#1f77b4", "LV": "#2ca02c", "NH": "#9467bd"}

QNPT = {"T": ("Temperature (K)", lambda r: r["T"], lambda r: r["Terr"]),
        "D": ("Density (g/cm^3)", lambda r: r["D"] / 1000.0, lambda r: r["Derr"] / 1000.0),
        "H": ("Enthalpy (kJ/mol)", lambda r: r["H"], lambda r: r["Herr"])}
QNVT = {"T": ("Temperature (K)", lambda r: r["T"], lambda r: r["Terr"]),
        "Pot": ("Potential energy (kJ/mol)", lambda r: r["Pot"], lambda r: r["Poterr"]),
        "P": ("Pressure (bar)", lambda r: r["P"], lambda r: r["Perr"])}


def load():
    rows = []
    for line in (BASE / "summary_matrix.txt").read_text().splitlines():
        m = re.match(r"^(\S+)\s+T=([-\d.]+) Terr=([-\d.]+) P=([-\d.]+) Perr=([-\d.]+) D=([-\d.]+) Derr=([-\d.]+) H=([-\d.]+) Herr=([-\d.]+) Pot=([-\d.]+) Poterr=([-\d.]+)$", line)
        if not m:
            continue
        name, T, Terr, P, Perr, D, Derr, H, Herr, Pot, Poterr = m.groups()
        if name.startswith("nvt_"):
            ens, sys = "nvt", "flex" if "flex" in name else "rigid"
        else:
            ens, sys = "npt", "flex" if "flex" in name else "rigid"
        combos = NVT_COMBOS if ens == "nvt" else NPT_COMBOS
        combo = next((c for c in combos if f"_{c.replace('-', '_')}_" in name), None)
        m2 = re.search(r"dt(\d)p(\d)", name)
        dt = float(f"{m2.group(1)}.{m2.group(2)}")
        rows.append(dict(ens=ens, sys=sys, combo=combo, dt=dt,
                         T=float(T), Terr=float(Terr), P=float(P), Perr=float(Perr),
                         D=float(D), Derr=float(Derr), H=float(H), Herr=float(Herr),
                         Pot=float(Pot), Poterr=float(Poterr)))
    return rows


def series(runs, ens, sys, combo):
    return sorted([r for r in runs if r["ens"] == ens and r["sys"] == sys
                   and r["combo"] == combo], key=lambda r: r["dt"])


def plot_panel(runs, ens, sys):
    quals = QNPT if ens == "npt" else QNVT
    combos = NPT_COMBOS if ens == "npt" else NVT_COMBOS
    fig, axes = plt.subplots(1, 3, figsize=(18, 5.6))
    for ax, (key, (ylab, ykey, yerr)) in zip(axes, quals.items()):
        for combo in combos:
            pts = series(runs, ens, sys, combo)
            if not pts:
                continue
            ax.errorbar([p["dt"] for p in pts], [ykey(p) for p in pts],
                        yerr=[yerr(p) for p in pts], color=COLORS[combo],
                        marker="o", ms=5.5, lw=1.5, capsize=2.5, capthick=1.2,
                        elinewidth=1.0, label=f"middle {combo}")
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
        ax.legend(loc="best")
    fig.suptitle(f"GROMACS middle (mid_final1) — {ens.upper()} {sys} water"
                 + (" (216 TIP3P, T = 300 K, P = 1 bar)"
                    if ens == "npt" else " (216 TIP3P, T = 300 K, fixed volume)"),
                 y=0.985)
    fig.tight_layout(rect=[0, 0, 1, 0.955])
    fig.savefig(OUT / f"midf1_{ens}_{sys}_panel.png", dpi=500,
                bbox_inches="tight")
    plt.close(fig)


def main():
    runs = load()
    assert len(runs) == 81, f"expected 81 runs, got {len(runs)}"
    for ens in ("npt", "nvt"):
        for sys in ("flex", "rigid"):
            plot_panel(runs, ens, sys)
    print("wrote:", sorted(str(p) for p in OUT.glob("*.png")))


if __name__ == "__main__":
    main()
