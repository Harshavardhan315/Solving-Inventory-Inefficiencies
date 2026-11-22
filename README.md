# Urban Retail Inventory Optimization & Supply Chain Analytics

A comprehensive end-to-end data analytics solution built using **SQL** and **Power BI** to analyze inventory performance, optimize stock levels, evaluate supplier reliability, and reduce working capital inefficiencies across multiple stores and product categories for an Urban Retail company[cite: 1, 2, 6].

---

## 📋 Table of Contents
- [Project Overview](#project-overview)
- [Database Architecture & Schema](#database-architecture--schema)
- [Key Metrics & KPIs Tracked](#key-metrics--kpis-tracked)
- [Key Analytical Findings](#key-analytical-findings)
- [Strategic Recommendations](#strategic-recommendations)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)

---

## 🎯 Project Overview
Managing inventory across diverse regions and product categories requires balancing stock availability against holding costs[cite: 2, 3]. This project transforms raw, flat retail forecasting data (`inventory_forecasting`) into a normalized relational database[cite: 1, 5], computes advanced inventory and supplier KPIs via SQL, and visualizes actionable insights in an interactive Power BI dashboard.

---

## 🗄️ Database Architecture & Schema
The raw dataset is normalized into a structured relational model (5 core tables and 3 analytical views/tables)[cite: 1, 5]:

### Core Normalized Tables
* **`Product`**: Stores `ProductID`, `Category`, and category-specific `LeadTimeDays` (Groceries: 3 days, Toys: 4 days, Clothing: 5 days, Electronics: 7 days, Furniture: 10 days)[cite: 1, 5].
* **`Store`**: Maps `unique_storeid` (composite of `StoreID` and `Region`) to regional store locations[cite: 1, 5].
* **`Sales`**: Tracks daily `UnitsSold`, `UnitsOrdered`, `DemandForecast`, `WeatherCondition`, `HolidayPromotion`, `CompetitorPricing`, and `Seasonality`[cite: 1, 5].
* **`PriceHistory`**: Logs daily product `Price` and `Discount` percentages per store[cite: 1, 5].
* **`InventorySnapshot`**: Captures daily `InventoryLevel` and flags low-stock alerts (`LowLevelDetection`)[cite: 1, 5].

### Analytical Tables
* **`ProductROPandTurnover`**: Calculates store-level and product-level inventory turnover, categorizes items into movement quartiles (`Fast-Moving`, `Moderate`, `Slow-Moving`), and computes dynamic store-specific Reorder Points (ROP).
* **`kpi`**: Summarizes forecast-based `StockoutRate`, `AverageInventoryAge_Days` (Days Sales of Inventory), and `AvgInventoryValue`[cite: 1].
* **`SupplierPerformance`**: Evaluates replenishment intervals (`DeliveryLag`) against category lead times to flag on-time deliveries (`OnTimeFlag`)[cite: 1].

---

## 📊 Key Metrics & KPIs Tracked
* **Inventory Turnover:** $\frac{\text{Total Units Sold}}{\text{Average Inventory Level}}$[cite: 1, 2]
* **Reorder Point (ROP):** $(\text{Avg Daily Demand} \times \text{Lead Time}) + (0.84 \times \text{StdDev Daily Demand} \times \sqrt{\text{Lead Time}})$[cite: 1, 2]
* **Low Inventory Flag:** Triggered when current $\text{Inventory Level} < \text{Reorder Point}$[cite: 1, 2]
* **Stockout Rate:** $\left(\frac{\text{Total At-Risk Days where Inventory} < \text{Demand Forecast}}{\text{Total Days on Record}}\right) \times 100$[cite: 1, 2]
* **Inventory Age (DSI):** $\frac{\text{Average Inventory Value}}{\text{Average Daily COGS}}$[cite: 1, 2]
* **Supplier On-Time Rate:** Percentage of replenishment deliveries arriving within category `LeadTimeDays`[cite: 1, 2]

---

## 🔍 Key Analytical Findings
* **Widespread Inventory Shortfall:** **51.7%** of all product-store combinations are currently below their calculated Reorder Point (ROP)[cite: 3].
* **Insufficient Stock Coverage:** The company-wide average inventory age is only **1.51 days**, falling well short of product replenishment lead times (3 to 10 days) and driving frequent stockouts[cite: 3].
* **Inefficient Capital Allocation:** **25%** of all product-store combinations are classified as **Slow-Moving** (predominantly Electronics), tying up **25%** of total working capital[cite: 3].
* **Category-Specific Bottlenecks:**
  * **Clothing:** Highest turnover and most efficient category, but suffers the highest stockout rate at **15.9%**, resulting in significant lost revenue[cite: 3].
  * **Groceries:** Second-highest turnover category, experiencing recurring stockout risks[cite: 3].
  * **Furniture:** Poses the highest strategic supply chain risk due to its **10-day lead time**, making stockout recovery slow and costly[cite: 3].
  * **Electronics:** Slowest-moving category and the largest drain on tied-up inventory capital[cite: 3].

---

## 💡 Strategic Recommendations
1. **Immediate Replenishment:** Authorize urgent purchase orders for the **310 product-store combinations** flagged with low inventory levels[cite: 4].
2. **Re-invest in High-Velocity Categories:**
   * **Priority 1 (Clothing):** Increase safety stock thresholds to capture the **15.9%** of sales currently lost to stockouts[cite: 4].
   * **Priority 2 (Furniture):** Expand buffer stock to insulate operations against its long **10-day supplier lead time**[cite: 4].
3. **Liquidate Slow-Moving Capital:** Launch targeted clearance sales and promotional discounts on slow-moving Electronics (specifically SKUs **`P0031`**, **`P0068`**, and **`P0183`**) to free up the **25%** of working capital trapped in stagnant stock[cite: 4].

---

## 📁 Repository Structure
```text
├── inventory_analysis.sql     # Database normalization, DDL/DML scripts, and KPI calculations
├── CnA Report.pbix            # Interactive Power BI dashboard and data model
├── Executive Summary.pdf      # Project summary, key findings, and business recommendations
├── ERD Diagram.png            # Entity-Relationship Diagram of the normalized database
└── README.md                  # Project documentation
