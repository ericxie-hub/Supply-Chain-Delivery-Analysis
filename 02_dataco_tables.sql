-- =========================================================
-- DataCo Supply Chain: Step 2 - Split raw_orders into clean tables
-- =========================================================
-- raw_orders has one row per ORDER ITEM, with customer, product, and
-- order details repeated on every row. Here we split it into 4 tables
-- so each fact is stored once:
--
--   customers    one row per customer
--   products     one row per product (with its category/department)
--   orders       one row per order (dates, shipping, delivery, location)
--   order_items  one row per line item (quantity, price, sales, profit)
--
-- How they connect:
--   customers.customer_id  <- orders.customer_id
--   orders.order_id        <- order_items.order_id
--   products.product_id    <- order_items.product_id
--
-- Along the way we convert text into real types:
--   text dates like '1/31/2018 22:56' -> DATETIME
--   text numbers -> INT / DECIMAL
-- NULLIF(x, '') turns blank text into NULL so conversions don't fail.
-- =========================================================

USE dataco;

-- Drop in reverse order (child tables first) so reruns work
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

-- ---------------------------------------------------------
-- 1. CUSTOMERS
-- ---------------------------------------------------------
-- (Email and password columns are masked in this dataset, so we skip them.)
CREATE TABLE customers (
    customer_id      INT PRIMARY KEY,
    first_name       VARCHAR(100),
    last_name        VARCHAR(100),
    segment          VARCHAR(50),     -- Consumer / Corporate / Home Office
    street           VARCHAR(200),
    city             VARCHAR(100),
    state            VARCHAR(50),
    country          VARCHAR(100),
    zipcode          VARCHAR(20)
);

-- GROUP BY customer_id collapses the repeated rows into one per customer.
-- MAX() just picks the value (they should be identical for a customer).
INSERT INTO customers
SELECT
    CAST(customer_id AS UNSIGNED),
    MAX(customer_fname),
    MAX(customer_lname),
    MAX(customer_segment),
    MAX(customer_street),
    MAX(customer_city),
    MAX(customer_state),
    MAX(customer_country),
    MAX(NULLIF(customer_zipcode, ''))
FROM raw_orders
GROUP BY customer_id;

-- ---------------------------------------------------------
-- 2. PRODUCTS
-- ---------------------------------------------------------
CREATE TABLE products (
    product_id       INT PRIMARY KEY,
    product_name     VARCHAR(200),
    product_price    DECIMAL(10,2),
    category_id      INT,
    category_name    VARCHAR(100),
    department_id    INT,
    department_name  VARCHAR(100)
);

INSERT INTO products
SELECT
    CAST(product_card_id AS UNSIGNED),
    MAX(product_name),
    MAX(CAST(NULLIF(product_price, '') AS DECIMAL(10,2))),
    MAX(CAST(NULLIF(category_id, '') AS UNSIGNED)),
    MAX(category_name),
    MAX(CAST(NULLIF(department_id, '') AS UNSIGNED)),
    MAX(department_name)
FROM raw_orders
GROUP BY product_card_id;

-- ---------------------------------------------------------
-- 3. ORDERS
-- ---------------------------------------------------------
CREATE TABLE orders (
    order_id                 INT PRIMARY KEY,
    customer_id              INT,
    order_date               DATETIME,
    shipping_date            DATETIME,
    shipping_mode            VARCHAR(50),   -- Standard / Second / First Class / Same Day
    days_shipping_real       INT,
    days_shipping_scheduled  INT,
    delivery_status          VARCHAR(50),   -- Advance / Late / On time / Canceled
    late_delivery_risk       TINYINT,       -- 1 = late, 0 = not late
    order_status             VARCHAR(50),   -- COMPLETE, PENDING, SUSPECTED_FRAUD, etc.
    payment_type             VARCHAR(50),
    market                   VARCHAR(50),
    order_region             VARCHAR(100),
    order_country            VARCHAR(100),
    order_state              VARCHAR(100),
    order_city               VARCHAR(100),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- STR_TO_DATE reads text dates. '%c/%e/%Y %H:%i' means
-- month/day/year hour:minute, with no leading zeros required.
INSERT INTO orders
SELECT
    CAST(order_id AS UNSIGNED),
    MAX(CAST(order_customer_id AS UNSIGNED)),
    MAX(STR_TO_DATE(order_date,    '%c/%e/%Y %H:%i')),
    MAX(STR_TO_DATE(shipping_date, '%c/%e/%Y %H:%i')),
    MAX(shipping_mode),
    MAX(CAST(days_shipping_real      AS UNSIGNED)),
    MAX(CAST(days_shipping_scheduled AS UNSIGNED)),
    MAX(delivery_status),
    MAX(CAST(late_delivery_risk AS UNSIGNED)),
    MAX(order_status),
    MAX(payment_type),
    MAX(market),
    MAX(order_region),
    MAX(order_country),
    MAX(order_state),
    MAX(order_city)
FROM raw_orders
GROUP BY order_id;

-- ---------------------------------------------------------
-- 4. ORDER_ITEMS
-- ---------------------------------------------------------
-- No GROUP BY here: raw_orders already has one row per item.
CREATE TABLE order_items (
    order_item_id    INT PRIMARY KEY,
    order_id         INT,
    product_id       INT,
    quantity         INT,
    unit_price       DECIMAL(10,2),
    discount         DECIMAL(10,2),   -- dollar amount
    discount_rate    DECIMAL(6,4),    -- e.g. 0.04 = 4%
    gross_sales      DECIMAL(10,2),   -- before discount
    net_sales        DECIMAL(10,2),   -- after discount
    profit           DECIMAL(10,2),   -- can be negative (a loss)
    profit_ratio     DECIMAL(8,4),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

INSERT INTO order_items
SELECT
    CAST(order_item_id AS UNSIGNED),
    CAST(order_id AS UNSIGNED),
    CAST(order_item_cardprod_id AS UNSIGNED),
    CAST(order_item_quantity AS UNSIGNED),
    CAST(NULLIF(order_item_product_price, '') AS DECIMAL(10,2)),
    CAST(NULLIF(order_item_discount, '')      AS DECIMAL(10,2)),
    CAST(NULLIF(order_item_discount_rate, '') AS DECIMAL(6,4)),
    CAST(NULLIF(sales, '')                    AS DECIMAL(10,2)),
    CAST(NULLIF(order_item_total, '')         AS DECIMAL(10,2)),
    CAST(NULLIF(order_profit_per_order, '')   AS DECIMAL(10,2)),
    CAST(NULLIF(order_item_profit_ratio, '')  AS DECIMAL(8,4))
FROM raw_orders;

-- =========================================================
-- Checks
-- =========================================================
-- Row counts: order_items should match raw_orders (~180,519)
SELECT 'raw_orders'  AS table_name, COUNT(*) AS row_count FROM raw_orders
UNION ALL SELECT 'customers',   COUNT(*) FROM customers
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;

-- Dates converted? Both should be real dates, not NULL
SELECT MIN(order_date) AS first_order, MAX(order_date) AS last_order,
       SUM(order_date IS NULL) AS missing_dates
FROM orders;

-- Do the joins work? One row should show info from all 4 tables
SELECT o.order_id, o.order_date, c.segment, p.product_name,
       oi.quantity, oi.net_sales, oi.profit, o.delivery_status
FROM order_items oi
JOIN orders    o ON oi.order_id   = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN products  p ON oi.product_id = p.product_id
LIMIT 10;
