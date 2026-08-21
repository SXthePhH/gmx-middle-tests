# 0. RATTLE position tests（RATTLE 位置约束测试）

**目的**：检查 middle 方案中 RATTLE 速度约束与位置约束的一致性——对比
`mid_v9`（参考，SHAKE+RATTLE）与 `mid_v9_rfirst`（middle 顺序中 RATTLE
前置）在刚性水下的 T/P/D 统计。

**数据**（`data/rattle_position_summary.csv`）：从两套 rigid NPT 结果
（`mid_v9/results_npt`、`mid_v9_rfirst/results_npt`，dt 0.5–6.0 fs ×
LV/NH × MT/CR）用 `gmx energy -b 400 -nmol 216` 提取，统计窗 400–2000 ps。

**复现**：
1. 用 `input/` 两个 launcher + `common/run_md_shake.sh` +
   `common/em_tip3p.gro`，分别配 `mid_v9` / `mid_v9_rfirst` 二进制，
   跑 rigid NPT 套件（2000 ps、T=300 K、P=1 bar、nstout 500）；
2. 运行 `plot_rattle_position.py` 重新生成 csv 与 `plots/` 面板。

**面板**：combined + NH/LV × MT/CR 共 5 张。
