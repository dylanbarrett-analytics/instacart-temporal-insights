# Instacart Temporal Buying Patterns

---

## **Introduction**

Understanding *when* people shop is arguably more important than understanding *what* they buy — because timing reveals collective habits, while products reflect personal taste. This project analyzes over 3 million Instacart orders to discover temporal behavior patterns, highlighting how time segments (hour of the day, day of the week) influence **reorder speed**, **order size**, and **routine consistency**.

The **Repurchase Momentum Index (RMI)** combines speed, volume, and consistency into a single metric, and with its implementation, this project is able to identify time segments where customer behavior is not just active, but also **predictably repeatable**. Behavioral insights of this magnitude support business strategies that align with customer habits while avoiding too much arbitrary estimation and guesswork.

### **What is Instacart?**

Instacart is a North American grocery delivery and pickup service that allows customers to order groceries online from local stores. It offers users a convenient alternative to in-store shopping by combining a large product catalog with personalized recommendations and scheduling flexibility.

---

## **About the Dataset**

This dataset was originally released by Instacart for a Kaggle competition. It includes anonymized data on:

- **3.4 million orders**
- **Over 50,000 unique products**
- **Aisle and department categorizations**
- **Customer-level purchase sequences**
- **Timestamps of every order**

The files used in this project are:

- `orders.csv` — metadata for every order
- `order_products__prior.csv` — line-item detail for each prior order (main historical data)
- `products.csv`, `aisles.csv`, `departments.csv` — lookup tables for product names, aisle names, and department names

**Note:** The `order_products__train.csv` file is included but it will not be used in this analysis, as this project does not have a true predictive modeling focus.

---

## **Project Goal**

The goal of this project is to analyze how time-based elements affect customer behavior *at a collective level* — across reorder speed, order size, and routine consistency — and to combine these patterns into a standardized behavioral index (RMI) that captures **momentum and predictability** over time.

---

## **Table of Contents**

