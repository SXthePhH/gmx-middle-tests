#!/usr/bin/env python3
"""RATTLE-position test (middle scheme): T/P/D vs dt for mid_v9 (ref) vs
mid_v9_rfirst (RATTLE moved first).

NOTE: mid_v9_vv_r2nd (RATTLE second) is an md-vv variant, NOT a middle-scheme
test — excluded here per user (2026-08-19).

Stats over 400-2000 ps from md.edr via gmx energy (mid_v9 binary).
Writes rattle_position_summary.csv and panels into plots_rattle_position/.

The point: relocating the RATTLE (velocity-constraint) step away from its
correct position in the middle splitting produces progressively worse results
as dt grows (T/P/D diverge), while the reference stays flat.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

GMX = "/home/shuaix/PKUresearch/gmx/builds/mid_v9/build/bin/gmx_mpi"
BEGIN = "400"
ROOTS = {
    # reference: complete mid_v9 10 ns rigid suite (middle + SHAKE+RATTLE).
    # (the 2 ns middletest results_middle_rigid_rattle_* refs are truncated
    #  at dt <= 1.0 fs: edr ends ~141 ps, no data past the 400 ps cutoff)
    "ref": ("/home/shuaix/PKUresearch/gmx/tests/mid_v9/results_npt",
            "npt_tip3p_rigid_shake*/md.edr"),
    "rfirst": ("/home/shuaix/PKUresearch/gmx/tests/mid_v9_rfirst/results_npt",
               "npt_tip3p_rigid_shake*/md.edr"),
}
TERMS = ["Temperature", "Pressure", "Density"]
OUT = Path("/home/shuaix/PKUresearch/gmx/tests/plots_rattle_position")
OUT.mkdir(exist_ok=True)

plt.rcParams.update({
    "font.size": 14,
    "axes.labelsize": 15,
    "axes.titlesize": 15,
    "xtick.labelsize": 12,
    "ytick.labelsize": 12,
    "legend.fontsize": 13,
    "figure.titlesize": 22,
})
STYLE = {"ref": dict(ls="-", marker="o", color="#1f77b4", lw=2.4),
         "rfirst": dict(ls="--", marker="s", color="#d62728", lw=2.4)}
LABEL = {"ref": "mid_v9 (ref, 10 ns)", "rfirst": "RATTLE first"}


def stats(edr: Path) -> dict:
    out = {}
    for term in TERMS:
        p = subprocess.run(
            [GMX, "energy", "-f", str(edr), "-b", BEGIN, "-o", "/tmp/ene_tmp.xvg",
             "-xvg", "none"],
            input=f"{term}\n0\n", capture_output=True, text=True,
            env={**os.environ, "GMX_MAXBACKUP": "-1"},
        )
        val = (float("nan"), float("nan"))
        for line in p.stdout.splitlines():
            m = re.match(r"\s*%s\s+(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\s+(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)" % term, line)
            if m:
                val = (float(m.group(1)), float(m.group(2)))
                break
        out[term] = val
    return out


def parse_name(variant, name):
    """-> (dt_fs, tc, pc). All suites share the shape
    ..._dt{XpY}_{TC}[_tau{ZpW}]_{PC}_T300_{2000|10000}ps"""
    m = re.search(r"dt(\d)p(\d)", name)
    dt = float(f"{m.group(1)}.{m.group(2)}")
    rest = name.split("_dt")[1].split("_", 1)[1]
    parts = rest.split("_")  # [LV, tau0p5, CR, T300, 2000ps] or [NH, CR, T300, 2000ps]
    tc = parts[0]
    if tc == "LV":
        pc = parts[2]
    else:
        pc = parts[1]
    return dt, tc, pc


def main():
    rows = []  # (variant, combo, dt, s)
    for variant, (base, pattern) in ROOTS.items():
        for edr in sorted(Path(base).glob(pattern)):
            name = edr.parent.name
            try:
                dt, tc, pc = parse_name(variant, name)
            except Exception:
                continue
            s = stats(edr)
            if tc in ("NH", "LV", "VR") and pc in ("MT", "CR"):
                rows.append((variant, f"{tc}-{pc}", dt, s))
            print(f"[{variant}] {name}: T={s['Temperature'][0]:.1f} P={s['Pressure'][0]:.1f} D={s['Density'][0]:.1f}")

    # CSV
    csv_path = Path("/home/shuaix/PKUresearch/gmx/tests/rattle_position_summary.csv")
    with open(csv_path, "w") as f:
        f.write("# variant: ref=mid_v9 10ns rigid suite; rfirst=mid_v9_rfirst (middle, RATTLE first). Stats 400-2000 ps.\n")
        f.write("variant,combo,dt_fs,T_K,Terr,P_bar,Perr,D_kgm3\n")
        for variant, combo, dt, s in rows:
            t, te = s["Temperature"]; p, pe = s["Pressure"]; d, _ = s["Density"]
            f.write(f"{variant},{combo},{dt},{t:.2f},{te:.2f},{p:.1f},{pe:.1f},{d:.1f}\n")
    print("csv ->", csv_path)

    COMBO_LIST = ("NH-MT", "NH-CR", "LV-MT", "LV-CR")
    TERMS = [("Temperature", "Temperature (K)"),
             ("Pressure", "Pressure (bar)"),
             ("Density", "Density (kg/m^3)")]

    def plot_axis(ax, combo, term, ylab, legend):
        for variant in ("ref", "rfirst"):
            pts = sorted([r for r in rows if r[0] == variant and r[1] == combo],
                         key=lambda r: r[2])
            if not pts:
                continue
            x = [r[2] for r in pts]
            y = [r[3][term][0] for r in pts]
            ax.plot(x, y, **STYLE[variant], label=LABEL[variant])
        ax.axhline(300 if term == "Temperature" else 0, color="gray", ls=":", lw=1)
        ax.set_xlabel("dt (fs)")
        ax.set_ylabel(ylab)
        ax.grid(alpha=0.3)
        if legend:
            ax.legend(loc="best")

    # individual panels: one figure per combo (T, P, D vs dt), curves = ref/rfirst
    for combo in COMBO_LIST:
        fig, axes = plt.subplots(1, 3, figsize=(17, 4.8))
        for ax, (term, ylab) in zip(axes, TERMS):
            plot_axis(ax, combo, term, ylab, True)
            ax.set_title(f"{combo}: {ylab} vs dt")
        fig.suptitle(f"RATTLE position test — {combo} rigid NPT (mid_v9 build)",
                     y=0.99, fontsize=20)
        fig.tight_layout(rect=[0, 0, 1, 0.95])
        fig.savefig(OUT / f"rattle_pos_{combo.replace('-', '_')}_panel.png",
                    dpi=300, bbox_inches="tight")
        plt.close(fig)

    # combined panel: 1 row x 3 quantities; ALL combos and variants inside each subplot
    COMBO_COLOR = {"NH-MT": "#1f77b4", "NH-CR": "#ff7f0e",
                   "LV-MT": "#2ca02c", "LV-CR": "#d62728"}
    VAR_LS = {"ref": "-", "rfirst": "--"}
    VAR_MARK = {"ref": "o", "rfirst": "s"}
    VAR_LABEL = {"ref": "ref", "rfirst": "RATTLE first"}

    fig, axes = plt.subplots(1, 3, figsize=(19, 5.8))
    for ax, (term, ylab) in zip(axes, TERMS):
        for combo in COMBO_LIST:
            for variant in ("ref", "rfirst"):
                pts = sorted([r for r in rows if r[0] == variant and r[1] == combo],
                             key=lambda r: r[2])
                if not pts:
                    continue
                x = [r[2] for r in pts]
                y = [r[3][term][0] for r in pts]
                ax.plot(x, y, ls=VAR_LS[variant], marker=VAR_MARK[variant],
                        color=COMBO_COLOR[combo], lw=2.0, ms=6,
                        label=f"{combo} ({VAR_LABEL[variant]})")
        ax.axhline(300 if term == "Temperature" else 0, color="gray", ls=":", lw=1)
        ax.set_xlabel("dt (fs)")
        ax.set_ylabel(ylab)
        ax.set_title(ylab)
        if term == "Pressure":
            ax.set_yscale("symlog", linthresh=50)  # ref ~0 bar + rfirst up to 3441 bar
        ax.grid(alpha=0.3)
        ax.legend(loc="best", fontsize=9, ncol=2)
    fig.suptitle("RATTLE position test — middle scheme: mid_v9 (ref, solid) vs RATTLE first (dashed)\n"
                 "rigid NPT, 216 TIP3P, T = 300 K, P = 1 bar, stats 400-2000 ps",
                 y=0.99, fontsize=17)
    fig.tight_layout(rect=[0, 0, 1, 0.92])
    fig.savefig(OUT / "rattle_pos_combined_panel.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print("plots ->", sorted(str(p) for p in OUT.glob("*.png")))


if __name__ == "__main__":
    main()
