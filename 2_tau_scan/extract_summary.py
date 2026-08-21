#!/usr/bin/env python3
"""Extract and summarize the 162-run mid_final1 tau scan.

Reads each finished run's md.edr via gmx energy (-b 400, -nmol 216),
writes summary_tau_scan.txt (same format as mid_final1/summary_matrix.txt)
and prints an analysis table grouped by (ensemble, system, combo).
"""
import re, os, subprocess, sys, time

ROOT = '/home/shuaix/PKUresearch/gmx/tests/tau_scan'
GMX  = '/home/shuaix/PKUresearch/gmx/builds/mid_final1/build/bin/gmx_mpi'
TERMS = ['Temperature', 'Pressure', 'Density', 'Enthalpy', 'Potential']

def extract(edr, retries=6):
    env = os.environ.copy(); env['GMX_MAXBACKUP'] = '-1'
    stdin = '\n'.join(TERMS) + '\n0\n'
    for _ in range(retries):
        r = subprocess.run([GMX, 'energy', '-f', edr, '-xvg', 'none', '-nmol', '216',
                            '-b', '400'], input=stdin, capture_output=True, text=True, env=env)
        data = {}
        for line in r.stdout.splitlines():
            p = line.split()
            if len(p) >= 3 and re.match(r'^[\d.\-]+$', p[1]):
                data[p[0] + '_avg'] = float(p[1])
                data[p[0] + '_err'] = float(p[2]) if p[2] != '--' else 0.0
        if len(data) >= len(TERMS):
            return data
        time.sleep(1)
    return {}

def parse(name):
    # npt_tip3p_flex_dt2p0_VR_MT_taut250_taup1000_T300_2000ps
    m = re.match(r'(npt|nvt)_tip3p_(rigid_shake|flex)_dt(\d)p(\d)_(VR|NH|LV)(?:_(\w+))?_taut(\d+)_taup(\d+)_T300_2000ps', name)
    if not m:
        return None
    ens, sys, d1, d2, tc, pc, taut, taup = (m.group(1), m.group(2), m.group(3),
                                            m.group(4), m.group(5), m.group(6) or '-',
                                            m.group(7), m.group(8))
    dt = float(f"{d1}.{d2}")
    return dict(ens=ens, sys=sys, dt=dt, tc=tc, pc=pc, taut=int(taut), taup=int(taup))

rows = []
for base in ['results_npt_tau', 'results_nvt_tau']:
    for d in sorted(os.listdir(os.path.join(ROOT, base))):
        full = os.path.join(ROOT, base, d)
        if not os.path.isdir(full):
            continue
        log = os.path.join(full, 'md.log')
        if not (os.path.exists(os.path.join(full, 'md.edr')) and os.path.exists(log)
                and 'Finished mdrun' in open(log).read()):
            print(f"[skip unfinished] {d}", file=sys.stderr)
            continue
        r = extract(os.path.join(full, 'md.edr'))
        if not r:
            print(f"[extract failed] {d}", file=sys.stderr)
            continue
        p = parse(d)
        if p is None:
            print(f"[parse failed] {d}", file=sys.stderr)
            continue
        rows.append((d, p, r))

# write summary
with open(os.path.join(ROOT, 'summary_tau_scan.txt'), 'w') as f:
    for name, p, r in rows:
        f.write(f"{name}  T={r.get('Temperature_avg', float('nan')):.3f} "
                f"Terr={r.get('Temperature_err', 0):.3f} "
                f"P={r.get('Pressure_avg', float('nan')):.2f} "
                f"Perr={r.get('Pressure_err', 0):.2f} "
                f"D={r.get('Density_avg', float('nan')):.2f} "
                f"Derr={r.get('Density_err', 0):.2f} "
                f"H={r.get('Enthalpy_avg', float('nan')):.4f} "
                f"Herr={r.get('Enthalpy_err', 0):.4f} "
                f"Pot={r.get('Potential_avg', float('nan')):.4f} "
                f"Poterr={r.get('Potential_err', 0):.4f}\n")

print(f"extracted {len(rows)}/162 runs -> {ROOT}/summary_tau_scan.txt")
