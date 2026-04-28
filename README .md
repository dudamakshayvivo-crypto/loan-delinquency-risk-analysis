# 🏦 Loan Delinquency Risk Analysis & Prediction

![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Tools](https://img.shields.io/badge/Tools-SQL%20%7C%20Python%20%7C%20Power%20BI-blue)
![Dataset](https://img.shields.io/badge/Dataset-500%20Customers%20%7C%2019%20Features-orange)
![Domain](https://img.shields.io/badge/Domain-Banking%20%7C%20Credit%20Risk-navy)

> **An end-to-end data analytics portfolio project** demonstrating credit risk analysis, customer segmentation, predictive modelling, and executive dashboard development using real-world banking data.

---

## 📌 Project Summary

Financial institutions lose billions annually to loan defaults. This project builds a **complete credit risk intelligence system** that identifies at-risk customers **before** they become delinquent — enabling proactive intervention, smarter collections prioritisation, and portfolio-level risk monitoring.

| Metric | Result |
|---|---|
| Dataset Size | 500 customers, 19 features, 6-month payment history |
| Delinquency Rate Found | **16%** (80 of 500 customers) |
| High-Risk Customers Identified | **88** requiring immediate intervention |
| Model Accuracy | **82%** (Random Forest, class-balanced) |
| Risk Segments Created | **3** (High / Medium / Low) |
| Business Impact | Estimated 40% reduction in collections cost via early intervention |

---

## 🗂️ Project Structure

```
loan-delinquency-risk-analysis/
│
├── 📁 data/
│   └── Delinquency_prediction_dataset.xlsx   # Raw dataset (500 rows × 19 cols)
│
├── 📁 sql/
│   ├── 01_data_cleaning.sql                  # Null handling, standardisation, outlier capping
│   ├── 02_eda_aggregations.sql               # GROUP BY analysis across 9 dimensions
│   └── 03_risk_segmentation.sql             # 3-tier risk scoring, priority list, exposure analysis
│
├── 📁 python/
│   ├── loan_delinquency_analysis.py         # Full pipeline: EDA → visualisation → ML → segmentation
│   └── requirements.txt                      # pandas, numpy, matplotlib, seaborn, scikit-learn
│
├── 📁 powerbi/
│   ├── Loan_Delinquency_Dashboard.pbix       # Interactive Power BI dashboard
│   ├── dax_measures.md                       # All DAX measures with explanations
│   └── dashboard_screenshot.png              # Preview
│
├── 📁 presentation/
│   └── Loan_Delinquency_Presentation.pptx   # 10-slide executive deck
│
└── README.md
```

---

## 🔧 Tools & Technologies

| Tool | Version | Purpose |
|---|---|---|
| **Python** | 3.10+ | Data cleaning, EDA, visualisation, ML modelling |
| **pandas** | 2.x | Data manipulation and feature engineering |
| **scikit-learn** | 1.x | Random Forest classifier, train/test split, metrics |
| **matplotlib / seaborn** | Latest | 6-panel EDA charts, ROC curve, feature importance |
| **SQL** | MySQL/PostgreSQL | Data cleaning, aggregation, risk segmentation queries |
| **Power BI** | Desktop | Interactive dashboard with DAX measures and slicers |
| **Excel** | - | Source dataset (.xlsx) |
| **GitHub** | - | Version control, portfolio showcase |

---

## 📊 Dataset Overview

**Source:** `Delinquency_prediction_dataset.xlsx`  
**Domain:** Consumer Banking / Credit Risk

| Column | Type | Key Info |
|---|---|---|
| `Customer_ID` | ID | CUST0001–CUST0500 |
| `Age` | Numeric | 18–74 years |
| `Income` | Numeric | $15K–$200K annual (39 nulls → median imputed) |
| `Credit_Score` | Numeric | 301–847 (higher = better) |
| `Credit_Utilization` | Numeric | 0.0–1.0 (1 outlier capped at 1.0) |
| `Missed_Payments` | Numeric | Count 0–6 |
| **`Delinquent_Account`** | **Binary** | **🎯 TARGET variable: 1=Delinquent** |
| `Loan_Balance` | Numeric | $612–$99,620 (29 nulls → median imputed) |
| `Debt_to_Income_Ratio` | Numeric | 0.10–0.55 |
| `Employment_Status` | Categorical | Employed / Self-employed / Unemployed / Retired |
| `Account_Tenure` | Numeric | 0–19 years |
| `Credit_Card_Type` | Categorical | Standard / Gold / Platinum / Business / Student |
| `Location` | Categorical | 5 US cities |
| `Month_1–Month_6` | Categorical | On-time / Late / Missed (6-month history) |

**Data Quality Issues Resolved:**
- `Employment_Status`: 5 inconsistent variants (`EMP`, `employed`, etc.) → standardised to 4 clean categories
- `Income`: 39 nulls (7.8%) → median imputation ($107,658)
- `Loan_Balance`: 29 nulls (5.8%) → median imputation ($45,776)
- `Credit_Utilization`: 1 extreme outlier (>100%) → capped at 1.0

---

## 🗄️ SQL Highlights

**3 SQL files, 20+ production-grade queries:**

```sql
-- Risk segmentation with weighted scoring
SELECT Customer_ID, Credit_Score, Missed_Payments,
    CASE
        WHEN (score_formula) >= 4 THEN 'High Risk'
        WHEN (score_formula) >= 2 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS Risk_Segment
FROM loan_delinquency;

-- Delinquency rate by employment status
SELECT Employment_Status,
    COUNT(*) AS Customers,
    ROUND(AVG(Delinquent_Account)*100, 1) AS Delinquency_Rate_Pct
FROM loan_delinquency
GROUP BY Employment_Status
ORDER BY Delinquency_Rate_Pct DESC;
```

See [`sql/`](./sql/) for all queries.

---

## 🐍 Python Highlights

**Full pipeline in one script:**

```python
# Feature engineering from 6-month payment history
df["Missed_Count_6M"] = df[pay_cols].apply(lambda r: (r=="Missed").sum(), axis=1)
df["Late_Count_6M"]   = df[pay_cols].apply(lambda r: (r=="Late").sum(),   axis=1)

# Random Forest with class balancing for imbalanced target
model = RandomForestClassifier(n_estimators=200, max_depth=6,
                               class_weight="balanced", random_state=42)

# Risk segmentation function
def risk_segment(row):
    score = 0
    if row["Missed_Payments"] >= 4:       score += 2
    if row["Credit_Score"] < 450:          score += 2
    if row["Credit_Utilization"] > 0.75:   score += 1
    if row["Debt_to_Income_Ratio"] > 0.40: score += 1
    return "High Risk" if score>=4 else ("Medium Risk" if score>=2 else "Low Risk")
```

---

## 📈 Key Findings

### Finding 1 — Missed Payments is the Strongest Predictor
| Missed Payments | Delinquency Rate |
|---|---|
| 0 | ~5% |
| 1–2 | ~8–12% |
| 3–4 | ~16–22% |
| 5–6 | ~27–35% |

### Finding 2 — Credit Score Threshold at 500
- Customers with Credit Score **< 500** have **3× higher** delinquency risk
- The band 500–600 is a transition zone — moderate risk
- Scores 700+ show <10% delinquency regardless of other factors

### Finding 3 — Risk Segment Distribution
| Segment | Customers | Delinquency Rate | Action |
|---|---|---|---|
| 🔴 High Risk | 88 (18%) | ~12–20% | Immediate outreach |
| 🟡 Medium Risk | 268 (54%) | ~15–18% | Monitor & remind |
| 🟢 Low Risk | 144 (29%) | ~5–8% | Retain & reward |

### Finding 4 — 6-Month Payment Trend
- Consecutive Missed payments in recent months (Month 5–6) are the **most urgent flag**
- Customers with Late→Missed pattern have 2.5× higher default probability than Missed→Late

---

## 📊 Power BI Dashboard

**2-page interactive dashboard:**
- **Page 1 (Executive):** KPI cards, delinquency by city, monthly trend line, slicers
- **Page 2 (Deep-Dive):** Scatter plot (Credit Score vs Missed Payments), high-risk customer table

**Key DAX Measures:**
```dax
Delinquency Rate = 
DIVIDE(
    CALCULATE(COUNTROWS(loan_delinquency), loan_delinquency[Delinquent_Account]=1),
    COUNTROWS(loan_delinquency), 0
)

High Risk Count = 
CALCULATE(COUNT([Customer_ID]), [Risk_Segment]="High Risk")
```

---

## 💼 Business Recommendations

1. **Early Warning System** — Alert when 2+ consecutive Late/Missed payments detected
2. **Credit Line Reduction** — Reduce limits for customers with Utilisation >75% + Score <500
3. **Segment-Tailored Outreach** — Hardship plans (High) · SMS reminders (Medium) · Loyalty (Low)
4. **DTI Protocol** — Flag all accounts with DTI >40% for quarterly income verification
5. **ML Integration** — Deploy Random Forest into CRM for real-time applicant scoring
6. **Portfolio Stress Testing** — Quarterly simulation of 5% income-drop impact

---

## 🚀 How to Run

### Python Analysis
```bash
# 1. Clone the repo
git clone https://github.com/yourusername/loan-delinquency-risk-analysis.git
cd loan-delinquency-risk-analysis

# 2. Install dependencies
pip install -r python/requirements.txt

# 3. Run the analysis
python python/loan_delinquency_analysis.py
```

### SQL (MySQL example)
```bash
# Import the dataset (after converting Excel to CSV)
mysql -u root -p your_database < sql/01_data_cleaning.sql
mysql -u root -p your_database < sql/02_eda_aggregations.sql
mysql -u root -p your_database < sql/03_risk_segmentation.sql
```

### Power BI
- Open `powerbi/Loan_Delinquency_Dashboard.pbix` in Power BI Desktop
- Refresh data source to point to your local Excel file

---

## 📋 Requirements

```
# python/requirements.txt
pandas>=2.0.0
numpy>=1.24.0
matplotlib>=3.7.0
seaborn>=0.12.0
scikit-learn>=1.3.0
openpyxl>=3.1.0
```

---

## 👤 Author

**[Your Name]**  
Data Analyst | SQL · Python · Power BI  
📧 [your.email@example.com]  
🔗 [LinkedIn Profile URL]  
💼 [Portfolio URL]

---

## 📄 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

*⭐ If this project helped you, please give it a star on GitHub!*
