# 🚇 Delhi Transit Network Analysis

### SQL + Power BI | Public Transport Operations, Coverage & Service Equity

An end-to-end Business Analytics project analysing Delhi's public bus transit network using **MySQL and Power BI**.

The project transforms raw transit schedule data into a structured analytical dataset and interactive Power BI dashboard to understand **network coverage, service concentration, operator performance, route structure, service frequency, headway consistency, and potential accessibility gaps**.

The analysis combines SQL data transformation and advanced querying with Power BI visualisation to answer a practical business question:

> **How effectively is Delhi's bus network serving passengers across routes, operators, time periods and locations?**

---

# 🎯 Business Problem

Public transport networks generate large amounts of operational data, but raw schedule data does not directly answer the questions that matter to transport planners and decision-makers.

For Delhi's bus network, several questions are important:

- Which routes and operators provide the most service?
- How is service distributed across the day?
- Are some stops or areas significantly better served than others?
- Which stops act as major interchange hubs?
- How consistent are bus headways?
- Are there stops with very limited or no scheduled service?
- How concentrated is the network's service?
- Are there directional or operational imbalances?
- Which routes have unusually long travel distances or service spans?

This project converts the underlying transit schedule data into **decision-oriented insights** through SQL analysis and an interactive Power BI dashboard.

---

# 💡 Analytical Objective

The project was designed around three major analytical themes:

### 1. Network Overview
Understand the size and structure of Delhi's transit network.

### 2. Coverage & Equity
Identify how evenly service is distributed across stops and locations.

### 3. Operator Comparison
Compare DTC and DIMTS across routes, trips, stops and service patterns.

---

# 🧠 Analysis Framework

