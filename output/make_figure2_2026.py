"""Figure 2: EU and euro-area losses as a share of GVA by hazard, 2026 and 2030,
with 90% confidence intervals.

Reads the Stata outputs in output_2026/, writes the figure's source data
(fig_gva_shares_2026.csv) and the figure itself as published
(fig_gva_shares_2026.png/.pdf, included in the manuscript as Estimates2026.png).
"""
import pathlib

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.lines import Line2D
from matplotlib.ticker import FuncFormatter

OUT = pathlib.Path(__file__).parent / "output_2026"
Y0, Y1 = 2026, 2030

# ----------------------------------------------------------------- source data
ra = pd.read_stata(OUT / "ready_analysis_2026.dta")
GVA = {"EU": ra.EU27_GVA_2025.iloc[0], "EZ": ra.EZ_GVA_2025.iloc[0]}

HAZ = [("Heatwave", "hw", "heatwaves2026_{}_2C_CI.xlsx"),
       ("Drought", "dr", "droughts2026_{}_CI.xlsx"),
       ("Flood", "fl", "floods2026_{}_CI.xlsx")]
AREA = {"EZ": "eurozone", "EU": "europe"}

rows = []
for hz, pre, tmpl in HAZ:
    for area, fname in AREA.items():
        x = pd.read_excel(OUT / tmpl.format(fname)).iloc[0]
        for y in (Y0, Y1):
            lo, hi = sorted([x[f"{pre}_loss_cum_lo_{y}"], x[f"{pre}_loss_cum_hi_{y}"]])
            rows.append(dict(hazard=hz, area=area, year=y,
                             share=x[f"{area}_{pre}_pct_total_{y}"],
                             lo=lo / GVA[area] * 100, hi=hi / GVA[area] * 100))
d = pd.DataFrame(rows)
d.round(3).to_csv(OUT / "fig_gva_shares_2026.csv", index=False)

# --------------------------------------------------------------------- figure
# colour = year, marker = area (filled circle euro area, hollow diamond EU)
HZ = ["Heatwave", "Drought", "Flood"]
YCOL = {Y0: "#F4A259", Y1: "#9E2A2B"}
POS = [("EZ", Y0, -0.30), ("EU", Y0, -0.12), ("EZ", Y1, 0.12), ("EU", Y1, 0.30)]
MINUS = "−"


def fmt(v):
    return f"{v:.2f}".replace("-", MINUS)


plt.rcParams.update({"font.family": "serif", "font.size": 12,
                     "axes.edgecolor": "#444444"})
fig, ax = plt.subplots(figsize=(10, 5.8), dpi=250)

for i in range(len(HZ)):
    if i % 2 == 0:
        ax.axvspan(i - 0.5, i + 0.5, color="#F3F3F3", zorder=0, lw=0)
ax.axhline(0, color="#444444", lw=1, zorder=1)

for area, y, off in POS:
    s = d[(d.area == area) & (d.year == y)].set_index("hazard").loc[HZ]
    for i, hz in enumerate(HZ):
        r = s.loc[hz]
        x = i + off
        if area == "EZ":
            ax.vlines(x, r.lo, r.hi, color=YCOL[y], lw=3.2, zorder=2)
            ax.plot(x, r.share, marker="o", ms=9, color=YCOL[y], mec="white",
                    mew=1.2, zorder=3)
        else:
            ax.errorbar(x, r.share, yerr=[[r.share - r.lo], [r.hi - r.share]],
                        fmt="none", ecolor=YCOL[y], elinewidth=1.4, capsize=5,
                        capthick=1.4, zorder=2)
            ax.plot(x, r.share, marker="D", ms=8, mfc="white", mec=YCOL[y],
                    mew=2.2, zorder=3)
        below = (r.hi - r.lo) < 0.15      # label under the whisker when it is short
        ax.annotate(fmt(r.share), (x, r.lo if below else r.share),
                    xytext=(0, -9) if below else (7 if area == "EZ" else 10, 0),
                    textcoords="offset points",
                    ha="center" if below else "left",
                    va="top" if below else "center",
                    fontsize=9, color="#333333", zorder=4)

ax.set_xticks(range(len(HZ)), HZ, fontsize=13)
ax.tick_params(axis="x", length=0, pad=8)
ax.set_xlim(-0.5, len(HZ) - 0.5)
ax.set_ylim(min(-1.0, (d.lo.min() // 0.25) * 0.25), 0.15)
ax.yaxis.set_major_formatter(FuncFormatter(
    lambda v, _: (f"{v:.1f}".replace("-", MINUS) + "%") if v else "0"))
ax.grid(axis="y", linestyle=(0, (3, 3)), color="#CCCCCC", lw=0.8, zorder=0)
ax.set_axisbelow(True)
ax.set_ylabel("Cumulative loss as share of GVA")
ax.spines[["top", "right", "bottom"]].set_visible(False)

legend = [Line2D([], [], color=YCOL[Y0], lw=3.2, marker="o", ms=9, mec="white",
                 mew=1.2, label=f"Euro area {Y0}"),
          Line2D([], [], color=YCOL[Y0], lw=1.4, marker="D", ms=8, mfc="white",
                 mew=2.2, label=f"EU {Y0}"),
          Line2D([], [], color=YCOL[Y1], lw=3.2, marker="o", ms=9, mec="white",
                 mew=1.2, label=f"Euro area {Y1}"),
          Line2D([], [], color=YCOL[Y1], lw=1.4, marker="D", ms=8, mfc="white",
                 mew=2.2, label=f"EU {Y1}"),
          Line2D([], [], color="#555555", lw=2, label="90% CI")]
ax.legend(handles=legend, loc="upper center", bbox_to_anchor=(0.5, -0.07), ncol=5,
          frameon=False, handletextpad=0.5, columnspacing=1.8)

fig.tight_layout()
for ext in ("png", "pdf"):
    fig.savefig(OUT / f"fig_gva_shares_2026.{ext}", bbox_inches="tight")
plt.close(fig)
print("wrote fig_gva_shares_2026.csv, .png and .pdf")
