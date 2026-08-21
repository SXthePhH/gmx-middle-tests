#!/usr/bin/env python3
"""mid_fullrattle vs mid_v4 — LV-only NPT comparison (sampling-point study).

The two variants differ ONLY in where temperature is sampled
(fullrattle: after velocity constraint; mid_v4: end of step after SHAKE).

Data selection (user-approved):
  - LV only (NH not plotted).
  - mid_v4:             original suite, tau-p = 5.0 ps everywhere
  - mid_fullrattle:     ALL runs now at tau-p = 5.0 ps (rigid dt0.5-6.0 +
                        flex dt0.5/1.0/2.0; the small-dt completion runs are done)
So the whole comparison is tau-p matched (5.0 ps).
Unfinished runs are skipped (no partial-data extraction).
Usage: python3 tests/plot_compare_frv4.py
Output: tests/frv4_cmp_{rigid,flex}_npt_panel.png
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import os, subprocess, re, time

OUT     = '/home/shuaix/PKUresearch/gmx/tests'
GMX_FR  = '/home/shuaix/PKUresearch/gmx/builds/mid_fullrattle/build/bin/gmx_mpi'
GMX_V4  = '/home/shuaix/PKUresearch/gmx/builds/mid_v4/build/bin/gmx_mpi'
BASE_FR = '/home/shuaix/PKUresearch/gmx/tests/mid_fullrattle/results_npt'
BASE_V4 = '/home/shuaix/PKUresearch/gmx/tests/mid_v4/results_npt'

TERMS = ['Temperature', 'Density', 'Enthalpy', 'Pressure']
SHORT = {'Temperature': 'T', 'Density': 'D', 'Enthalpy': 'H', 'Pressure': 'P'}
TAG = {0.5: '0p5', 1.0: '1p0', 2.0: '2p0', 4.0: '4p0', 6.0: '6p0'}


def finished(base, name):
    d = os.path.join(base, name)
    log = os.path.join(d, 'md.log')
    return (os.path.exists(os.path.join(d, 'md.edr')) and os.path.exists(log)
            and 'Finished mdrun' in open(log).read())


def extract(edr, gmx, begin=400, retries=6):
    """Run gmx energy; retry on the intermittent MPI shared-memory init failure."""
    env = os.environ.copy()
    env['GMX_MAXBACKUP'] = '-1'
    stdin = '\n'.join(TERMS) + '\n0\n'
    for attempt in range(retries):
        r = subprocess.run([gmx, 'energy', '-f', edr, '-xvg', 'none', '-nmol', '216',
                            '-b', str(begin)],
                           input=stdin, capture_output=True, text=True, env=env)
        data = {}
        for line in r.stdout.strip().split('\n'):
            p = line.split()
            if len(p) >= 3 and re.match(r'^[\d.\-]+$', p[1]):
                data[p[0] + '_avg'] = float(p[1])
                data[p[0] + '_err'] = float(p[2]) if p[2] != '--' else 0.0
        if len(data) >= len(TERMS):
            return data
        time.sleep(1)
    return data


def fr_rigid_name(dt, pc):
    """fullrattle rigid: tau-p=5.0 runs at ALL dt (completion runs now done)."""
    tag = TAG[dt]
    return f'npt_tip3p_rigid_shake_dt{tag}_LV_tau{tag}_taup5p0_{pc}_T300_2000ps'


def fr_flex_name(dt, pc):
    """fullrattle flex: always the tau-p=5.0 runs (dt2.0 done; dt0.5/1.0 pending)."""
    tag = TAG[dt]
    return f'npt_tip3p_flex_dt{tag}_LV_tau{tag}_taup5p0_{pc}_T300_2000ps'


def v4_name(sys, dt, pc):
    """mid_v4: original suite (tau-p = 5.0), no taup suffix in name."""
    tag = TAG[dt]
    if sys == 'rigid':
        return f'npt_tip3p_rigid_shake_dt{tag}_LV_tau{tag}_{pc}_T300_2000ps'
    return f'npt_tip3p_flex_dt{tag}_LV_tau{tag}_{pc}_T300_2000ps'


def load_series(base, gmx, sys, dts, pc, name_fun):
    out = {}
    for dt in dts:
        name = name_fun(dt, pc)
        if not finished(base, name):
            out[dt] = {SHORT[k]: np.nan for k in TERMS} | \
                      {SHORT[k] + 'err': 0.0 for k in TERMS}
            continue
        r = extract(os.path.join(base, name, 'md.edr'), gmx)
        out[dt] = {SHORT[k]: r.get(k + '_avg', np.nan) for k in TERMS} | \
                  {SHORT[k] + 'err': r.get(k + '_err', 0) for k in TERMS}
    return out


dts_rigid = [0.5, 1.0, 2.0, 4.0, 6.0]
dts_flex  = [0.5, 1.0, 2.0]

DATA = {}
for sys, dts in [('rigid', dts_rigid), ('flex', dts_flex)]:
    for pc in ['MT', 'CR']:
        fr_fun = fr_rigid_name if sys == 'rigid' else fr_flex_name
        DATA[(sys, pc, 'fr')] = load_series(BASE_FR, GMX_FR, sys, dts, pc, fr_fun)
        DATA[(sys, pc, 'v4')] = load_series(BASE_V4, GMX_V4, sys, dts, pc,
                                            lambda dt, pc: v4_name(sys, dt, pc))

plt.rcParams.update({'font.size': 12, 'axes.titlesize': 14, 'axes.labelsize': 12,
                     'legend.fontsize': 10, 'figure.dpi': 200, 'savefig.dpi': 500,
                     'savefig.bbox': 'tight'})

COLOR = {'MT': '#1f77b4', 'CR': '#2ca02c'}
LS    = {'fr': '-', 'v4': '--'}

SPECS = [('T', 'Terr', 300, 'Temperature (K)'),
         ('D', 'Derr', None, 'Density (kg/m³)'),
         ('H', 'Herr', None, 'Enthalpy (kJ/mol)'),
         ('P', 'Perr', 1.0, 'Pressure (bar)')]

CAVEAT = 'LV only · tau-p = 5.0 ps both · tau-t LV = 1000 x dt'
NAME = {'fr': 'after RATTLE', 'v4': 'after SHAKE'}


def panel(sys, dts, refD):
    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    for ax, (pkey, ekey, ref, yl) in [
            (axes[0, 0], SPECS[0]), (axes[0, 1], SPECS[1]),
            (axes[1, 0], SPECS[2]), (axes[1, 1], SPECS[3])]:
        if ref:
            ax.axhline(ref, color='gray', ls=':', alpha=0.4)
        for variant in ['fr', 'v4']:
            for pc in ['MT', 'CR']:
                s = DATA[(sys, pc, variant)]
                pts = [(dt, s[dt][pkey], s[dt][ekey]) for dt in dts
                       if not np.isnan(s[dt][pkey])]
                if not pts:
                    continue
                x = [p[0] for p in pts]; y = [p[1] for p in pts]; ye = [p[2] for p in pts]
                ax.errorbar(x, y, yerr=ye, color=COLOR[pc], marker='o', ls=LS[variant],
                            label=f"{NAME[variant]} LV+{pc}", markersize=5,
                            linewidth=1.4, capsize=3)
        ax.set(xlabel='dt (fs)', ylabel=yl, title=f'{sys} NPT: {yl}')
        ax.legend(fontsize=9, ncol=2)
        ax.grid(alpha=0.3)
        if yl.startswith('Temperature'):
            ax.set_ylim(296, 304)
        if yl.startswith('Density'):
            ax.set_ylim(refD - 6, refD + 12)
    fig.suptitle(f'{NAME["fr"]} vs {NAME["v4"]} — LV NPT {sys} (216 TIP3P, T=300 K, P=1 bar)\n'
                 f'{CAVEAT}', fontsize=12)
    fig.tight_layout(rect=[0, 0, 1, 0.94])
    fig.savefig(os.path.join(OUT, f'frv4_cmp_{sys}_npt_panel.png'))
    plt.close(fig)


panel('rigid', dts_rigid, 984)
panel('flex',  dts_flex,  1010)

print('wrote:', sorted(f for f in os.listdir(OUT) if f.startswith('frv4_cmp_')))
print('flex dt2 LV+MT T fr/v4:', DATA[('flex', 'MT', 'fr')][2.0]['T'],
      DATA[('flex', 'MT', 'v4')][2.0]['T'])
print('flex dt0.5 LV+MT T fr/v4:', DATA[('flex', 'MT', 'fr')][0.5]['T'],
      DATA[('flex', 'MT', 'v4')][0.5]['T'])