```text
Raw Transit Data
       ↓
Data Structure & Quality Review
       ↓
SQL Data Transformation
       ↓
Reusable Analytical Views
       ↓
Network KPIs
       ↓
Coverage & Service Analysis
       ↓
Operator Analysis
       ↓
Power BI Data Model
       ↓
Interactive Dashboard
       ↓
Business Insights
````

---

# 🗂️ Data Structure

The analysis works with transit entities including:

* Agencies
* Routes
* Trips
* Stops
* Stop Times
* Calendar / service information

The SQL workflow first examines the underlying tables and their relationships before creating analytical views.

Because the raw transit data contains route variants, repeated stop events and non-standard time values, the first stage focuses on **structuring the data for analysis rather than directly visualising raw tables**.

---

# 🛠️ SQL Data Preparation

A major part of the project was creating reusable SQL views instead of repeatedly writing the same transformation logic.

## Route Transformation

The `v_routes` view:

* Connects routes with their operating agency
* Extracts a base route identifier
* Separates route direction into UP / Down
* Helps prevent route-variant inflation when counting actual routes

This is important because simply counting route records can overstate the actual number of underlying routes.

The analysis explicitly compares **route variants vs real/base routes**. 

---

# ⏱️ Time Normalisation

Transit schedules can contain departure times beyond the conventional 24-hour clock.

For example, a trip may continue past midnight and contain values such as `30:20:51`.

Instead of treating these values as invalid, the SQL model preserves them and creates analytical fields including:

* Departure seconds
* Raw hour
* Normalised hour of day
* Post-midnight indicator

This makes the dataset suitable for hourly service analysis without losing overnight trips. 

The analysis identifies **20,505 stop events occurring after 24:00**, demonstrating why standard time casting would have caused problems with this dataset. 

---

# 🚌 Trip-Level Analysis

The `v_trip_summary` view creates one analytical record per trip.

It captures:

* Route
* Stop count
* Start time
* End time
* Scheduled trip duration
* Starting hour

This creates a clean trip-level layer that can be used for route and operational analysis. 

---

# 📍 Geographic & Segment Analysis

The project calculates the distance between consecutive stops using the **Haversine formula**.

For every trip, the SQL model calculates:

* Previous stop
* Current stop
* Time elapsed between stops
* Geographic distance between stops

This enables analysis of:

* Stop spacing
* Route distance
* Potential data anomalies
* Approximate route speed

The segment-level calculation is implemented through window functions such as `LAG()` combined with geographic coordinates. 

---

# 📊 Key SQL Analyses

The project contains a series of analytical queries designed to answer operational and business questions.

---

## 1. Network Scale

The analysis measures:

* Total stops
* Number of underlying/base routes
* Route variants
* Daily trips
* Stop events

These metrics establish the overall scale of the transit network. 

---

## 2. Route Variant Inflation

One important data-quality/business insight is that the number of route records is not necessarily equal to the number of actual routes.

The analysis calculates:

```text
Route Variants per Real Route
=
Total Route Rows / Distinct Base Routes
```

This prevents misleading network-size reporting caused by multiple route variants. 

---

## 3. Operator Comparison

The project compares the two major operators across:

* Real routes
* Route variants
* Trips
* Stops served

This creates the basis for the **Operator Comparison** dashboard. 

---

# ⏰ 4. Hourly Service Profile

The project analyses when trips begin throughout the day.

It calculates:

* Trips starting per hour
* Percentage of daily trips
* Cumulative service contribution

Peak periods are also analysed separately, including:

* Morning peak
* Evening peak
* Night service

This helps understand how transit capacity is distributed throughout the day. 

---

# 🏆 5. Busiest Routes

Routes are ranked within each operator based on the number of scheduled trips.

A `DENSE_RANK()` window function is used to identify the highest-service routes for each operator. 

This supports questions such as:

> Which routes carry the largest scheduled service load?

---

# ⚖️ 6. Service Concentration & Equity

One of the most important analyses in the project is service concentration.

Stops are divided into **deciles based on service volume**, allowing the analysis to measure what percentage of total service is concentrated among different groups of stops.

This moves the analysis beyond simply asking:

> "How many buses operate?"

and toward:

> "How evenly is service distributed across the network?" 

---

# 🚏 7. Underserved Stops

The analysis identifies stops receiving very limited scheduled service.

Stops with **three or fewer trips** are flagged as potential low-service locations.

The analysis captures:

* Stop name
* Trips serving the stop
* Routes serving the stop
* First service hour
* Last service hour

This creates a useful starting point for identifying potential service-access gaps. 

---

# ❌ 8. Stops With No Service

The project also checks for stops that exist in the stop master but have no corresponding scheduled service events.

This is done using a `LEFT JOIN` between stops and stop-time records. 

This is particularly useful from a **data-quality and coverage perspective**.

---

# 🔄 9. Interchange Hubs

The project identifies major interchange locations based on:

* Number of routes serving the stop
* Number of service events
* Number of operators serving the location

The highest-connected stops can therefore be interpreted as potential transit interchange hubs. 

---

# 🛣️ 10. Route & Stop Connectivity

The analysis examines how many routes serve each stop.

It calculates:

* Minimum routes per stop
* Average routes per stop
* Maximum routes per stop
* Number of single-route stops
* Percentage of stops served by only one route

This helps distinguish between highly connected transit locations and stops dependent on a single route. 

---

# 🏢 11. Operator Dependency

The project also measures how dependent stops are on a single operator.

This identifies stops where service is provided by only one of the analysed operators.

Such locations may have lower operator redundancy and therefore potentially fewer alternatives when service is disrupted. 

---

# ⏱️ 12. Headway Consistency

Average frequency alone can hide irregular service.

For this reason, the project calculates:

* Average headway
* Standard deviation
* Minimum gap
* Maximum gap
* Coefficient of variation

The coefficient of variation is particularly useful because it measures **headway consistency relative to the average interval**.

Routes can therefore be compared based on how evenly buses are spaced rather than simply how frequently they operate. 

---

# 🕐 13. Service Span

The analysis calculates the operating span of routes using:

* First departure
* Last departure
* Total service span
* Number of trips

This allows routes to be compared on the duration of their scheduled operating window. 

The SQL analysis reports a **network average service span of approximately 11.4 hours**. 

---

# 📏 14. Trip & Route Length

Trip-level analysis examines the number of stops covered by each trip.

The dataset shows:

* Minimum: 2 stops
* Average: 41.7 stops
* Maximum: 169 stops

The analysis also calculates route distance from consecutive stop segments. 

The resulting route-distance analysis reports:

* Network average route length: **22.9 km**
* Maximum route length: **121.3 km**



---

# 🔀 15. Directional Imbalance

The project checks whether routes have both UP and DOWN variants.

The analysis identifies:

**82 routes operating in only one direction.**

This creates an important operational insight because a passenger may have scheduled service in one direction without an equivalent scheduled return route. 

---

# 🌙 16. Overnight Service

Instead of dropping trips that extend beyond midnight, the project explicitly identifies post-midnight service.

This allows overnight operations to be analysed separately while preserving the original schedule structure. 

---

# 🚦 17. Route Speed Analysis

The final SQL analysis calculates average route speed by combining:

**Total route distance ÷ total elapsed travel time**

This allows routes to be ranked by calculated average speed and provides another operational lens beyond simple route frequency. 

---

# 📊 Power BI Dashboard

The SQL output is transformed into an interactive Power BI dashboard designed around three analytical views.

---

## 🏙️ Page 1 — Network Overview

Provides a high-level view of the Delhi transit network.

The page focuses on metrics such as:

* Network size
* Stops
* Routes
* Trips
* Service distribution
* Geographic network structure

The purpose is to allow a decision-maker to understand the network at a glance before drilling into individual operational dimensions.

---

## ⚖️ Page 2 — Coverage & Equity

Focuses on how service is distributed across the network.

Key analytical areas include:

* Stop coverage
* Service concentration
* Low-service stops
* Route connectivity
* Geographic distribution
* Potential service gaps

The goal is to move beyond network size and evaluate **whether service is distributed evenly across locations**.

---

## 🚌 Page 3 — Operator Comparison

Compares DTC and DIMTS across operational metrics.

The analysis looks at differences in:

* Routes
* Route variants
* Trips
* Stops served
* Hourly service
* Service patterns

This provides a comparative view of how the two operators contribute to the overall transit network.

---

# 🔍 Data Quality Checks

A key part of the project was not treating the dataset as perfectly clean.

Several potential data-quality issues were explicitly investigated:

### Route Duplication

Multiple route variants can inflate route counts.

### Non-standard Time Values

Trips can contain times beyond 24:00.

### Extreme Stop Gaps

The segment analysis identifies unusually large geographic gaps between consecutive stops.

For example, the SQL analysis finds a maximum consecutive-stop distance of approximately **37.1 km**, which is flagged as a likely data issue rather than treated as a normal stop spacing value. 

### Missing Service

Stops existing in the stop master without service events are separately identified.

These checks improve confidence in the downstream analysis.

---

# 🧰 Tools & Technologies

### SQL / MySQL

* MySQL
* CTEs
* Window Functions
* `LAG()`
* `LEAD()`
* `DENSE_RANK()`
* `NTILE()`
* Conditional Aggregation
* Correlated Subqueries
* Views
* Temporary analytical tables
* String / Regex transformations
* Time transformations
* Haversine distance calculation

### Power BI

* Data modelling
* KPI cards
* Interactive dashboards
* Geographic visualisation
* Service distribution analysis
* Operator comparison
* Filtering and drill-down analysis

---

# 📁 Repository Structure

```text
Delhi-Transit-Analysis/
│
├── 📄 README.md
│
├── 🗄️ delhi.sql
│   └── SQL data preparation, analytical views and business queries
│
└── 📊 Delhi_Transit.pbix
    └── Interactive Power BI dashboard
