-- =============================================================
--  LOAN DELINQUENCY RISK ANALYSIS
--  File: 02_eda_aggregations.sql
--  Purpose: Summary statistics, GROUP BY analysis, EDA queries
-- =============================================================


-- ─── SECTION A: OVERALL SUMMARY STATISTICS ───────────────────────────────────

-- Master summary — the numbers that go on the KPI dashboard
SELECT
    COUNT(*)                                                AS Total_Customers,
    SUM(Delinquent_Account)                                 AS Delinquent_Count,
    COUNT(*) - SUM(Delinquent_Account)                      AS Good_Standing_Count,
    ROUND(AVG(Delinquent_Account) * 100, 2)                 AS Delinquency_Rate_Pct,
    ROUND(AVG(Credit_Score), 0)                             AS Avg_Credit_Score,
    ROUND(MIN(Credit_Score), 0)                             AS Min_Credit_Score,
    ROUND(MAX(Credit_Score), 0)                             AS Max_Credit_Score,
    ROUND(AVG(Income), 0)                                   AS Avg_Annual_Income,
    ROUND(AVG(Missed_Payments), 2)                          AS Avg_Missed_Payments,
    ROUND(AVG(Credit_Utilization) * 100, 1)                 AS Avg_Credit_Util_Pct,
    ROUND(AVG(Loan_Balance), 0)                             AS Avg_Loan_Balance,
    ROUND(AVG(Debt_to_Income_Ratio), 3)                     AS Avg_DTI_Ratio
FROM loan_delinquency;


-- Compare key metrics: Delinquent vs Non-Delinquent customers
SELECT
    Delinquent_Account,
    COUNT(*)                                    AS Customer_Count,
    ROUND(AVG(Age), 1)                          AS Avg_Age,
    ROUND(AVG(Income), 0)                       AS Avg_Income,
    ROUND(AVG(Credit_Score), 0)                 AS Avg_Credit_Score,
    ROUND(AVG(Credit_Utilization) * 100, 1)     AS Avg_Utilization_Pct,
    ROUND(AVG(Missed_Payments), 2)              AS Avg_Missed_Payments,
    ROUND(AVG(Loan_Balance), 0)                 AS Avg_Loan_Balance,
    ROUND(AVG(Debt_to_Income_Ratio), 3)         AS Avg_DTI,
    ROUND(AVG(Account_Tenure), 1)               AS Avg_Account_Tenure_Yrs
FROM loan_delinquency
GROUP BY Delinquent_Account
ORDER BY Delinquent_Account;


-- ─── SECTION B: GROUP BY EMPLOYMENT STATUS ───────────────────────────────────

SELECT
    Employment_Status,
    COUNT(*)                                            AS Customer_Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1)  AS Portfolio_Share_Pct,
    SUM(Delinquent_Account)                             AS Delinquent_Count,
    ROUND(AVG(Delinquent_Account) * 100, 1)             AS Delinquency_Rate_Pct,
    ROUND(AVG(Credit_Score), 0)                         AS Avg_Credit_Score,
    ROUND(AVG(Income), 0)                               AS Avg_Income,
    ROUND(AVG(Missed_Payments), 1)                      AS Avg_Missed_Payments
FROM loan_delinquency
GROUP BY Employment_Status
ORDER BY Delinquency_Rate_Pct DESC;


-- ─── SECTION C: GROUP BY LOCATION ────────────────────────────────────────────

SELECT
    Location,
    COUNT(*)                                            AS Total_Customers,
    SUM(Delinquent_Account)                             AS Delinquent_Customers,
    ROUND(AVG(Delinquent_Account) * 100, 1)             AS Delinquency_Rate_Pct,
    ROUND(AVG(Credit_Score), 0)                         AS Avg_Credit_Score,
    ROUND(AVG(Income), 0)                               AS Avg_Income,
    ROUND(AVG(Credit_Utilization) * 100, 1)             AS Avg_Util_Pct,
    ROUND(AVG(Loan_Balance), 0)                         AS Avg_Loan_Balance
FROM loan_delinquency
GROUP BY Location
ORDER BY Delinquency_Rate_Pct DESC;


-- ─── SECTION D: GROUP BY CREDIT CARD TYPE ────────────────────────────────────

SELECT
    Credit_Card_Type,
    COUNT(*)                                            AS Customer_Count,
    SUM(Delinquent_Account)                             AS Delinquent_Count,
    ROUND(AVG(Delinquent_Account) * 100, 1)             AS Delinquency_Rate_Pct,
    ROUND(AVG(Credit_Score), 0)                         AS Avg_Credit_Score,
    ROUND(AVG(Loan_Balance), 0)                         AS Avg_Loan_Balance,
    ROUND(AVG(Credit_Utilization) * 100, 1)             AS Avg_Util_Pct
FROM loan_delinquency
GROUP BY Credit_Card_Type
ORDER BY Delinquency_Rate_Pct DESC;


-- ─── SECTION E: DELINQUENCY RATE BY MISSED PAYMENTS COUNT ────────────────────

SELECT
    Missed_Payments,
    COUNT(*)                                    AS Customer_Count,
    SUM(Delinquent_Account)                     AS Delinquent_Count,
    ROUND(AVG(Delinquent_Account) * 100, 1)     AS Delinquency_Rate_Pct,
    ROUND(AVG(Credit_Score), 0)                 AS Avg_Credit_Score,
    ROUND(AVG(Credit_Utilization) * 100, 1)     AS Avg_Util_Pct
