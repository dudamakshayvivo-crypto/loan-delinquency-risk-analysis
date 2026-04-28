-- =============================================================
--  LOAN DELINQUENCY RISK ANALYSIS
--  File: 01_data_cleaning.sql
--  Purpose: Standardise raw data, handle nulls, fix dirty values
--  Database: MySQL / PostgreSQL / SQL Server compatible
-- =============================================================

-- ─── STEP 1: INSPECT RAW DATA ────────────────────────────────────────────────

-- Preview first 10 rows
SELECT * FROM loan_delinquency LIMIT 10;

-- Check total rows and columns
SELECT COUNT(*) AS Total_Rows FROM loan_delinquency;

-- Check for NULL values in each column
SELECT
    SUM(CASE WHEN Customer_ID           IS NULL THEN 1 ELSE 0 END) AS Null_CustomerID,
    SUM(CASE WHEN Age                   IS NULL THEN 1 ELSE 0 END) AS Null_Age,
    SUM(CASE WHEN Income                IS NULL THEN 1 ELSE 0 END) AS Null_Income,
    SUM(CASE WHEN Credit_Score          IS NULL THEN 1 ELSE 0 END) AS Null_CreditScore,
    SUM(CASE WHEN Credit_Utilization    IS NULL THEN 1 ELSE 0 END) AS Null_Utilization,
    SUM(CASE WHEN Missed_Payments       IS NULL THEN 1 ELSE 0 END) AS Null_MissedPayments,
    SUM(CASE WHEN Delinquent_Account    IS NULL THEN 1 ELSE 0 END) AS Null_Target,
    SUM(CASE WHEN Loan_Balance          IS NULL THEN 1 ELSE 0 END) AS Null_LoanBalance,
    SUM(CASE WHEN Debt_to_Income_Ratio  IS NULL THEN 1 ELSE 0 END) AS Null_DTI,
    SUM(CASE WHEN Employment_Status     IS NULL THEN 1 ELSE 0 END) AS Null_Employment
FROM loan_delinquency;

-- Check distinct values in categorical columns (spot dirty data)
SELECT DISTINCT Employment_Status FROM loan_delinquency ORDER BY 1;
SELECT DISTINCT Credit_Card_Type  FROM loan_delinquency ORDER BY 1;
SELECT DISTINCT Location          FROM loan_delinquency ORDER BY 1;
SELECT DISTINCT Month_1           FROM loan_delinquency ORDER BY 1;

-- Check for outliers in numeric columns
SELECT
    MIN(Credit_Utilization)  AS Min_Util,
    MAX(Credit_Utilization)  AS Max_Util,
    MIN(Credit_Score)        AS Min_CreditScore,
    MAX(Credit_Score)        AS Max_CreditScore,
    MIN(Age)                 AS Min_Age,
    MAX(Age)                 AS Max_Age
FROM loan_delinquency;


-- ─── STEP 2: FIX EMPLOYMENT STATUS INCONSISTENCIES ───────────────────────────

-- Before fix: shows EMP, employed, Employed, retired as separate values
SELECT Employment_Status, COUNT(*) AS Count
FROM loan_delinquency
GROUP BY Employment_Status
ORDER BY Count DESC;

-- Apply standardisation
UPDATE loan_delinquency
SET Employment_Status = CASE
    WHEN UPPER(TRIM(Employment_Status)) IN ('EMP', 'EMPLOYED') THEN 'Employed'
    WHEN TRIM(Employment_Status) = 'Self-employed'             THEN 'Self-employed'
    WHEN TRIM(Employment_Status) = 'Unemployed'                THEN 'Unemployed'
    WHEN LOWER(TRIM(Employment_Status)) = 'retired'            THEN 'Retired'
    ELSE 'Employed'  -- default for any unrecognised value
END;

-- Verify: should now have exactly 4 clean categories
SELECT Employment_Status, COUNT(*) AS Count
FROM loan_delinquency
GROUP BY Employment_Status
ORDER BY Count DESC;


-- ─── STEP 3: HANDLE NULL VALUES ──────────────────────────────────────────────

-- Calculate medians first (use as replacement values)
-- MySQL syntax (adjust for your DB):
SET @income_median = (
    SELECT AVG(Income) FROM (
        SELECT Income FROM loan_delinquency
        WHERE Income IS NOT NULL
        ORDER BY Income
        LIMIT 2 - (SELECT COUNT(*) FROM loan_delinquency WHERE Income IS NOT NULL) % 2
        OFFSET (SELECT (COUNT(*) - 1) / 2 FROM loan_delinquency WHERE Income IS NOT NULL)
    ) AS sub
);

-- Fill missing Income with median
UPDATE loan_delinquency
SET Income = 107658  -- median value calculated from dataset
WHERE Income IS NULL;

