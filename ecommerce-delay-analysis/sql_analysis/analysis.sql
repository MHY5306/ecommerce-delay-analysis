

USE ecommerce;
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM payments;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;

-- ============================================
-- Module 1: GMV Trend & Growth Analysis
-- ============================================


-- --------------------------------------------
-- Step 1: Daily GMV
-- --------------------------------------------
-- Calculate total GMV per day.

SELECT
    DATE(o.order_purchase_timestamp) AS day,
    SUM(p.payment_value) AS daily_gmv
FROM orders o
JOIN payments p
    ON o.order_id = p.order_id
GROUP BY day
ORDER BY day;


-- --------------------------------------------
-- Step 2: Monthly GMV
-- --------------------------------------------
-- Aggregate GMV at monthly level.

SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
    SUM(p.payment_value) AS monthly_gmv
FROM orders o
JOIN payments p
    ON o.order_id = p.order_id
GROUP BY month
ORDER BY month;


-- --------------------------------------------
-- Step 3: Add Previous Month GMV
-- --------------------------------------------

SELECT
    month,
    monthly_gmv,
    LAG(monthly_gmv) OVER (ORDER BY month) AS last_month_gmv
FROM (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        SUM(p.payment_value) AS monthly_gmv
    FROM orders o
    JOIN payments p
        ON o.order_id = p.order_id
    GROUP BY month
) t;


-- --------------------------------------------
-- Step 4: Calculate Growth Rate
-- --------------------------------------------

SELECT
    month,
    monthly_gmv,
    last_month_gmv,
    (monthly_gmv - last_month_gmv) / last_month_gmv AS growth_rate
FROM (
    SELECT
        month,
        monthly_gmv,
        LAG(monthly_gmv) OVER (ORDER BY month) AS last_month_gmv
    FROM (
        SELECT
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
            SUM(p.payment_value) AS monthly_gmv
        FROM orders o
        JOIN payments p
            ON o.order_id = p.order_id
        GROUP BY month
    ) t1
) t2;


-- --------------------------------------------
-- Step 5: Identify Highest Growth Month
-- --------------------------------------------

SELECT *
FROM (
    SELECT
        month,
        monthly_gmv,
        last_month_gmv,
        (monthly_gmv - last_month_gmv) / last_month_gmv AS growth_rate
    FROM (
        SELECT
            month,
            monthly_gmv,
            LAG(monthly_gmv) OVER (ORDER BY month) AS last_month_gmv
        FROM (
            SELECT
                DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
                SUM(p.payment_value) AS monthly_gmv
            FROM orders o
            JOIN payments p
                ON o.order_id = p.order_id
            GROUP BY month
        ) t1
    ) t2
) t3
WHERE growth_rate IS NOT NULL
ORDER BY growth_rate DESC
LIMIT 1;


-- --------------------------------------------
-- Step 6: Filter Unrealistic Growth
-- --------------------------------------------

SELECT *
FROM (
    SELECT
        month,
        monthly_gmv,
        last_month_gmv,
        (monthly_gmv - last_month_gmv) / last_month_gmv AS growth_rate
    FROM (
        SELECT
            month,
            monthly_gmv,
            LAG(monthly_gmv) OVER (ORDER BY month) AS last_month_gmv
        FROM (
            SELECT
                DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
                SUM(p.payment_value) AS monthly_gmv
            FROM orders o
            JOIN payments p
                ON o.order_id = p.order_id
            GROUP BY month
        ) t1
    ) t2
) t3
WHERE growth_rate IS NOT NULL
  AND last_month_gmv > 5000
ORDER BY growth_rate DESC
LIMIT 1;

-- ============================================
-- Module 2: Business Metrics Analysis
-- ============================================


-- --------------------------------------------
-- Step 1: Monthly Business Metrics
-- --------------------------------------------
-- Calculate GMV, order count, and average order value.

SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
    SUM(p.payment_value) AS monthly_gmv,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(p.payment_value) / COUNT(DISTINCT o.order_id) AS avg_order_value
FROM orders o
JOIN payments p
ON o.order_id = p.order_id
GROUP BY month
ORDER BY month;


-- ============================================
-- Module 3: Product Analysis
-- ============================================