FROM loan_delinquency
GROUP BY Missed_Payments
ORDER BY Missed_Payments;


-- ─── SECTION F: AGE BAND ANALYSIS ────────────────────────────────────────────

SELECT
    CASE
        WHEN Age BETWEEN 18 AND 29 THEN '18-29 (Young Adult)'
        WHEN Age BETWEEN 30 AND 44 THEN '30-44 (Prime Working)'
        WHEN Age BETWEEN 45 AND 59 THEN '45-59 (Mid Career)'
        WHEN Age >= 60              THEN '60+ (Pre/Post Retire)'
    END                                                 AS Age_Band,
    COUNT(*)                                            AS Customer_Count,
    ROUND(AVG(Delinquent_Account) * 100, 1)             AS Delinquency_Rate_Pct,
    ROUND(AVG(Credit_Score), 0)                         AS Avg_Credit_Score,
    ROUND(AVG(Income), 0)                               AS Avg_Income,
    ROUND(AVG(Missed_Payments), 2)                      AS Avg_Missed_Payments
FROM loan_delinquency
GROUP BY Age_Band
ORDER BY MIN(Age);


-- ─── SECTION G: CREDIT SCORE BAND ANALYSIS ───────────────────────────────────

SELECT
    CASE
        WHEN Credit_Score < 400             THEN 'Very Poor  (<400)'
        WHEN Credit_Score BETWEEN 400 AND 499 THEN 'Poor       (400-499)'
        WHEN Credit_Score BETWEEN 500 AND 599 THEN 'Fair       (500-599)'
        WHEN Credit_Score BETWEEN 600 AND 699 THEN 'Good       (600-699)'
        WHEN Credit_Score BETWEEN 700 AND 799 THEN 'Very Good  (700-799)'
        ELSE                                     'Excellent  (800+)'
    END                                             AS Credit_Band,
    COUNT(*)                                        AS Customer_Count,
    SUM(Delinquent_Account)                         AS Delinquent_Count,
    ROUND(AVG(Delinquent_Account) * 100, 1)         AS Delinquency_Rate_Pct,
    ROUND(AVG(Income), 0)                           AS Avg_Income
FROM loan_delinquency
GROUP BY Credit_Band
ORDER BY MIN(Credit_Score);


-- ─── SECTION H: MONTHLY PAYMENT BEHAVIOUR TREND ──────────────────────────────

-- Missed payments by month (to detect deteriorating trends)
SELECT
    'Month_1' AS Payment_Month,
    COUNT(CASE WHEN Month_1='On-time' THEN 1 END)   AS On_Time,
    COUNT(CASE WHEN Month_1='Late'    THEN 1 END)   AS Late,
    COUNT(CASE WHEN Month_1='Missed'  THEN 1 END)   AS Missed
FROM loan_delinquency
UNION ALL
SELECT 'Month_2',
    COUNT(CASE WHEN Month_2='On-time' THEN 1 END),
    COUNT(CASE WHEN Month_2='Late'    THEN 1 END),
    COUNT(CASE WHEN Month_2='Missed'  THEN 1 END)
FROM loan_delinquency
UNION ALL
SELECT 'Month_3',
    COUNT(CASE WHEN Month_3='On-time' THEN 1 END),
    COUNT(CASE WHEN Month_3='Late'    THEN 1 END),
    COUNT(CASE WHEN Month_3='Missed'  THEN 1 END)
FROM loan_delinquency
UNION ALL
SELECT 'Month_4',
    COUNT(CASE WHEN Month_4='On-time' THEN 1 END),
    COUNT(CASE WHEN Month_4='Late'    THEN 1 END),
    COUNT(CASE WHEN Month_4='Missed'  THEN 1 END)
FROM loan_delinquency
UNION ALL
SELECT 'Month_5',
    COUNT(CASE WHEN Month_5='On-time' THEN 1 END),
    COUNT(CASE WHEN Month_5='Late'    THEN 1 END),
    COUNT(CASE WHEN Month_5='Missed'  THEN 1 END)
FROM loan_delinquency
UNION ALL
SELECT 'Month_6',
    COUNT(CASE WHEN Month_6='On-time' THEN 1 END),
    COUNT(CASE WHEN Month_6='Late'    THEN 1 END),
    COUNT(CASE WHEN Month_6='Missed'  THEN 1 END)
FROM loan_delinquency;


-- ─── SECTION I: INCOME QUARTILE ANALYSIS ─────────────────────────────────────

SELECT
    CASE
        WHEN Income < 62295   THEN 'Q1 (<$62K)'
        WHEN Income < 107658  THEN 'Q2 ($62K–$108K)'
        WHEN Income < 155734  THEN 'Q3 ($108K–$156K)'
        ELSE                       'Q4 (>$156K)'
    END                                             AS Income_Quartile,
    COUNT(*)                                        AS Customer_Count,
    ROUND(AVG(Delinquent_Account) * 100, 1)         AS Delinquency_Rate_Pct,
    ROUND(AVG(Credit_Score), 0)                     AS Avg_Credit_Score,
    ROUND(AVG(Missed_Payments), 2)                  AS Avg_Missed_Payments,
    ROUND(AVG(Debt_to_Income_Ratio), 3)             AS Avg_DTI
FROM loan_delinquency
GROUP BY Income_Quartile
ORDER BY MIN(Income);