-- Fill missing Loan_Balance with median
UPDATE loan_delinquency
SET Loan_Balance = 45776  -- median value calculated from dataset
WHERE Loan_Balance IS NULL;

-- Fill missing Credit_Score with median
UPDATE loan_delinquency
SET Credit_Score = 578  -- median value calculated from dataset
WHERE Credit_Score IS NULL;

-- Verify: no more nulls
SELECT
    SUM(CASE WHEN Income        IS NULL THEN 1 ELSE 0 END) AS Null_Income,
    SUM(CASE WHEN Loan_Balance  IS NULL THEN 1 ELSE 0 END) AS Null_LoanBalance,
    SUM(CASE WHEN Credit_Score  IS NULL THEN 1 ELSE 0 END) AS Null_CreditScore
FROM loan_delinquency;


-- ─── STEP 4: FIX CREDIT UTILIZATION OUTLIERS ─────────────────────────────────

-- Check how many rows exceed 100% utilization
SELECT COUNT(*) AS Rows_Over_100pct
FROM loan_delinquency
WHERE Credit_Utilization > 1.0;

-- Cap at 1.0 (100%)
UPDATE loan_delinquency
SET Credit_Utilization = 1.0
WHERE Credit_Utilization > 1.0;

-- Verify
SELECT MIN(Credit_Utilization), MAX(Credit_Utilization)
FROM loan_delinquency;


-- ─── STEP 5: ADD COMPUTED COLUMNS (Optional - for analysis) ──────────────────

-- Add Monthly Missed Count column
ALTER TABLE loan_delinquency ADD COLUMN Missed_Count_6M INT DEFAULT 0;

UPDATE loan_delinquency
SET Missed_Count_6M = (
    CASE WHEN Month_1 = 'Missed' THEN 1 ELSE 0 END +
    CASE WHEN Month_2 = 'Missed' THEN 1 ELSE 0 END +
    CASE WHEN Month_3 = 'Missed' THEN 1 ELSE 0 END +
    CASE WHEN Month_4 = 'Missed' THEN 1 ELSE 0 END +
    CASE WHEN Month_5 = 'Missed' THEN 1 ELSE 0 END +
    CASE WHEN Month_6 = 'Missed' THEN 1 ELSE 0 END
);

-- Add Monthly Late Count column
ALTER TABLE loan_delinquency ADD COLUMN Late_Count_6M INT DEFAULT 0;

UPDATE loan_delinquency
SET Late_Count_6M = (
    CASE WHEN Month_1 = 'Late' THEN 1 ELSE 0 END +
    CASE WHEN Month_2 = 'Late' THEN 1 ELSE 0 END +
    CASE WHEN Month_3 = 'Late' THEN 1 ELSE 0 END +
    CASE WHEN Month_4 = 'Late' THEN 1 ELSE 0 END +
    CASE WHEN Month_5 = 'Late' THEN 1 ELSE 0 END +
    CASE WHEN Month_6 = 'Late' THEN 1 ELSE 0 END
);

-- Add Risk Segment label
ALTER TABLE loan_delinquency ADD COLUMN Risk_Segment VARCHAR(20);

UPDATE loan_delinquency
SET Risk_Segment = CASE
    WHEN (
        CASE WHEN Missed_Payments >= 4 THEN 2 WHEN Missed_Payments >= 2 THEN 1 ELSE 0 END +
        CASE WHEN Credit_Score < 450   THEN 2 WHEN Credit_Score < 600   THEN 1 ELSE 0 END +
        CASE WHEN Credit_Utilization > 0.75 THEN 1 ELSE 0 END +
        CASE WHEN Debt_to_Income_Ratio > 0.40 THEN 1 ELSE 0 END
    ) >= 4 THEN 'High Risk'
    WHEN (
        CASE WHEN Missed_Payments >= 4 THEN 2 WHEN Missed_Payments >= 2 THEN 1 ELSE 0 END +
        CASE WHEN Credit_Score < 450   THEN 2 WHEN Credit_Score < 600   THEN 1 ELSE 0 END +
        CASE WHEN Credit_Utilization > 0.75 THEN 1 ELSE 0 END +
        CASE WHEN Debt_to_Income_Ratio > 0.40 THEN 1 ELSE 0 END
    ) >= 2 THEN 'Medium Risk'
    ELSE 'Low Risk'
END;

-- Final data quality check
SELECT
    COUNT(*)                                        AS Total_Records,
    COUNT(DISTINCT Customer_ID)                     AS Unique_Customers,
    SUM(CASE WHEN Delinquent_Account=1 THEN 1 END)  AS Delinquent_Count,
    ROUND(AVG(Delinquent_Account)*100, 1)           AS Delinquency_Rate_Pct,
    SUM(CASE WHEN Income IS NULL THEN 1 END)        AS Remaining_Nulls_Income
FROM loan_delinquency;
