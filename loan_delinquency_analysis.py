"""
=============================================================
  LOAN DELINQUENCY PREDICTION — END-TO-END ANALYSIS
  Author: [Your Name]
  Dataset: Delinquency_prediction_dataset.xlsx (500 customers)
  Tools: Python · pandas · seaborn · scikit-learn
=============================================================
"""

# ─── 1. IMPORTS ──────────────────────────────────────────────────────────────
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import (classification_report, confusion_matrix,
                             roc_auc_score, roc_curve)
import warnings
warnings.filterwarnings("ignore")

# ─── 2. LOAD DATA ────────────────────────────────────────────────────────────
print("=" * 60)
print("STEP 1 — LOADING DATA")
print("=" * 60)

import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
file_path = os.path.join(BASE_DIR, "Delinquency_prediction_dataset.xlsx")

df = pd.read_excel(file_path)
print(f"✅ Dataset loaded: {df.shape[0]} rows × {df.shape[1]} columns")
print(df.head(3).to_string())

# ─── 3. DATA CLEANING ────────────────────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 2 — DATA CLEANING")
print("=" * 60)

# Standardise Employment_Status
emp_map = {
    "EMP": "Employed", "employed": "Employed", "Employed": "Employed",
    "Self-employed": "Self-employed",
    "Unemployed": "Unemployed",
    "retired": "Retired"
}
df["Employment_Status"] = df["Employment_Status"].map(emp_map).fillna("Employed")

# Fill missing Income and Loan_Balance with median (robust to outliers)
df["Income"].fillna(df["Income"].median(), inplace=True)
df["Loan_Balance"].fillna(df["Loan_Balance"].median(), inplace=True)
df["Credit_Score"].fillna(df["Credit_Score"].median(), inplace=True)

# Clamp Credit_Utilization outliers (cap at 1.0 = 100%)
df["Credit_Utilization"] = df["Credit_Utilization"].clip(upper=1.0)

# Encode monthly payment behaviour: count Missed / Late payments
for col in ["Month_1", "Month_2", "Month_3", "Month_4", "Month_5", "Month_6"]:
    df[col] = df[col].str.strip()
df["Missed_Count"] = df[["Month_1","Month_2","Month_3","Month_4","Month_5","Month_6"]].apply(
    lambda r: (r == "Missed").sum(), axis=1
)
df["Late_Count"] = df[["Month_1","Month_2","Month_3","Month_4","Month_5","Month_6"]].apply(
    lambda r: (r == "Late").sum(), axis=1
)

print(f"Missing values after cleaning:\n{df.isnull().sum()[df.isnull().sum()>0]}")
print(f"\nDelinquent Rate: {df['Delinquent_Account'].mean()*100:.1f}%  "
      f"({df['Delinquent_Account'].sum()} of {len(df)} customers)")

# ─── 4. EDA — SUMMARY STATS ──────────────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 3 — EXPLORATORY DATA ANALYSIS")
print("=" * 60)

num_cols = ["Age","Income","Credit_Score","Credit_Utilization",
            "Missed_Payments","Loan_Balance","Debt_to_Income_Ratio"]
print(df[num_cols].describe().round(2).to_string())

# ─── 5. VISUALISATIONS ───────────────────────────────────────────────────────
sns.set_theme(style="whitegrid", palette="muted")
ACCENT  = "#0D9488"   # teal
DANGER  = "#E11D48"   # red
NEUTRAL = "#64748B"   # slate

fig, axes = plt.subplots(2, 3, figsize=(16, 10))
fig.suptitle("Loan Delinquency — Exploratory Data Analysis", fontsize=16,
             fontweight="bold", y=1.01)

# 5a — Delinquency distribution
ax = axes[0, 0]
vals = df["Delinquent_Account"].value_counts()
ax.bar(["Non-Delinquent (0)", "Delinquent (1)"],
       vals[[0, 1]], color=[ACCENT, DANGER], edgecolor="white", width=0.5)
for i, v in enumerate(vals[[0, 1]]):
    ax.text(i, v + 3, f"{v}\n({v/len(df)*100:.1f}%)", ha="center", fontsize=10)
ax.set_title("Class Distribution")
ax.set_ylabel("Count")

# 5b — Credit Score by Delinquency
ax = axes[0, 1]
for label, grp, colour in [(0, df[df["Delinquent_Account"]==0], ACCENT),
                            (1, df[df["Delinquent_Account"]==1], DANGER)]:
    ax.hist(grp["Credit_Score"], bins=20, alpha=0.6, color=colour,
            label=f"{'Non-' if label==0 else ''}Delinquent")
ax.set_title("Credit Score Distribution")
ax.set_xlabel("Credit Score")
ax.legend()

# 5c — Missed Payments vs Delinquency
ax = axes[0, 2]
grp = df.groupby("Missed_Payments")["Delinquent_Account"].mean() * 100
ax.bar(grp.index, grp.values, color=DANGER, edgecolor="white")
ax.set_title("Delinquency Rate by Missed Payments")
ax.set_xlabel("Missed Payments")
ax.set_ylabel("Delinquency Rate (%)")

