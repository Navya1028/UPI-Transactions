/* =========================================================
   UPI TRANSACTIONS DASHBOARD — ANALYSIS QUERY LIBRARY
   Built against the real UPI_Transactions.xlsx star schema.
   Sections: Data Quality, Spending Patterns, Anomaly
   Signals, Time-Series, Operational Health.
   ========================================================= */

-- =========================================================
-- SECTION 0: DATA QUALITY CHECKS (run these first)
-- =========================================================

-- 0.1 Currency mix — flags that this "UPI" dataset carries non-INR values
SELECT currency, COUNT(*) AS txn_count, ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM fact_transactions),2) AS pct
FROM fact_transactions
GROUP BY currency
ORDER BY txn_count DESC;

-- 0.2 Uniform-distribution check — confirms categories are evenly split (signals templated/demo data)
SELECT purpose, COUNT(*) AS txn_count FROM fact_transactions GROUP BY purpose;

-- 0.3 Amount-exceeds-balance flag rate (built-in anomaly pattern in this dataset)
SELECT amount_exceeds_balance, COUNT(*) AS txn_count,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM fact_transactions),2) AS pct
FROM fact_transactions
GROUP BY amount_exceeds_balance;

-- 0.4 Confirm customer/merchant accounts are unique per row (no repeat customers)
SELECT
  (SELECT COUNT(*) FROM fact_transactions) AS total_rows,
  (SELECT COUNT(DISTINCT customer_account_number) FROM fact_transactions) AS unique_customers,
  (SELECT COUNT(DISTINCT merchant_account_number) FROM fact_transactions) AS unique_merchants;


-- =========================================================
-- SECTION 1: SPENDING PATTERNS
-- =========================================================

-- 1.1 Total spend & transaction count by purpose (category)
SELECT purpose,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount),2) AS total_spend,
       ROUND(AVG(amount),2) AS avg_ticket_size
FROM fact_transactions
WHERE status = 'Success'
GROUP BY purpose
ORDER BY total_spend DESC;

-- 1.2 Spend by transaction type (Transfer vs Payment)
SELECT transaction_type,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount),2) AS total_spend,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM fact_transactions WHERE status='Success'),2) AS pct_of_txns
FROM fact_transactions
WHERE status = 'Success'
GROUP BY transaction_type;

-- 1.3 Spend by merchant
SELECT merchant_name,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount),2) AS total_received,
       ROUND(AVG(amount),2) AS avg_ticket_size
FROM fact_transactions
WHERE status = 'Success'
GROUP BY merchant_name
ORDER BY total_received DESC;

-- 1.4 Spend by city
SELECT city,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount),2) AS total_spend
FROM fact_transactions
WHERE status = 'Success'
GROUP BY city
ORDER BY total_spend DESC;

-- 1.5 Spend by age group & gender
SELECT
  CASE
    WHEN customer_age < 30 THEN '20-29'
    WHEN customer_age < 40 THEN '30-39'
    WHEN customer_age < 50 THEN '40-49'
    ELSE '50-59'
  END AS age_group,
  gender,
  COUNT(*) AS txn_count,
  ROUND(AVG(amount),2) AS avg_ticket_size
FROM fact_transactions
WHERE status = 'Success'
GROUP BY age_group, gender
ORDER BY age_group, gender;

-- 1.6 Device type & payment method usage
SELECT device_type, payment_method,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount),2) AS total_spend
FROM fact_transactions
WHERE status = 'Success'
GROUP BY device_type, payment_method
ORDER BY txn_count DESC;

-- 1.7 Weekday vs weekend spending
SELECT CASE WHEN d.is_weekend = 1 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
       COUNT(*) AS txn_count,
       ROUND(AVG(f.amount),2) AS avg_ticket_size,
       ROUND(SUM(f.amount),2) AS total_spend
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.status = 'Success'
GROUP BY day_type;

-- 1.8 Instant vs Scheduled payment mode behaviour
SELECT payment_mode,
       COUNT(*) AS txn_count,
       ROUND(AVG(amount),2) AS avg_ticket_size
FROM fact_transactions
WHERE status = 'Success'
GROUP BY payment_mode;


-- =========================================================
-- SECTION 2: ANOMALY SIGNALS
-- =========================================================

-- 2.1 Transactions where Amount exceeds RemainingBalance (built-in flag)
SELECT transaction_id, txn_time, amount, remaining_balance, purpose, status
FROM fact_transactions
WHERE amount_exceeds_balance = 1
ORDER BY (amount - remaining_balance) DESC
LIMIT 50;

