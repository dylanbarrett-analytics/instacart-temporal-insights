-- ================================================================================
-- File: 04_analysis_queries.sql
-- Project: Instacart Temporal Buying Patterns
-- Author: Dylan Barrett
-- Last Updated: May 30, 2025
--
-- Description:
-- This script contains all major SQL steps used to analyze customer behavior
-- within the Instacart dataset — specifically focusing on how different time
-- segments affect reorder speed and order size.
--
-- Steps Included:
-- - Step 5a: Temporal Analysis Prep
-- - Step 5b: Repurchase Cycle by Time Segment
-- - Step 5c: Order Size by Time Segment
-- - Step 6: Repurchase Momentum Index (RMI)
-- - Step 7: Supporting Behavioral Metrics
-- ================================================================================

-- Set active schema context
SET search_path TO instacart;

-- --------------------------------------------------------------------------------
-- Step 5a: Temporal Analysis Prep
-- Goal: Prepare core metrics to analyze how time-related dimensions affect purchasing behavior

-- Logic:
-- 1. Extract hour of day, day of week, and weekday/weekend flag from orders table
-- 2. Count number of products per order to calculate order size across all orders
-- 3. Join both tables to produce one row per order with time and behavior metrics
-- --------------------------------------------------------------------------------
-- Extract time-based fields from the orders table
WITH time_dimensions AS (
	SELECT
		order_id,
		order_hour_of_day,
		order_dow,
		CASE
			WHEN order_dow BETWEEN 0 AND 4 THEN 'Weekday'
			ELSE 'Weekend'
		END AS weekday_or_weekend,
		days_since_prior_order AS repurchase_cycle
	FROM orders
	WHERE eval_set = 'prior'	-- filter to 'prior' orders only to ensure full user purchase history is complete ('train' and 'test' involve incomplete data)
),

-- Count number of products in each order (i.e., order size)
order_sizes AS (
	SELECT
		order_id,
		COUNT(*) AS order_size
	FROM order_products__prior
	GROUP BY order_id
)

-- Join time and behavior metrics at order-level
-- Save result as a temporary table for future reuse
SELECT
	td.order_id,
	order_hour_of_day,
	order_dow,
	weekday_or_weekend,
	repurchase_cycle,
	order_size
INTO TEMP time_order_metrics
FROM time_dimensions td
LEFT JOIN order_sizes os ON td.order_id = os.order_id;

-- Display results
SELECT *
FROM time_order_metrics;

-- --------------------------------------------------------------------------------
-- Step 5b: Repurchase Cycle by Time Segment
-- Goal: Analyze how time-based factors influence the reorder speed of customers

-- Logic:
-- 1. Use `time_order_metrics` (from Step 5a)
-- 2. Group by hour of day, day of week, and weekday/weekend to calculate average repurchase cycle for each time segment
-- 3. Also include total number of orders for each time segment to provide more context
-- 4. Filter out first-time orders where repurchase_cycle is NULL
-- --------------------------------------------------------------------------------
-- Average repurchase cycle by hour of day (0 = 12am, 23 = 11pm)
CREATE TABLE repurchase_cycle_by_hour AS
SELECT
	CASE
		WHEN order_hour_of_day = 0 THEN '12 AM'
		WHEN order_hour_of_day BETWEEN 1 AND 11 THEN order_hour_of_day || ' AM'
		WHEN order_hour_of_day = 12 THEN '12 PM'
		ELSE (order_hour_of_day - 12) || ' PM'
	END AS hour_of_day,
	ROUND(AVG(repurchase_cycle)::numeric,2) AS avg_repurchase_cycle,
	COUNT(*) AS number_of_orders
FROM time_order_metrics
WHERE repurchase_cycle IS NOT NULL
GROUP BY hour_of_day
ORDER BY MIN(order_hour_of_day);	-- ensures correct time order

-- Average repurchase cycle by day of week (0 = Sunday, 6 = Saturday)
CREATE TABLE repurchase_cycle_by_day AS
SELECT
	CASE order_dow
		WHEN 0 THEN 'Sunday'
		WHEN 1 THEN 'Monday'
		WHEN 2 THEN 'Tuesday'
		WHEN 3 THEN 'Wednesday'
		WHEN 4 THEN 'Thursday'
		WHEN 5 THEN 'Friday'
		WHEN 6 THEN 'Saturday'
	END AS day_of_week,
	ROUND(AVG(repurchase_cycle)::numeric,2) AS avg_repurchase_cycle,
	COUNT(*) AS number_of_orders
FROM time_order_metrics
WHERE repurchase_cycle IS NOT NULL
GROUP BY order_dow
ORDER BY
	CASE order_dow
		WHEN 0 THEN 0
		WHEN 1 THEN 1
		WHEN 2 THEN 2
		WHEN 3 THEN 3
		WHEN 4 THEN 4
		WHEN 5 THEN 5
		WHEN 6 THEN 6
	END;

