# 3. Middle vs md-vv（middle 与 vanilla md-vv 对比）

**目的**：`mid_final1`（81 组）与 vanilla md-vv（`gmx_vanilla2`，40 组）
的完整对比，覆盖 NPT/NVT × rigid/flex × dt 扫描（2026-08-18 测试规则，
每组 9 个 dt）。

**数据**（`data/`）：
- `summary_matrix.txt`：mid_final1 81 组 T/P/D/H/Pot（mean ± Err.Est.）
- `summary_vanilla2.txt`：md-vv 40 组，同格式

**复现**：
1. `input/vanilla2_launch_all.sh` + `common/run_md_shake.sh`/`run_nvt.sh`，
   配 `gmx_vanilla` 二进制 → md-vv 结果；`input/vanilla2_extract.sh` →
   `summary_vanilla2.txt`；
2. `input/mid_final1_launch_matrix.sh`，配 `mid_final1` 二进制 → 81 组；
   `input/mid_final1_summary_results.sh` → `summary_matrix.txt`；
3. `plot_vanilla2.py` / `plot_mid_final1.py` / `plot_gmx_compare.py` →
   `plots/` 12 张面板。

**关键结论**：flex dt2 只有 Langevin 密度正确（~1010，平坦），
v-rescale/NH 爬升到 1022–1033；rigid 全 dt 稳定（NH+MT P ±5 bar）。