-- 2.2 Statistical outliers using Z-score, by purpose category
WITH stats AS (
  SELECT purpose,
         AVG(amount) AS mean_amt,
         SQRT(AVG(amount*amount) - AVG(amount)*AVG(amount)) AS sd_amt
  FROM fact_transactions
  WHERE status = 'Success'
  GROUP BY purpose
)
SELECT f.transaction_id, f.txn_time, f.purpose, f.amount,
       ROUND((f.amount - s.mean_amt) / NULLIF(s.sd_amt,0), 2) AS z_score
FROM fact_transactions f
JOIN stats s ON f.purpose = s.purpose
WHERE f.status = 'Success'
  AND ABS((f.amount - s.mean_amt) / NULLIF(s.sd_amt,0)) > 3
ORDER BY z_score DESC;

-- 2.3 Failed transaction rate by sending bank
SELECT b.bank_name,
       COUNT(*) AS total_txns,
       SUM(CASE WHEN f.status='Failed' THEN 1 ELSE 0 END) AS failed_txns,
       ROUND(100.0*SUM(CASE WHEN f.status='Failed' THEN 1 ELSE 0 END)/COUNT(*),2) AS failure_rate_pct
FROM fact_transactions f
JOIN dim_bank b ON f.sent_bank_id = b.bank_id
GROUP BY b.bank_name
ORDER BY failure_rate_pct DESC;

-- 2.4 Non-INR currency transactions (data-quality anomaly for a "UPI" dataset)
SELECT currency, COUNT(*) AS txn_count, ROUND(SUM(amount),2) AS total_amount
FROM fact_transactions
WHERE currency != 'INR' AND status = 'Success'
GROUP BY currency
ORDER BY total_amount DESC;

-- 2.5 High-value failed transactions (risk: money movement attempted but not completed)
SELECT transaction_id, txn_time, amount, purpose, merchant_name, city
FROM fact_transactions
WHERE status = 'Failed'
ORDER BY amount DESC
LIMIT 20;


-- =========================================================
-- SECTION 3: TIME-SERIES
-- =========================================================

-- 3.1 Monthly transaction volume & value trend (2024)
SELECT d.month, d.month_name,
       COUNT(*) AS txn_count,
       ROUND(SUM(f.amount),2) AS total_value
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.status = 'Success'
GROUP BY d.month, d.month_name
ORDER BY d.month;

-- 3.2 Month-over-month growth rate
WITH monthly AS (
  SELECT d.month, SUM(f.amount) AS total_value
  FROM fact_transactions f JOIN dim_date d ON f.date_id = d.date_id
  WHERE f.status = 'Success'
  GROUP BY d.month
)
SELECT month, total_value,
       ROUND(100.0*(total_value - LAG(total_value) OVER (ORDER BY month))
             / NULLIF(LAG(total_value) OVER (ORDER BY month),0), 2) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- 3.3 7-day moving average of daily spend
WITH daily AS (
  SELECT d.full_date, SUM(f.amount) AS daily_total
  FROM fact_transactions f JOIN dim_date d ON f.date_id = d.date_id
  WHERE f.status = 'Success'
  GROUP BY d.full_date
)
SELECT full_date, daily_total,
       ROUND(AVG(daily_total) OVER (ORDER BY full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS moving_avg_7d
FROM daily
ORDER BY full_date;

-- 3.4 Quarter-wise breakdown by transaction type
SELECT d.quarter, f.transaction_type,
       ROUND(SUM(f.amount),2) AS total_value
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.status = 'Success'
GROUP BY d.quarter, f.transaction_type
ORDER BY d.quarter;

-- NOTE: this dataset covers a single calendar year (2024), so a true
-- year-over-year comparison isn't possible. Use MoM / QoQ trends
-- instead (3.2, 3.4). If you extend the dataset with a second year,
-- the YoY DAX pattern in 03_dax_measures.txt will work unchanged.


-- =========================================================
-- SECTION 4: OPERATIONAL HEALTH
-- =========================================================

-- 4.1 Overall success/failure rate
SELECT status, COUNT(*) AS txn_count,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM fact_transactions),2) AS pct
FROM fact_transactions
GROUP BY status;

-- 4.2 Device-type usage split
SELECT device_type, COUNT(*) AS txn_count,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM fact_transactions),2) AS pct
FROM fact_transactions
GROUP BY device_type;

-- 4.3 Payment method success rate
SELECT payment_method,
       COUNT(*) AS total_txns,
       ROUND(100.0*SUM(CASE WHEN status='Success' THEN 1 ELSE 0 END)/COUNT(*),2) AS success_rate_pct
FROM fact_transactions
GROUP BY payment_method
ORDER BY success_rate_pct DESC;
