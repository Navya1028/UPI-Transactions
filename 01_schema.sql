/* =========================================================
   UPI TRANSACTIONS DASHBOARD — STAR SCHEMA DDL
   Built from the user-supplied UPI_Transactions.xlsx dataset
   (20,000 rows, calendar year 2024, no nulls)
   Engine: SQLite (portable to MySQL/Postgres/SQL Server)
   ========================================================= */

-- 1. Raw landing table (mirrors the source Excel export as-is)
CREATE TABLE raw_upi_transactions (
    TransactionID           TEXT PRIMARY KEY,
    TransactionDate          TEXT,
    Amount                    REAL,
    BankNameSent              TEXT,
    BankNameReceived          TEXT,
    RemainingBalance          REAL,
    City                      TEXT,
    Gender                    TEXT,
    TransactionType           TEXT,   -- Transfer | Payment
    Status                    TEXT,   -- Success | Failed
    TransactionTime           TEXT,
    DeviceType                TEXT,   -- Mobile | Tablet | Laptop
    PaymentMethod             TEXT,   -- UPI ID | QR Code | Phone Number
    MerchantName               TEXT,
    Purpose                   TEXT,   -- Food | Travel | Bill Payment | Shopping | Others
    CustomerAge               INTEGER,
    PaymentMode               TEXT,   -- Instant | Scheduled
    Currency                  TEXT,   -- INR | USD | EUR | GBP  (data-quality flag, see docs)
    CustomerAccountNumber     INTEGER,
    MerchantAccountNumber     INTEGER
);

-- 2. Dimension: Date
CREATE TABLE dim_date (
    date_id     INTEGER PRIMARY KEY,   -- YYYYMMDD
    full_date   TEXT,
    year        INTEGER,
    quarter     INTEGER,
    month       INTEGER,
    month_name  TEXT,
    day         INTEGER,
    day_name    TEXT,
    is_weekend  INTEGER
);

-- 3. Dimension: Bank (ROLE-PLAYING DIMENSION)
-- Only 4 distinct banks appear across BOTH BankNameSent and
-- BankNameReceived, so a single dim_bank table serves two roles.
-- In Power BI: create ONE active relationship
-- (fact_transactions[sent_bank_id] -> dim_bank[bank_id]) and one
-- INACTIVE relationship (received_bank_id -> bank_id), then use
-- USERELATIONSHIP() in DAX to activate the second role when needed.
CREATE TABLE dim_bank (
    bank_id     INTEGER PRIMARY KEY,
    bank_name   TEXT UNIQUE
);

-- 4. Fact: Transactions (grain = one row per UPI transaction)
CREATE TABLE fact_transactions (
    transaction_id             TEXT PRIMARY KEY,
    date_id                     INTEGER REFERENCES dim_date(date_id),
    txn_time                    TEXT,
    amount                       REAL,
    remaining_balance            REAL,
    sent_bank_id                 INTEGER REFERENCES dim_bank(bank_id),
    received_bank_id             INTEGER REFERENCES dim_bank(bank_id),
    city                         TEXT,
    gender                       TEXT,
    transaction_type             TEXT,
    status                        TEXT,
    device_type                  TEXT,
    payment_method                TEXT,
    merchant_name                 TEXT,
    purpose                       TEXT,
    customer_age                  INTEGER,
    payment_mode                  TEXT,
    currency                      TEXT,
    customer_account_number        INTEGER,
    merchant_account_number        INTEGER,
    amount_exceeds_balance         INTEGER   -- derived flag, see Section 6 of project doc
);

CREATE INDEX idx_fact_date      ON fact_transactions(date_id);
CREATE INDEX idx_fact_sentbank  ON fact_transactions(sent_bank_id);
CREATE INDEX idx_fact_recvbank  ON fact_transactions(received_bank_id);
CREATE INDEX idx_fact_purpose   ON fact_transactions(purpose);

/* =========================================================
   DESIGN NOTES
   - city, gender, transaction_type, status, device_type,
     payment_method, merchant_name, purpose, payment_mode,
     currency are kept as attributes directly on the fact
     table rather than split into further dimensions: each
     has very low cardinality (2-5 distinct values) and no
     additional descriptive attributes of their own, so a
     separate dimension table would add join cost without a
     modeling benefit. This is a normal, defensible star-
     schema design decision worth explaining in interviews.
   - customer_account_number and merchant_account_number are
     UNIQUE PER ROW in this dataset (no repeat customers or
     merchants), so no dim_customer / dim_merchant table was
     built — doing so would just be a 1:1 relabel of the fact
     table, not a true dimensional reduction.
   ========================================================= */