-- Average repurchase cycle by weekday vs. weekend
CREATE TABLE repurchase_cycle_weekday_or_weekend AS
SELECT
	weekday_or_weekend,
	ROUND(AVG(repurchase_cycle)::numeric,2) AS avg_repurchase_cycle,
	COUNT(*) AS number_of_orders
FROM time_order_metrics
WHERE repurchase_cycle IS NOT NULL
GROUP BY weekday_or_weekend
ORDER BY weekday_or_weekend;

-- --------------------------------------------------------------------------------
-- Step 5c: Order Size by Time Segment
-- Goal: Analyze how time-based factors influence customer order size

-- Logic:
-- 1. Use `time_order_metrics` (from Step 5a)
-- 2. Group by hour of day, day of week, and weekday/weekend to calculate:
--     - average order size
--     - number of orders
--     - total item volume (average order size * number of orders)
-- 3. Filter out first-time orders where order_size is NULL
-- --------------------------------------------------------------------------------
-- Order size by hour of day (12 AM - 11 PM)
CREATE TABLE order_size_by_hour AS
SELECT
	CASE
		WHEN order_hour_of_day = 0 THEN '12 AM'
		WHEN order_hour_of_day BETWEEN 1 AND 11 THEN order_hour_of_day || ' AM'
		WHEN order_hour_of_day = 12 THEN '12 PM'
		ELSE (order_hour_of_day - 12) || ' PM'
	END AS hour_of_day,
	ROUND(AVG(order_size)::numeric,2) AS avg_order_size,
	COUNT(*) AS number_of_orders,
	ROUND(AVG(order_size)::numeric * COUNT(*),0) AS total_item_volume
FROM time_order_metrics
WHERE order_size IS NOT NULL
GROUP BY order_hour_of_day
ORDER BY order_hour_of_day;

-- Order size by day of week
CREATE TABLE order_size_by_day AS
SELECT
	CASE order_dow
		WHEN 0 THEN 'Sunday'
		WHEN 1 THEN 'Monday'
		WHEN 2 THEN 'Tuesday'
		WHEN 3 THEN 'Wednesday'
		WHEN 4 THEN 'Thursday'
		WHEN 5 THEN 'Friday'
		WHEN 6 THEN 'Saturday'
	END AS day_of_week,
	ROUND(AVG(order_size)::numeric,2) AS avg_order_size,
	COUNT(*) AS number_of_orders,
	ROUND(AVG(order_size)::numeric * COUNT(*),0) AS total_item_volume
FROM time_order_metrics
WHERE order_size IS NOT NULL
GROUP BY order_dow
ORDER BY order_dow;

-- Order size by weekday vs. weekend
CREATE TABLE order_size_weekday_or_weekend AS
SELECT
	weekday_or_weekend,
	ROUND(AVG(order_size)::numeric,2) AS avg_order_size,
	COUNT(*) AS number_of_orders,
	ROUND(AVG(order_size)::numeric * COUNT(*),0) AS total_item_volume
FROM time_order_metrics
WHERE order_size IS NOT NULL
GROUP BY weekday_or_weekend
ORDER BY weekday_or_weekend;

-- --------------------------------------------------------------------------------
-- Step 6: Repurchase Momentum Index (RMI)
-- Goal: Quantify the behavioral strength of each hour + day segment by combining repurchase cycle and total item volume (scaled)

-- Logic:
-- 1. Use time_order_metrics (Step 5a) to group by hour of day and day of week
-- 2. Calculate:
--    - average repurchase cycle
--    - average order size
--    - number of orders
--    - repurchase cycle lift (global average repurchase cycle - local average repurchase cycle)
--    - ln(total item volume)		-- total item volume = SUM(order_size)
--    - raw RMI = repurchase_cycle_lift * ln(total item volume)
-- 3. Rescale raw RMI into a standardized 0-10 range
-- --------------------------------------------------------------------------------
CREATE TABLE rmi_by_hour_day_final AS
-- Find the global average repurchase cycle (from all orders in dataset)
WITH global_avg_rc AS (
	SELECT
		ROUND(AVG(repurchase_cycle)::numeric,2) AS global_avg_repurchase_cycle
	FROM time_order_metrics
	WHERE repurchase_cycle IS NOT NULL
),

-- Calculate raw RMI at hour + day level
rmi_by_hour_day AS (
	SELECT
		order_hour_of_day,
		order_dow,
		ROUND(AVG(repurchase_cycle)::numeric,2) AS avg_repurchase_cycle,
		ROUND(AVG(order_size)::numeric,2) AS avg_order_size,
		COUNT(*) AS number_of_orders,
		ROUND(
			((SELECT global_avg_repurchase_cycle FROM global_avg_rc)
			- AVG(repurchase_cycle))::numeric,2)
			* 
			ROUND(LN(SUM(order_size))::numeric, 2) AS raw_rmi
	FROM time_order_metrics
	WHERE repurchase_cycle IS NOT NULL
	GROUP BY order_hour_of_day, order_dow
),

