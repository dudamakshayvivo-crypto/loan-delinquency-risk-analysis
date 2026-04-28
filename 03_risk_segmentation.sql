-- =============================================================
--  LOAN DELINQUENCY RISK ANALYSIS
--  File: 03_risk_segmentation.sql
--  Purpose: Risk scoring, priority customer lists, segment reporting
-- =============================================================


-- ─── SECTION A: CORE RISK SEGMENTATION ───────────────────────────────────────

-- Weighted risk score model (business rule-based)
-- Score 4+ = High Risk | Score 2-3 = Medium Risk | Score 0-1 = Low Risk
WITH risk_scored AS (
    SELECT
        Customer_ID,
        Age,
        Income,
        Credit_Score,
        Missed_Payments,
        Credit_Utilization,
        Loan_Balance,
        Debt_to_Income_Ratio,
        Employment_Status,
        Location,
        Credit_Card_Type,
        Account_Tenure,
        Delinquent_Account,

        -- Individual risk components
        CASE WHEN Missed_Payments >= 4      THEN 2
             WHEN Missed_Payments >= 2      THEN 1
             ELSE 0 END                             AS Score_MissedPayments,

        CASE WHEN Credit_Score < 450        THEN 2
             WHEN Credit_Score < 600        THEN 1
             ELSE 0 END                             AS Score_CreditScore,

        CASE WHEN Credit_Utilization > 0.75 THEN 1
             ELSE 0 END                             AS Score_Utilization,

        CASE WHEN Debt_to_Income_Ratio > 0.40 THEN 1
             ELSE 0 END                             AS Score_DTI,

        -- Total risk score
        (
            CASE WHEN Missed_Payments >= 4      THEN 2 WHEN Missed_Payments >= 2 THEN 1 ELSE 0 END +
            CASE WHEN Credit_Score < 450        THEN 2 WHEN Credit_Score < 600   THEN 1 ELSE 0 END +
            CASE WHEN Credit_Utilization > 0.75 THEN 1 ELSE 0 END +
            CASE WHEN Debt_to_Income_Ratio > 0.40 THEN 1 ELSE 0 END
        ) AS Total_Risk_Score

    FROM loan_delinquency
)
SELECT
    *,
    CASE
        WHEN Total_Risk_Score >= 4 THEN 'High Risk'
        WHEN Total_Risk_Score >= 2 THEN 'Medium Risk'
        ELSE                            'Low Risk'
    END AS Risk_Segment
FROM risk_scored
ORDER BY Total_Risk_Score DESC, Credit_Score ASC;


-- ─── SECTION B: SEGMENT SUMMARY REPORT ───────────────────────────────────────

WITH risk_scored AS (
    SELECT
        Customer_ID, Credit_Score, Missed_Payments, Credit_Utilization,
        Loan_Balance, Debt_to_Income_Ratio, Income, Delinquent_Account,
        (
            CASE WHEN Missed_Payments >= 4 THEN 2 WHEN Missed_Payments >= 2 THEN 1 ELSE 0 END +
            CASE WHEN Credit_Score < 450   THEN 2 WHEN Credit_Score < 600   THEN 1 ELSE 0 END +
            CASE WHEN Credit_Utilization > 0.75 THEN 1 ELSE 0 END +
            CASE WHEN Debt_to_Income_Ratio > 0.40 THEN 1 ELSE 0 END
        ) AS Total_Risk_Score
    FROM loan_delinquency
),
segmented AS (
    SELECT *,
        CASE WHEN Total_Risk_Score >= 4 THEN 'High Risk'
             WHEN Total_Risk_Score >= 2 THEN 'Medium Risk'
             ELSE 'Low Risk' END AS Risk_Segment
    FROM risk_scored
)
SELECT
    Risk_Segment,
    COUNT(*)                                            AS Customer_Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1)  AS Portfolio_Share_Pct,
    SUM(Delinquent_Account)                             AS Delinquent_Count,
    ROUND(AVG(Delinquent_Account) * 100, 1)             AS Delinquency_Rate_Pct,
    ROUND(AVG(Credit_Score), 0)                         AS Avg_Credit_Score,
    ROUND(AVG(Missed_Payments), 1)                      AS Avg_Missed_Payments,
    ROUND(AVG(Credit_Utilization) * 100, 1)             AS Avg_Util_Pct,
    ROUND(AVG(Loan_Balance), 0)                         AS Avg_Loan_Balance,
    ROUND(SUM(Loan_Balance), 0)                         AS Total_Loan_Exposure
FROM segmented
GROUP BY Risk_Segment
ORDER BY
    CASE Risk_Segment
        WHEN 'High Risk'   THEN 1
        WHEN 'Medium Risk' THEN 2
        ELSE 3
    END;


-- ─── SECTION C: PRIORITY LIST — TOP 30 HIGH RISK CUSTOMERS ───────────────────
-- Use this list for immediate collections outreach