# 5d — Credit Utilisation Boxplot
ax = axes[1, 0]
df.boxplot(column="Credit_Utilization", by="Delinquent_Account", ax=ax,
           notch=True, patch_artist=True,
           boxprops=dict(facecolor=ACCENT, color=NEUTRAL),
           medianprops=dict(color=DANGER, linewidth=2))
ax.set_title("Credit Utilisation vs Delinquency")
ax.set_xlabel("Delinquent Account (0=No, 1=Yes)")
ax.set_ylabel("Credit Utilisation")
plt.sca(ax)
plt.title("Credit Utilisation vs Delinquency")

# 5e — Delinquency Rate by Employment Status
ax = axes[1, 1]
emp_rate = (df.groupby("Employment_Status")["Delinquent_Account"]
              .mean()
              .sort_values(ascending=False) * 100)
emp_rate.plot(kind="barh", ax=ax, color=ACCENT, edgecolor="white")
ax.set_title("Delinquency Rate by Employment")
ax.set_xlabel("Delinquency Rate (%)")

# 5f — Correlation Heatmap
ax = axes[1, 2]
corr = df[num_cols + ["Delinquent_Account"]].corr()
sns.heatmap(corr[["Delinquent_Account"]].drop("Delinquent_Account"),
            annot=True, fmt=".2f", cmap="RdYlGn_r", ax=ax,
            linewidths=0.5, cbar=False)
ax.set_title("Correlation with Delinquency")

plt.tight_layout()
plt.savefig("eda_charts.png", dpi=150, bbox_inches="tight")
plt.close()
print("\n✅ EDA charts saved → eda_charts.png")

# ─── 6. PREDICTION MODEL ─────────────────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 4 — PREDICTION MODEL (Random Forest)")
print("=" * 60)

le = LabelEncoder()
for col in ["Employment_Status", "Credit_Card_Type", "Location"]:
    df[col + "_enc"] = le.fit_transform(df[col])

features = ["Age","Income","Credit_Score","Credit_Utilization",
            "Missed_Payments","Loan_Balance","Debt_to_Income_Ratio",
            "Account_Tenure","Missed_Count","Late_Count",
            "Employment_Status_enc","Credit_Card_Type_enc","Location_enc"]

X = df[features]
y = df["Delinquent_Account"]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

model = RandomForestClassifier(n_estimators=200, max_depth=6, random_state=42,
                               class_weight="balanced")
model.fit(X_train, y_train)
y_pred = model.predict(X_test)
y_prob = model.predict_proba(X_test)[:, 1]

print(f"\nClassification Report:\n{classification_report(y_test, y_pred)}")
print(f"ROC-AUC Score: {roc_auc_score(y_test, y_prob):.4f}")

# Feature Importance Plot
fig, axes = plt.subplots(1, 2, figsize=(14, 5))

fi = pd.Series(model.feature_importances_, index=features).sort_values()
fi.plot(kind="barh", ax=axes[0], color=ACCENT, edgecolor="white")
axes[0].set_title("Feature Importance (Random Forest)")
axes[0].set_xlabel("Importance Score")

fpr, tpr, _ = roc_curve(y_test, y_prob)
axes[1].plot(fpr, tpr, color=DANGER, lw=2,
             label=f"ROC (AUC = {roc_auc_score(y_test, y_prob):.2f})")
axes[1].plot([0,1],[0,1], "k--", lw=1)
axes[1].set_xlabel("False Positive Rate")
axes[1].set_ylabel("True Positive Rate")
axes[1].set_title("ROC Curve")
axes[1].legend()

plt.tight_layout()
plt.savefig("model_results.png", dpi=150, bbox_inches="tight")
plt.close()
print("✅ Model charts saved → model_results.png")

# ─── 7. RISK SEGMENTATION ────────────────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 5 — RISK SEGMENTATION")
print("=" * 60)

def risk_segment(row):
    score = 0
    if row["Missed_Payments"] >= 4: score += 2
    elif row["Missed_Payments"] >= 2: score += 1
    if row["Credit_Score"] < 450: score += 2
    elif row["Credit_Score"] < 600: score += 1
    if row["Credit_Utilization"] > 0.75: score += 1
    if row["Debt_to_Income_Ratio"] > 0.4: score += 1
    if score >= 4: return "High Risk"
    elif score >= 2: return "Medium Risk"
    return "Low Risk"

df["Risk_Segment"] = df.apply(risk_segment, axis=1)
print(df.groupby("Risk_Segment").agg(
    Customers=("Customer_ID","count"),
    Delinquency_Rate=("Delinquent_Account","mean"),
    Avg_Credit_Score=("Credit_Score","mean"),
    Avg_Missed=("Missed_Payments","mean")
).round(2))

print("\n✅ Analysis complete! Files generated:")
print("   • eda_charts.png")
print("   • model_results.png")
