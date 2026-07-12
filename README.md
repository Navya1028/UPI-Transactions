# UPI Transactions Dashboard

End-to-end Power BI dashboard built on a real 20,000-row UPI transactions
dataset — hand-built star schema, a role-playing dimension, DAX time
intelligence, and rule-based anomaly detection (after testing and correctly
ruling out a statistical approach that didn't fit the data).

## Dashboard preview

> Replace these with your actual exported screenshots — see "Exporting
> screenshots" below.

### Executive Overview
![Overview](screenshots/page1_overview.png)

### Spending Patterns
![Spending](screenshots/page2_spending.png)

### Anomaly & Data Quality
![Anomaly](screenshots/page3_anomaly.png)

### Bank Flow & Trends
![Bank Flow](screenshots/page4_bankflow.png)

## What this project does

Starting from a single flat Excel export of UPI transactions, this project:

1. **Profiles the raw data first** — checks distribution shape, cardinality,
   and data quality before deciding how to model or analyze it
2. **Builds a star schema by hand** in Power Query — one fact table plus
   `dim_date` and `dim_bank`, including a genuine role-playing dimension
   (the bank table is referenced twice: sender and receiver)
3. **Tests anomaly-detection approaches against the actual data** — a
   Z-score method was tried and found inapplicable (amounts are uniformly
   distributed, confirmed via SQL), so a rule-based signal was used instead
4. **Surfaces a real data-quality issue** (75% of "UPI" transactions carry
   non-INR currency values) as a live dashboard KPI instead of hiding it
5. **Implements 20+ DAX measures** covering time intelligence (MTD, MoM),
   the role-playing dimension (`USERELATIONSHIP`), and anomaly tracking

## Key technical decisions

| Decision | Why |
|---|---|
| Only `dim_date` and `dim_bank` as separate dimension tables | `CustomerAccountNumber` / `MerchantAccountNumber` are unique per row — no repeat customers exist, so a customer/merchant dimension would misrepresent the data |
| Rule-based anomaly flag instead of Z-score | Amount is uniformly distributed (tested and confirmed) — a statistical outlier method finds nothing on this data by construction |
| `dim_bank` used twice via role-playing dimension | `BankNameSent` and `BankNameReceived` share the same 4 banks — one small lookup table serves both roles via an active + inactive relationship |
| Currency flagged, not cleaned | A UPI feed should be 100% INR; silently converting or deleting the other 75% would hide a real data-quality problem |

## Debugging notes (real issues hit while building this)

- **Circular reference** when building `dim_bank` via Power Query's
  Reference feature — fixed by using Duplicate instead, which breaks the
  live dependency on the source query
- **Date table gaps** — a `dim_date` built by deduplicating transaction
  dates was missing calendar days with zero transactions, which fails
  Power BI's "Mark as date table" validation; rebuilt with DAX `CALENDAR()`
  to guarantee a complete, gap-free sequence
- **"100% failure rate" on every bank** — traced (by isolating the measure
  in a blank card, then inspecting the report's underlying JSON) to an
  incorrectly selected visual type (100% Stacked Bar Chart normalizes every
  bar to its own total), not a DAX or data bug

## Tech stack

SQL (SQLite, for query design/testing) · Power BI Desktop · DAX · Power Query (M)

## Repository contents

```
├── UPI_Transactions_Dashboard.pbix   — the Power BI report
├── UPI_Transactions_Dashboard.pdf    — static export of all 4 pages
├── screenshots/                      — page-by-page images
├── sql/
│   ├── 01_schema.sql                 — star schema DDL
│   └── 02_analysis_queries.sql       — 23 tested analysis queries
├── dax/
│   └── measures.txt                  — full DAX measures library
└── docs/
    └── UPI_Transactions_Dashboard_Project.docx  — full project writeup
```

## Data source

Dataset structure based on a UPI transactions export (20,000 rows, calendar
year 2024). All figures shown in the dashboard are computed directly from
this file — none are estimated or fabricated.

## Exporting screenshots (before you upload)

1. In Power BI Desktop, open each page and resize the window cleanly
2. `File → Export → Export to PDF` for a full-report PDF, or use
   Windows Snipping Tool (`Win+Shift+S`) per page for individual PNGs
3. Save as `page1_overview.png`, `page2_spending.png`,
   `page3_anomaly.png`, `page4_bankflow.png` in a `screenshots/` folder
