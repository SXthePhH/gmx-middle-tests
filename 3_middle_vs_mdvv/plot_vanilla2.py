#!/usr/bin/env python3
"""Plot the gmx_vanilla2 suite (vanilla md-vv, 49 runs, 2026-08-18).

Style mirrors the LAMMPS comparison plots (500 dpi, large fonts, fixed T range).
Flex and rigid are SEPARATE figures; each figure plots ALL coupling combos
together (no delta/comparison plots).

NPT: Temperature / Density / Enthalpy vs dt
NVT: Temperature / Potential energy / Pressure vs dt
"""
import os
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = Path("/home/shuaix/PKUresearch/gmx/tests/gmx_vanilla2")
OUT = BASE / "plots_vanilla2"
OUT.mkdir(exist_ok=True)

plt.rcParams.update({
    "font.size": 15,
    "axes.labelsize": 16,
    "axes.titlesize": 16,
    "xtick.labelsize": 14,
    "ytick.labelsize": 14,
    "legend.fontsize": 16,
    "figure.titlesize": 24,
})

COMBOS = {
    "npt": ["VR-CR", "NH-CR", "NH-MT"],
    "nvt": ["NH", "VR"],
}
COLORS = {"VR-CR": "#1f77b4", "NH-CR": "#2ca02c",
          "NH-MT": "#d62728", "NH": "#1f77b4", "VR": "#d62728"}

QNPT = {"T": ("Temperature (K)", lambda r: r["T"], lambda r: r["Terr"]),
        "D": ("Density (g/cm^3)", lambda r: r["D"] / 1000.0, lambda r: r["Derr"] / 1000.0),
        "H": ("Enthalpy (kJ/mol)", lambda r: r["H"], lambda r: r["Herr"])}
QNVT = {"T": ("Temperature (K)", lambda r: r["T"], lambda r: r["Terr"]),
        "Pot": ("Potential energy (kJ/mol)", lambda r: r["Pot"], lambda r: r["Poterr"]),
        "P": ("Pressure (bar)", lambda r: r["P"], lambda r: r["Perr"])}


def load():
    rows = []
    for line in (BASE / "summary_vanilla2.txt").read_text().splitlines():
        p = line.split("\t")
        if len(p) != 11 or p[0] == "run":
            continue

        def f(i):
            try:
                return float(p[i])
            except ValueError:
                return None
        name = p[0]
        if name.startswith("nvt_"):
            ens, sys = "nvt", "flex" if "flex" in name else "rigid"
        else:
            ens, sys = "npt", "flex" if "flex" in name else "rigid"
        combo = None
        for c in COMBOS[ens]:
            if f"_{c.replace('-', '_')}_" in name or name.endswith(f"_{c.replace('-', '_')}_tau"):
                combo = c
        if combo is None:  # nvt names end with _tauX
            for c in COMBOS[ens]:
                if f"_{c}_" in name:
                    combo = c
        import re
        m = re.search(r"dt(\d)p(\d)", name)
        dt = float(f"{m.group(1)}.{m.group(2)}")
        rows.append(dict(ens=ens, sys=sys, combo=combo, dt=dt,
                         T=f(1), Terr=f(2), P=f(3), Perr=f(4),
                         D=f(5), Derr=f(6), H=f(7), Herr=f(8),
                         Pot=f(9), Poterr=f(10)))
    return rows


def series(runs, ens, sys, combo):
    return sorted([r for r in runs if r["ens"] == ens and r["sys"] == sys
                   and r["combo"] == combo], key=lambda r: r["dt"])


def plot_panel(runs, ens, sys):
    quals = QNPT if ens == "npt" else QNVT
    fig, axes = plt.subplots(1, 3, figsize=(18, 5.6))
    for ax, (key, (ylab, ykey, yerr)) in zip(axes, quals.items()):
        for combo in COMBOS[ens]:
            pts = series(runs, ens, sys, combo)
            if not pts:
                continue
            x = [p["dt"] for p in pts]
            y = [ykey(p) for p in pts]
            ye = [yerr(p) for p in pts]
            if all(v is None for v in y):
                continue
            ax.errorbar(x, y, yerr=ye, color=COLORS[combo], marker="o", ms=5.5,
                        lw=1.5, capsize=2.5, capthick=1.2, elinewidth=1.0,
                        label=f"md-vv {combo}")
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
    fig.suptitle(f"GROMACS vanilla md-vv — {ens.upper()} {sys} water"
                 + (" (216 TIP3P, T = 300 K, P = 1 bar)"
                    if ens == "npt" else " (216 TIP3P, T = 300 K, fixed volume)"),
                 y=0.985)
    fig.tight_layout(rect=[0, 0, 1, 0.955])
    fig.savefig(OUT / f"gmxv2_{ens}_{sys}_panel.png", dpi=500,
                bbox_inches="tight")
    plt.close(fig)


def main():
    runs = load()
    assert len(runs) == 40, f"expected 40 runs, got {len(runs)}"
    for ens in ("npt", "nvt"):
        for sys in ("flex", "rigid"):
            plot_panel(runs, ens, sys)
    print("wrote:", sorted(str(p) for p in OUT.glob("*.png")))


if __name__ == "__main__":
    main()