- [Introduction](#introduction)
- [What is Instacart?](#what-is-instacart)
- [About the Dataset](#about-the-dataset)
- [Project Goal](#project-goal)
- [Tools Used](#tools-used)
- [Project Files](#project-files)
- [Step 1: Set Schema Context](#step-1-set-schema-context)
- [Step 2: Data Preparation](#step-2-data-preparation)
- [Step 3: Import Raw Data](#step-3-import-raw-data)
- [Step 4: Data Sanity Check](#step-4-data-sanity-check)
- [Step 5a: Temporal Analysis Prep](#step-5a-temporal-analysis-prep)
- [Step 5b: Repurchase Cycle by Time Segment](#step-5b-repurchase-cycle-by-time-segment)
- [Step 5c: Order Size by Time Segment](#step-5c-order-size-by-time-segment)
- [Step 6: Repurchase Momentum Index (RMI)](#step-6-repurchase-momentum-index-rmi)
- [Step 7: Supporting Behavioral Metrics](#step-7-supporting-behavioral-metrics)
- [Final Dashboard Overview](#final-dashboard-overview)
- [Final Thoughts](#final-thoughts)
- [Dashboard](#dashboard)

---

## **Tools Used**
- PostgreSQL (via pgAdmin 4) — for database setup and management
- SQL — used for data transformation, joins, aggregations, and filtering
- Tableau — used for final visualizations

---

## **Project Files**
| File | Description |
|------|-------------|
| `01_create_tables.sql` | Creates base and lookup tables |
| `02_import_data.sql` | Imports CSV datasets |
| `03_data_validation.sql` | Performs row count and preview checks |
| `04_analysis_queries.sql` | Contains all analytical SQL steps (Steps 5-7) |
| `05_export_tables.sql` | References final tables for Tableau import |

---

## **Step 1: Set Schema Context**

**Goal:**  
Ensure all tables are created within the correct project schema (`instacart`)

**Actions Taken:**  
- Used `SET search_path TO instacart;` to define the default schema for the project

**Purpose:**  
Avoids repetitive schema prefixes in SQL scripts and ensures clean table organization throughout the duration of the project.

---

## **Step 2: Data Preparation**

**Goal:**  
Create base tables that mirror the structure of the original Instacart CSV datasets

**Actions Taken:**  
- Created tables for 6 core datasets: `orders`, `order_products__prior`, `order_products__train`, `products`, `aisles`, and `departments`  
- Assigned appropriate data types to each column

**Purpose:**  
Establish a relational database structure to enable accurate data merging and analysis in future steps.

---

## **Step 3: Import Raw Data**

**Goal:**  
Load all CSV files into their corresponding SQL tables using the `COPY` command

**Actions Taken:**  
- Imported the following datasets:
  - `orders`
  - `order_products__prior`
  - `order_products__train`
  - `products`
  - `aisles`
  - `departments`  
- Confirmed UTF-8 encoding and delimiter alignment

**Purpose:**  
Populate the schema with the Instacart data for analysis.

---

## **Step 4: Data Sanity Check**

**Goal:**  
Verify that all tables were successfully created and populated.

**Actions Taken:**  
- Ran `SELECT COUNT(*)` to confirm row totals per table  
- Ran `SELECT * LIMIT 10` to preview structure and values in each table

**Purpose:**  
Confirm that the import process worked and that all tables are ready for analysis.

---

## **Step 5a: Temporal Analysis Prep**

**Goal:**
Prepare core metrics to analyze how time-related dimensions affect purchasing behavior

**Actions Taken:**
- Extracted time-based fields from the `orders` table:
  - `order_hour_of_day`, `order_dow` (day of week), and a `weekday_or_weekend` flag (created from a case statement)
- Filtered out 'train' and 'test' sets from the eval_set column to ensure full user purchase history is complete
- Calculated **order size** by counting the number of products for each order from the `order_products__prior` table
- Joined time-based fields and order sizes into a single table for the analysis
  - A `LEFT JOIN` was used to ensure that all orders from the `orders` table are retained, even if some orders do not have any matching product entries in the `order_products__prior` table

**Purpose:**
This creates a foundational order-level table that will be used to identify **temporal shopping patterns**.

---

## **Step 5b: Repurchase Cycle by Time Segment**

**Goal:**
Analyze how time-based factors influence the reorder speed (and volume) of customers

**Actions Taken:**
- Used the `time_order_metrics` table (from Step 5a)
- Grouped by hour of day, day of week, and weekday/weekend to calculate:
  - average repurchase cycle
  - number of orders
- Filtered out first-time orders where `repurchase_cycle` IS NULL
- Saved all three time segment outputs as tables:
  - `repurchase_cycle_by_hour`
  - `repurchase_cycle_by_day`
  - `repurchase_cycle_weekday_or_weekend`

**Purpose:**
This explores how different time segments influence both customer reordering speed and the total number of orders.

---

## **Step 5c: Order Size by Time Segment**

**Goal:**
Analyze how time-based factors influence customer order size

**Actions Taken:**
- Used the `time_order_metrics` table (from Step 5a)
- Grouped by hour of day, day of week, and weekday/weekend to calculate:
  - average order size
  - number of orders
  - total item volume (average order size * number of orders)
- Filtered out first-time orders where `order_size` IS NULL
- Saved all three time segment outputs as tables:
  - `order_size_by_hour`
  - `order_size_by_day`
  - `order_size_weekday_or_weekend`

**Purpose:**
This explores when customers tend to place larger orders and when overall item volume is highest (with regard to each time segment).

**Semantics ("Total Item Volume" vs. "Estimated Total Item Volume"):**
If I were working with a partial dataset, the product of average order size and number of orders would be referred to as "Estimated Total Item Volume." In the world of statistics, we estimate population-level metrics by extrapolating from a sample. However, this is not necessary in this case because I am working with a full dataset, so "Total Item Volume" will suffice here. (This may sound pedantic, but it's actually an important distinction.)

---

## **Step 6: Repurchase Momentum Index (RMI)**

**Goal:**
Quantify the behavioral strength of each hour + day segment by combining repurchase cycle and total item volume (scaled)

**Actions Taken:**
- Used `time_order_metrics` (from Step 5a) to group by hour of day and day of week
- Calculated:
  - average repurchase cycle
  - average order size
  - number of orders
  - repurchase cycle lift
  - the natural log of total_item_volume
  - raw RMI = repurchase_cycle_lift * ln(total item volume)
- Rescaled the raw RMI into a standardized 0-10 range

**Purpose:**
The standardized **Repurchase Momentum Index (RMI)** captures **how fast** customers return to shop and **how much** they buy when they do so. This combination of speed and volume provides a great snapshot of behavioral intensity across time segments — such as "Thursday at 9 AM." Using this approach, high-opportunity time segments can be identified based on collective behavior.

In the previous project (*Instacart Product Buying Patterns*), **Influence Index (II)** was the primary KPI, but it only focused on **product-level strength** tied to **personal shopping habits**. The **RMI**, by contrast, measures **time-based momentum** tied to **collective shopping habits**, offering a much clearer view of **predictability** with regard to the entire customer base. 

**Note:**
Instead of simply using the raw total item volume, I used the **natural log** of the total item volume. This logarithmic transformation helps to reduce the impact of overpowering high-volume outliers, so they don't skew the data. This natural log application models **diminishing returns** — a key concept in both statistics and behavioral analytics.
> For example, an increase in total item volume from **1 to 2** (100% increase) has a much more significant impact on the data story than an increase from **1000 to 1001** (0.1% increase). As volume increases, every (identical) increase becomes **less and less meaningful** when it comes to the context of **behavioral momentum**. Logarithmic scaling reflects this statistical reality while still retaining every data point in the analysis.

---

## **Step 7: Supporting Behavioral Metrics**

**Goal:**
Add additional context to the Repurchase Momentum Index by calculating key statistical metrics for each hour + day segment

**Actions Taken:**
- Used `time_order_metrics` (from Step 5a) to group by hour of day and day of week
- Calculated:
  - **order size lift** = local average order size - global average order size
  - **repurchase cycle lift** = global average repurchase cycle - local average repurchase cycle
  - **standard deviation** of order size and repurchase cycle
  - **z-score** of order size and repurchase cycle (centered and scaled)

**Purpose:**
These metrics provide more structure for Repurchase Momentum Index
- The lift metrics display **behavioral deviation**
- Standard deviation reveals **behavioral consistency**
- Z-scores offer a **standardized comparison scale** across all time segments

**Note:**
While both lifts measure behavioral deviation, they are **directionally opposite**:
- For **order size**, *higher* is better — indicates larger orders (more items)
  - This is why **order size lift** is calculated as *(local average - global average)* where more positive values are better
- For **repurchase cycle**, *lower* is better — indicates faster returns (less days)
  - This is why **repurchase cycle lift** is calculated as *(global average - local average)* where more negative values are better

**Rescaling Insight:**
After rescaling both order size lift and repurchase cycle lift to a 0-10 range (in Tableau), it turns out that the **average of the rescaled order size lift** is 4.026, while the **average of the rescaled repurchase cycle lift** is 5.871. With the latter having a noticeably higher average, this confirms that **reorder speed** has a higher behavioral impact than **order size**.
> In so many words, a customer making the decision *to initiate shopping* is more behaviorally significant than the customer's decision *to add additional items* to the cart when already shopping.

---

## **Final Dashboard Overview**

The final Tableau dashboard explores how different time segments affect Instacart purchase behavior, using a combination of **speed, volume, and consistency** metrics.

The heart of this dashboard is the **Repurchase Momentum Index (RMI)** — a standardized score that captures **how fast customers return** (reorder speed), **how much they buy** (order size), and **how consistent this purchasing behavior is** across large volumes of orders. This index balances urgency and quantity while modeling behavioral momentum over time.

**Visualizations:**

- **Scatterplot (Reorder Speed vs. Order Size)** segments temporal patterns by shopping routines. Smaller, frequent routines stand out in the top-left quadrant, having the largest RMIs of any quadrant. The size of each data point reflects RMI, which gives users a simple way to visually spot high-impact time windows. 

- **RMI by Hour** and **RMI by Day** reveal when the strongest patterns occur on an hourly and daily basis, respectively. The 7-9 AM and 8-10 PM windows featured the most predictable customer behavior, while during the week, Wednesday thru Friday showed the most predictable customer behavior.

**KPIs include:**

- **Repurchase Momentum Index**
- **Time Segment**
- **Total Orders**
- **Total Item Volume** (a.k.a. total items purchased)
- **Reorder Speed** (scaled 0-10)
- **Order Size** (scaled 0-10)

> To maintain clarity, both KPIs and filters are click-based. This design emphasizes **natural discovery** over dropdown filtering, encouraging users to explore and interact with curiosity.

---

## **Final Thoughts**

My previous project (*Instacart Behavioral Product Patterns*) heavily featured **frequency** and **volume** when it came to purchasing behavior at the individual customer level. While these two measures are certainly impactful and they convey a solid storyline, they didn't tell the full story about the customer base's behavior at scale. In this particular project, incorporating **time elements** opens the door for **behavioral predictability**. This helps uncover moments when shopping patterns are not only strong (customer to customer), but also **reliable** (across the entire customer base).

For business intelligence operations, the awareness of this customer base predictability creates opportunities for strategies that align with high-consistency routines, such as time-targeted promotions and optimized push notifications.

In the real world, **timing is everything**. And this project proves it with data. 

---

## **Dashboard**

[Instacart Temporal Buying Patterns (Tableau Public)](https://public.tableau.com/app/profile/dylan.barrett1539/viz/InstacartTemporalBuyingPatterns/Dashboard)