SELECT COUNT(product_id) FROM order_items oi;
-- ============================================
-- Product Analysis - Step 1: Top Products by GMV
-- ============================================
-- This query identifies the top 10 products
-- based on total GMV (Gross Merchandise Value).
--
-- GMV = price + freight_value
-- Data source: order_items table
--
-- Insight:
-- Helps identify the most valuable products in terms of revenue.

SELECT
    oi.product_id,
    SUM(oi.price + oi.freight_value) AS product_gmv
FROM order_items oi
GROUP BY oi.product_id
ORDER BY product_gmv DESC
LIMIT 10;


-- ============================================
-- Product Analysis - Step 2: Top Categories by GMV
-- ============================================
-- This query calculates total GMV for each product category.
--
-- GMV (Gross Merchandise Value) = price + freight_value
-- Data source:
--   order_items (transaction data)
--   products (category information)
--
-- Purpose:
-- Identify which product categories generate the highest revenue,
-- helping understand the overall business structure.

SELECT
    p.product_category_name,                     -- Product category name
    SUM(oi.price + oi.freight_value) AS category_gmv  -- Total GMV per category
FROM order_items oi
JOIN products p
    ON oi.product_id = p.product_id              -- Link items to category
GROUP BY p.product_category_name                -- Aggregate by category
ORDER BY category_gmv DESC;                     -- Sort from highest to lowest GMV



-- ============================================
-- Product Analysis - Step 3: Top Products by Sales Volume
-- ============================================
-- This query identifies the most frequently sold products.
--
-- Metrics:
--   sales_count = number of times a product is sold
--   product_gmv = total revenue generated by the product
--
-- Insight:
-- High sales volume does not necessarily mean high revenue.
-- Some products sell frequently but contribute less to GMV.

SELECT
    oi.product_id,
    COUNT(*) AS sales_count,                      -- Number of times sold
    SUM(oi.price + oi.freight_value) AS product_gmv
FROM order_items oi
GROUP BY oi.product_id
ORDER BY sales_count DESC
LIMIT 10;

-- ============================================
-- Product Analysis - Step 4: Top Products by GMV
-- ============================================
-- This query identifies the top 10 products
-- based on total GMV (Gross Merchandise Value).
--
-- GMV = price + freight_value
--
-- Purpose:
-- Identify products that generate the highest revenue,
-- regardless of how frequently they are sold.
--
-- Insight:
-- Products with high GMV may have lower sales volume,
-- indicating high-value or premium products.

SELECT
    oi.product_id,
    COUNT(*) AS sales_count,                          -- Number of times sold
    SUM(oi.price + oi.freight_value) AS product_gmv   -- Total revenue per product
FROM order_items oi
GROUP BY oi.product_id
ORDER BY product_gmv DESC                             -- Sort by highest GMV
LIMIT 10;

-- ============================================
-- Product Analysis - Step 5: Cumulative GMV Ratio
-- ============================================

SELECT
    product_id,
    product_gmv,

    SUM(product_gmv) OVER (ORDER BY product_gmv DESC)
    / SUM(product_gmv) OVER () AS cumulative_ratio

FROM (
    SELECT
        oi.product_id,
        SUM(oi.price + oi.freight_value) AS product_gmv
    FROM order_items oi
    GROUP BY oi.product_id
) t;

-- ============================================
-- Module 4: Customer Analysis
-- ============================================

-- ============================================
-- Customer Analysis - Step 1: Customer Total Spending
-- ============================================
-- This query calculates total spending for each customer.
--
-- Purpose:
-- Identify high-value customers based on total payment amount.

SELECT
    o.customer_id,
    SUM(p.payment_value) AS total_spent
FROM orders o
JOIN payments p
    ON o.order_id = p.order_id
GROUP BY o.customer_id
ORDER BY total_spent DESC
LIMIT 10;


-- ============================================
-- Customer Analysis - Step 2: Customer Segmentation
-- ============================================

SELECT
    CASE
        WHEN total_spent >= 5000 THEN 'high_value'
        WHEN total_spent >= 1000 THEN 'mid_value'
        ELSE 'low_value'
    END AS customer_level,
    COUNT(*) AS customer_count
FROM (
    SELECT
        o.customer_id,
        SUM(p.payment_value) AS total_spent
    FROM orders o
    JOIN payments p
        ON o.order_id = p.order_id
    GROUP BY o.customer_id
) t
GROUP BY customer_level;

