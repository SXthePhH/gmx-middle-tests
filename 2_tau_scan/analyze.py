#!/usr/bin/env python3
"""Analyze the mid_final1 tau scan summary."""
import re

ROOT = '/home/shuaix/PKUresearch/gmx/tests/tau_scan'
DATA = {}
with open(f'{ROOT}/summary_tau_scan.txt') as f:
    for line in f:
        m = re.match(r'^(\S+)\s+T=(\S+) Terr=(\S+) P=(\S+) Perr=(\S+)'
                     r' D=(\S+) Derr=(\S+) H=(\S+) Herr=(\S+)'
                     r' Pot=(\S+) Poterr=(\S+)$', line)
        if not m:
            continue
        name, g = m.group(1), [float(x) for x in m.groups()[1:]]
        mm = re.match(r'(npt|nvt)_tip3p_(rigid_shake|flex)_dt(\d)p(\d)_(VR|NH|LV)'
                      r'(?:_(\w+))?_taut(\d+)_taup(\d+)_T300_2000ps', name)
        ens, sys, tc = mm.group(1), mm.group(2), mm.group(5)
        pc = mm.group(6) or '-'
        taut, taup = int(mm.group(7)), int(mm.group(8))
        DATA[(ens, sys, tc, pc, taut, taup)] = dict(T=g[0], Terr=g[1], P=g[2], Perr=g[3],
                                                    D=g[4], Derr=g[5], H=g[6], Herr=g[7],
                                                    Pot=g[8], Poterr=g[9])

def grid(ens, sys, tc, pc, tauts, taup, key, fmt):
    print(f"  {ens.upper()} {sys} {tc}+{pc}: {key} (rows tau-t {tauts[0]}/{tauts[1]}/{tauts[2]}, cols tau-p {taup[0]}/{taup[1]}/{taup[2]})")
    for t in tauts:
        vals = [DATA[(ens, sys, tc, pc, t, p)][key] for p in taup]
        print("    taut%4d  " % t + "  ".join(fmt(v) for v in vals))
    print()

print("=" * 70)
print("RIGID dt6.0 NPT — T (K), target 300")
print("=" * 70)
for tc in ['VR', 'NH', 'LV']:
    for pc in ['MT', 'CR']:
        grid('npt', 'rigid_shake', tc, pc, [500, 1000, 2000], [1000, 2000, 4000], 'T', "{:7.2f}".format)

print("=" * 70)
print("RIGID dt6.0 NPT — P (bar), target 1")
print("=" * 70)
for tc in ['VR', 'NH', 'LV']:
    for pc in ['MT', 'CR']:
        grid('npt', 'rigid_shake', tc, pc, [500, 1000, 2000], [1000, 2000, 4000], 'P', "{:7.1f}".format)

print("=" * 70)
print("FLEX dt2.0 NPT — T (K), target 300")
print("=" * 70)
for tc in ['VR', 'NH', 'LV']:
    for pc in ['MT', 'CR']:
        grid('npt', 'flex', tc, pc, [250, 500, 1000], [1000, 2000, 4000], 'T', "{:7.2f}".format)

print("=" * 70)
print("FLEX dt2.0 NPT — P (bar), target 1")
print("=" * 70)
for tc in ['VR', 'NH', 'LV']:
    for pc in ['MT', 'CR']:
        grid('npt', 'flex', tc, pc, [250, 500, 1000], [1000, 2000, 4000], 'P', "{:7.1f}".format)

print("=" * 70)
print("NVT — T (K), target 300 (tau-p is a no-op; show taut rows, mean over taup)")
print("=" * 70)
for sys, tauts in [('rigid_shake', [500, 1000, 2000]), ('flex', [250, 500, 1000])]:
    for tc in ['VR', 'NH', 'LV']:
        print(f"  NVT {sys} {tc}: ", end="")
        for t in tauts:
            vals = [DATA[('nvt', sys, tc, '-', t, p)]['T'] for p in [1000, 2000, 4000]]
            print(f"taut{t}={sum(vals)/3:6.2f}  ", end="")
        print()
print()

print("=" * 70)
print("DENSITY check — rigid target ~984-985, flex target ~1009-1010 (NPT, mean over grid)")
print("=" * 70)
for sys, ref in [('rigid_shake', 984.5), ('flex', 1010)]:
    for tc in ['VR', 'NH', 'LV']:
        for pc in ['MT', 'CR']:
            tauts = [500, 1000, 2000] if sys == 'rigid_shake' else [250, 500, 1000]
            Ds = [DATA[('npt', sys, tc, pc, t, p)]['D'] for t in tauts for p in [1000, 2000, 4000]]
            print(f"  NPT {sys} {tc}+{pc}: D mean={sum(Ds)/len(Ds):7.1f}  min={min(Ds):7.1f}  max={max(Ds):7.1f}  (ref {ref})")

print()
print("=" * 70)
print("WORST DEVIATIONS (|T-300| > 1 K or |P| > 100 bar or D far from ref)")
print("=" * 70)
for (ens, sys, tc, pc, t, p), v in sorted(DATA.items()):
    refD = 984.5 if sys == 'rigid_shake' else 1010
    bad = []
    if abs(v['T'] - 300) > 1: bad.append(f"T={v['T']:.1f}")
    if ens == 'npt' and abs(v['P']) > 100: bad.append(f"P={v['P']:.0f}")
    if ens == 'npt' and abs(v['D'] - refD) > 12: bad.append(f"D={v['D']:.0f}")
    if bad:
        print(f"  {ens} {sys} {tc}+{pc} taut{t} taup{p}: " + ", ".join(bad))