WITH risk_scored AS (
    SELECT
        Customer_ID, Age, Income, Credit_Score, Missed_Payments,
        Credit_Utilization, Loan_Balance, Debt_to_Income_Ratio,
        Employment_Status, Location, Account_Tenure, Delinquent_Account,
        Month_5, Month_6,  -- Most recent months — highest priority signal
        (
            CASE WHEN Missed_Payments >= 4 THEN 2 WHEN Missed_Payments >= 2 THEN 1 ELSE 0 END +
            CASE WHEN Credit_Score < 450   THEN 2 WHEN Credit_Score < 600   THEN 1 ELSE 0 END +
            CASE WHEN Credit_Utilization > 0.75 THEN 1 ELSE 0 END +
            CASE WHEN Debt_to_Income_Ratio > 0.40 THEN 1 ELSE 0 END
        ) AS Risk_Score
    FROM loan_delinquency
)
SELECT
    Customer_ID,
    Age,
    ROUND(Income, 0)                        AS Annual_Income,
    Credit_Score,
    Missed_Payments,
    ROUND(Credit_Utilization * 100, 1)      AS Util_Pct,
    ROUND(Loan_Balance, 0)                  AS Loan_Balance,
    ROUND(Debt_to_Income_Ratio, 3)          AS DTI_Ratio,
    Employment_Status,
    Location,
    Month_5                                 AS Recent_Month_5,
    Month_6                                 AS Recent_Month_6,
    Risk_Score,
    Delinquent_Account                      AS Currently_Delinquent
FROM risk_scored
WHERE Risk_Score >= 4
ORDER BY Risk_Score DESC, Missed_Payments DESC, Credit_Score ASC
LIMIT 30;


-- ─── SECTION D: CONSECUTIVE MISSED PAYMENTS DETECTION ────────────────────────
-- Customers with 2+ consecutive Missed payments in recent months — highest urgency

SELECT
    Customer_ID,
    Month_1, Month_2, Month_3, Month_4, Month_5, Month_6,
    Credit_Score,
    Missed_Payments,
    Loan_Balance,
    CASE
        WHEN Month_5 = 'Missed' AND Month_6 = 'Missed' THEN 'CRITICAL — 2 Consecutive Recent'
        WHEN Month_4 = 'Missed' AND Month_5 = 'Missed' THEN 'HIGH — 2 Consecutive'
        WHEN Month_3 = 'Missed' AND Month_4 = 'Missed' THEN 'HIGH — 2 Consecutive'
        WHEN Month_6 = 'Missed'                         THEN 'WATCH — Latest Month Missed'
        ELSE 'MONITOR'
    END AS Urgency_Flag
FROM loan_delinquency
WHERE
    (Month_5 = 'Missed' AND Month_6 = 'Missed')
    OR (Month_4 = 'Missed' AND Month_5 = 'Missed')
    OR (Month_3 = 'Missed' AND Month_4 = 'Missed')
ORDER BY
    CASE
        WHEN Month_5='Missed' AND Month_6='Missed' THEN 1
        WHEN Month_4='Missed' AND Month_5='Missed' THEN 2
        ELSE 3
    END,
    Loan_Balance DESC;


-- ─── SECTION E: CROSS-SEGMENT ANALYSIS ───────────────────────────────────────
-- Which locations have the most high-risk customers?

WITH segmented AS (
    SELECT
        Customer_ID, Location, Employment_Status,
        CASE
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
        END AS Risk_Segment
    FROM loan_delinquency
)
SELECT
    Location,
    COUNT(CASE WHEN Risk_Segment = 'High Risk'   THEN 1 END) AS High_Risk,
    COUNT(CASE WHEN Risk_Segment = 'Medium Risk' THEN 1 END) AS Medium_Risk,
    COUNT(CASE WHEN Risk_Segment = 'Low Risk'    THEN 1 END) AS Low_Risk,
    COUNT(*)                                                   AS Total,
    ROUND(
        COUNT(CASE WHEN Risk_Segment = 'High Risk' THEN 1 END) * 100.0 / COUNT(*), 1
    )                                                          AS High_Risk_Pct
FROM segmented
GROUP BY Location
ORDER BY High_Risk_Pct DESC;


-- ─── SECTION F: EXPOSURE ANALYSIS ────────────────────────────────────────────
-- Total loan balance at risk by segment

SELECT
    CASE
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
    END                                                     AS Risk_Segment,
    COUNT(*)                                                AS Customers,
    ROUND(SUM(Loan_Balance), 0)                             AS Total_Exposure_USD,
    ROUND(AVG(Loan_Balance), 0)                             AS Avg_Exposure_USD,
    ROUND(SUM(Loan_Balance) * 100.0 / SUM(SUM(Loan_Balance)) OVER(), 1) AS Portfolio_Exposure_Pct
FROM loan_delinquency
GROUP BY Risk_Segment
ORDER BY Total_Exposure_USD DESC;
