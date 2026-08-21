# 1. Sampling point: after SHAKE vs after RATTLE（采样位置对比）

**目的**：两个只有采样点不同的 middle 变体在匹配条件下的对比——
`mid_fullrattle`（采样在速度约束 RATTLE 之后）vs `mid_v4`（采样在
步末 SHAKE 之后）。仅 Langevin，tau-p = 5.0 ps 两侧一致（tau-matched）。

**数据**（`data/frv4_comparison.csv`，32 行）：rigid dt 0.5–6.0 /
flex dt 0.5–2.0 × LV+MT/LV+CR，两变体的 T/P/D/H（mean ± Err.Est.），
`gmx energy -b 400 -nmol 216` 提取。

**复现**：
1. `input/` 4 个 launcher（fullrattle：npt 主矩阵 + rigid taup5 +
   flex taup5；v4：npt 主矩阵）+ `common/run_md_shake.sh` +
   `common/em_tip3p.gro`，配 `mid_fullrattle` / `mid_v4` 二进制，
   生成两侧 `results_npt/`；
2. 运行 `plot_compare_frv4.py` 重新提取并生成 `plots/` 两张面板。

**结论**：大 dt 时采样点影响显著——after RATTLE 在 rigid dt 6 仍保持
300 ± 0.6 K，after SHAKE 漂到 ~302 K（见面板与 csv）。