-- Scale RMI scores from 0-10
rmi_scaled AS (
	SELECT
		order_hour_of_day,
		order_dow,
		avg_repurchase_cycle,
		avg_order_size,
		number_of_orders,
		raw_rmi,
		MIN(raw_rmi) OVER () AS min_rmi,
		MAX(raw_rmi) OVER () AS max_rmi
	FROM rmi_by_hour_day
),

-- Create readable labels and final scaled RMI
final_rmi AS (
	SELECT
		CASE order_dow
			WHEN 0 THEN 'Sunday'
			WHEN 1 THEN 'Monday'
			WHEN 2 THEN 'Tuesday'
			WHEN 3 THEN 'Wednesday'
			WHEN 4 THEN 'Thursday'
			WHEN 5 THEN 'Friday'
			WHEN 6 THEN 'Saturday'
		END || ' at ' ||
		CASE
			WHEN order_hour_of_day = 0 THEN '12 AM'
			WHEN order_hour_of_day BETWEEN 1 AND 11 THEN order_hour_of_day || ' AM'
			WHEN order_hour_of_day = 12 THEN '12 PM'
			ELSE (order_hour_of_day - 12) || ' PM'
		END AS hour_day_label,
		order_dow,
		order_hour_of_day,
		avg_repurchase_cycle,
		avg_order_size,
		number_of_orders,
		raw_rmi,
		ROUND(
			CASE
				WHEN max_rmi = min_rmi THEN 5
				ELSE ((raw_rmi - min_rmi) / NULLIF(max_rmi - min_rmi, 0)) * 10
			END, 2) AS rmi_scaled
	FROM rmi_scaled
)

SELECT *
FROM final_rmi;

-- Display results
SELECT *
FROM rmi_by_hour_day_final
ORDER BY rmi_scaled DESC;

-- --------------------------------------------------------------------------------
-- Step 7: Supporting Behavioral Metrics
-- Goal: Add additional context to the Repurchase Momentum Index by calculating key statistical metrics for each hour + day segment

-- Logic:
-- 1. Use time_order_metrics (Step 5a) to group by hour of day and day of week
-- 2. Calculate:
--    - order size lift (local average order size - global average order size)
--    - repurchase cycle lift (global average repurchase cycle - local average repurchase cycle)
--    - standard deviation		-- for both order size and repurchase cycle
--    - z-score					-- for both order size and repurchase cycle
-- --------------------------------------------------------------------------------
CREATE TABLE hour_day_metrics AS
-- Calculate global averages and standard deviations
WITH global_stats AS (
	SELECT
		ROUND(AVG(repurchase_cycle)::numeric,2) AS global_avg_repurchase_cycle,
		ROUND(STDDEV_POP(repurchase_cycle)::numeric,2) AS stddev_repurchase_cycle,
		ROUND(AVG(order_size)::numeric,2) AS global_avg_order_size,
		ROUND(STDDEV_POP(order_size)::numeric,2) AS stddev_order_size
	FROM time_order_metrics
	WHERE repurchase_cycle IS NOT NULL
		AND order_size IS NOT NULL
),

-- Calculate hour + day segment averages, lifts, and z-scores
hour_day_behavioral_metrics AS (
	SELECT
		order_hour_of_day,
		order_dow,
		ROUND(AVG(repurchase_cycle)::numeric, 2) AS global_avg_repurchase_cycle,
		ROUND(STDDEV_POP(repurchase_cycle)::numeric, 2) AS stddev_repurchase_cycle,
		ROUND(AVG(order_size)::numeric, 2) AS global_avg_order_size,
		ROUND(STDDEV_POP(order_size)::numeric, 2) AS stddev_order_size,
		COUNT(*) AS number_of_orders,
		ROUND((
			(SELECT global_avg_repurchase_cycle FROM global_stats) - AVG(repurchase_cycle))::numeric, 2) AS repurchase_cycle_lift,
		ROUND(
			((
			(SELECT global_avg_repurchase_cycle FROM global_stats) - AVG(repurchase_cycle))::numeric) / NULLIF((SELECT stddev_repurchase_cycle FROM global_stats), 0), 2) AS zscore_repurchase_cycle,
		ROUND((AVG(order_size) - (SELECT global_avg_order_size FROM global_stats))::numeric, 2) AS order_size_lift,
		ROUND(
			((AVG(order_size) - (SELECT global_avg_order_size FROM global_stats))::numeric) / NULLIF((SELECT stddev_order_size FROM global_stats), 0), 2) AS zscore_order_size
	FROM time_order_metrics tom
	JOIN global_stats gs ON TRUE
	WHERE repurchase_cycle IS NOT NULL
		AND order_size IS NOT NULL
	GROUP BY order_hour_of_day, order_dow
)

SELECT *
FROM hour_day_behavioral_metrics;

-- Display results
SELECT * 
FROM hour_day_metrics
ORDER BY order_dow, order_hour_of_day;