-- ============================================
-- Customer Analysis - Step 3: Repeat Purchase Analysis
-- ============================================

SELECT
    customer_id,
    COUNT(order_id) AS order_count
FROM orders
GROUP BY customer_id
ORDER BY order_count DESC
LIMIT 10;

SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers
FROM (
    SELECT
        customer_id,
        COUNT(order_id) AS order_count
    FROM orders
    GROUP BY customer_id
) t;

-- ============================================
-- Module 5: Regional Analysis
-- ============================================
-- ============================================
-- Regional Analysis - Step 1: Top Cities by GMV
-- ============================================
-- This query calculates total GMV for each city.
--
-- Purpose:
-- Identify which cities contribute the most revenue.

SELECT
    c.customer_city,
    SUM(p.payment_value) AS city_gmv
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN payments p
    ON o.order_id = p.order_id
GROUP BY c.customer_city
ORDER BY city_gmv DESC
LIMIT 10;

-- ============================================
-- Module 6: Seller Analysis
-- ============================================

-- Seller Analysis - Step 1: Top Sellers by GMV

SELECT
    oi.seller_id,
    SUM(oi.price + oi.freight_value) AS seller_gmv  
FROM order_items oi
GROUP BY oi.seller_id
ORDER BY seller_gmv DESC
LIMIT 10;

-- Seller Analysis - Step 2: Seller GMV Cumulative Ratio

SELECT
    seller_id,
    seller_gmv,


    SUM(seller_gmv) OVER (ORDER BY seller_gmv DESC)
    / SUM(seller_gmv) OVER () AS cumulative_ratio

FROM (

    SELECT
        oi.seller_id,
        SUM(oi.price + oi.freight_value) AS seller_gmv
    FROM order_items oi
    GROUP BY oi.seller_id
) t;


-- ============================================
-- Module 7: Delivery Performance Analysis
-- ============================================

-- ============================================
-- Delivery Analysis - Step 1: On-time vs Delayed
-- ============================================

SELECT
    COUNT(*) AS total_orders,   -- total delivered orders

    SUM(CASE
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 1
        ELSE 0
    END) AS on_time_orders,     -- on-time orders

    SUM(CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1
        ELSE 0
    END) AS delayed_orders,     -- delayed orders

    SUM(CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1
        ELSE 0
    END) / COUNT(*) AS delay_rate   -- delay rate

FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

-- ============================================
-- Delivery Analysis - Step 2: Delay Rate by City
-- ============================================

SELECT
    c.customer_city,

    COUNT(*) AS total_orders,   -- total orders in the city

    SUM(CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END) AS delayed_orders,     -- delayed orders

    SUM(CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END) / COUNT(*) AS delay_rate   -- delay rate per city

FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY c.customer_city

HAVING COUNT(*) > 100   -- filter out small sample cities

ORDER BY delay_rate DESC
LIMIT 10;

-- ============================================
-- Delivery Analysis - Step 3: Delay Rate by City & Seller
-- ============================================

SELECT
    c.customer_city,
    oi.seller_id,

    COUNT(DISTINCT o.order_id) AS total_orders,   -- avoid duplicates

    SUM(CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END) AS delayed_orders,

    SUM(CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END)
    / COUNT(DISTINCT o.order_id) AS delay_rate

FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY c.customer_city, oi.seller_id

HAVING COUNT(DISTINCT o.order_id) > 20

ORDER BY delay_rate DESC
LIMIT 20;


-- ============================================
-- Delivery Analysis - Step 4: High-risk Sellers
-- ============================================

SELECT
    oi.seller_id,

    COUNT(DISTINCT o.order_id) AS total_orders,

    SUM(CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END) AS delayed_orders,

    SUM(CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        ELSE 0
    END)
    / COUNT(DISTINCT o.order_id) AS delay_rate

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY oi.seller_id

HAVING COUNT(DISTINCT o.order_id) > 50

ORDER BY delay_rate DESC
LIMIT 10;

-- ============================================
-- Delivery Analysis - Step 5: Delay Trend Over Time
-- ============================================

SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,

    COUNT(*) AS total_orders,

    SUM(CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1
        ELSE 0
    END) AS delayed_orders,

    SUM(CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1
        ELSE 0
    END) / COUNT(*) AS delay_rate

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL

GROUP BY order_month
ORDER BY order_month;

