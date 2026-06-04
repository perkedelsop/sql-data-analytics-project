/*
===================================================================
Customer Report 
===================================================================
This report contains key customer metrics and behaviors.

Highlights :
	1. Essential customer information.
	2. Customer segmentation into age group and loyalty categories (VIP, Regular, New).
	3. Aggregate customer-level metrics :
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (months)
	4. Calculate valueable KPIs :
		- recency 
		- average order value
		- average monthly spend
===================================================================
*/
IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS
	WITH base_query AS(
		-- 1. Retrieving column
		SELECT 
		f.order_number,
		f.product_key,
		f.order_date,
		f.sales_amount,
		f.quantity,
		c.customer_key,
		c.customer_number,
		-- 2. Transformation
		CONCAT(c.first_name, ' ' , c.last_name) customer_name,
		DATEDIFF(year,c.birthdate, GETDATE()) age
		FROM gold.fact_sales f
		LEFT JOIN gold.dim_customers c
		ON c.customer_key = f.customer_key
		WHERE order_date IS NOT NULL
	)

	, customer_aggregation AS (
		SELECT 
		customer_key,
		customer_number,
		customer_name,
		age,
		-- 3. Aggregation
		COUNT(DISTINCT order_number) total_orders,
		SUM(sales_amount) total_sales,
		SUM(quantity) total_quantity,
		COUNT(DISTINCT product_key) total_products,
		MAX(order_date) last_order_date,
		DATEDIFF(month, MIN(order_date), MAX(order_date)) lifespan
	FROM base_query
	GROUP BY
		customer_key,
		customer_number,
		customer_name,
		age
	)

	SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	-- Age group segmentation
	CASE WHEN age < 20 THEN 'Under 20'
		WHEN age between 20 and 39 THEN '20-39'
		WHEN age between 40 and 59 THEN '40-59'
		ELSE '60+'
	END age_group,
	-- Customer loyalty segmentation 
	CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN lifespan >+ 12 AND total_sales <= 5000 THEN 'Regular'
		ELSE 'New'
	END customer_segment,
	DATEDIFF(month, last_order_date, GETDATE()) AS recency,
	total_orders,
	total_sales,
	total_products,
	last_order_date,
	lifespan,
	-- Average order value
	CASE WHEN total_sales = 0 THEN 0
		 ELSE total_sales / total_orders
	END AS avg_order_value,
	-- Average monthly spend
	CASE WHEN lifespan = 0 THEN total_sales
		 ELSE total_sales / lifespan
	END AS avg_monthly_spend
	FROM customer_aggregation