```

---

# 📌 Key Business Insights

The analysis demonstrates several important characteristics of the transit network:

### 1. Route counts can be misleading

Route variants need to be normalised before measuring the actual route network.

### 2. Service is not necessarily evenly distributed

A small group of stops can account for a disproportionately large share of scheduled service.

### 3. Frequency and reliability are different

A route may have frequent service on average but still experience inconsistent headways.

### 4. Network connectivity varies significantly

Some stops function as major interchange points while others depend on a single route.

### 5. Data quality directly affects business conclusions

Non-standard times, duplicate route structures and geographic anomalies need to be addressed before drawing operational conclusions.

### 6. Operator contribution varies

DTC and DIMTS have different levels of route, trip and stop coverage, making operator-level analysis important for understanding the network.

---

# 💼 Business Analyst Skills Demonstrated

This project demonstrates practical Business Analytics and Business Analyst capabilities including:

* Business problem framing
* Data exploration
* Data quality assessment
* SQL-based data transformation
* KPI development
* Operational analysis
* Service coverage analysis
* Equity analysis
* Comparative analysis
* Trend and time-period analysis
* Geographic analysis
* Data validation
* Dashboard development
* Stakeholder-oriented storytelling
* Data-driven recommendations

---

# 🎯 Business Impact

The analytical framework can support transit planners and operations teams in areas such as:

* Identifying underserved stops
* Evaluating service concentration
* Comparing operator coverage
* Understanding peak-period capacity
* Identifying potential interchange hubs
* Monitoring headway consistency
* Investigating route-level operational anomalies
* Prioritising locations for deeper service analysis

The project demonstrates how raw transit schedules can be transformed into a **decision-support tool rather than simply a reporting dashboard**.

---

# 👩‍💼 Project Author

**Diya Singhal**

Business Analyst | Business Analytics | Data-driven Decision Making

This project was developed as part of a Business Analyst portfolio to demonstrate practical SQL analysis, Power BI dashboarding, data-quality investigation and operational business analysis.

---

⭐ If you found this project useful, feel free to explore the SQL analysis and Power BI dashboard included in this repository.
