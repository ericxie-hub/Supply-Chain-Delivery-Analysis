-- =========================================================
-- DataCo Supply Chain: Step 1 - Load the raw CSV into MySQL
-- =========================================================
-- Before running:
--   1. Run:  SHOW VARIABLES LIKE 'secure_file_priv';
--      It shows the one folder MySQL is allowed to read files from.
--      On Windows this is usually:
--      C:\ProgramData\MySQL\MySQL Server 8.x\Uploads\
--   2. Copy DataCoSupplyChainDataset.csv into that folder.
--   3. Edit the file path in the LOAD DATA line below to match
--      (use forward slashes / even on Windows).
-- =========================================================

CREATE DATABASE IF NOT EXISTS dataco;
USE dataco;

-- Staging table: every column loads as text first.
-- This avoids import errors from blanks or odd values.
-- We'll convert to proper types (dates, numbers) in the next step.
DROP TABLE IF EXISTS raw_orders;

CREATE TABLE raw_orders (
    payment_type                 VARCHAR(50),
    days_shipping_real           VARCHAR(20),
    days_shipping_scheduled      VARCHAR(20),
    benefit_per_order            VARCHAR(30),
    sales_per_customer           VARCHAR(30),
    delivery_status              VARCHAR(50),
    late_delivery_risk           VARCHAR(5),
    category_id                  VARCHAR(20),
    category_name                VARCHAR(100),
    customer_city                VARCHAR(100),
    customer_country             VARCHAR(100),
    customer_email               VARCHAR(100),
    customer_fname               VARCHAR(100),
    customer_id                  VARCHAR(20),
    customer_lname               VARCHAR(100),
    customer_password            VARCHAR(100),
    customer_segment             VARCHAR(50),
    customer_state               VARCHAR(50),
    customer_street              VARCHAR(200),
    customer_zipcode             VARCHAR(20),
    department_id                VARCHAR(20),
    department_name              VARCHAR(100),
    latitude                     VARCHAR(30),
    longitude                    VARCHAR(30),
    market                       VARCHAR(50),
    order_city                   VARCHAR(100),
    order_country                VARCHAR(100),
    order_customer_id            VARCHAR(20),
    order_date                   VARCHAR(30),
    order_id                     VARCHAR(20),
    order_item_cardprod_id       VARCHAR(20),
    order_item_discount          VARCHAR(30),
    order_item_discount_rate     VARCHAR(30),
    order_item_id                VARCHAR(20),
    order_item_product_price     VARCHAR(30),
    order_item_profit_ratio      VARCHAR(30),
    order_item_quantity          VARCHAR(20),
    sales                        VARCHAR(30),
    order_item_total             VARCHAR(30),
    order_profit_per_order       VARCHAR(30),
    order_region                 VARCHAR(100),
    order_state                  VARCHAR(100),
    order_status                 VARCHAR(50),
    order_zipcode                VARCHAR(20),
    product_card_id              VARCHAR(20),
    product_category_id          VARCHAR(20),
    product_description          VARCHAR(500),
    product_image                VARCHAR(500),
    product_name                 VARCHAR(200),
    product_price                VARCHAR(30),
    product_status               VARCHAR(5),
    shipping_date                VARCHAR(30),
    shipping_mode                VARCHAR(50)
);

-- Load the CSV. The file uses Latin-1 encoding, not UTF-8.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/DataCoSupplyChainDataset.csv'
INTO TABLE raw_orders
CHARACTER SET latin1
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES             -- skip the header row
(payment_type, days_shipping_real, days_shipping_scheduled, benefit_per_order,
 sales_per_customer, delivery_status, late_delivery_risk, category_id,
 category_name, customer_city, customer_country, customer_email,
 customer_fname, customer_id, customer_lname, customer_password,
 customer_segment, customer_state, customer_street, customer_zipcode,
 department_id, department_name, latitude, longitude, market, order_city,
 order_country, order_customer_id, order_date, order_id,
 order_item_cardprod_id, order_item_discount, order_item_discount_rate,
 order_item_id, order_item_product_price, order_item_profit_ratio,
 order_item_quantity, sales, order_item_total, order_profit_per_order,
 order_region, order_state, order_status, order_zipcode, product_card_id,
 product_category_id, product_description, product_image, product_name,
 product_price, product_status, shipping_date, @last_col)
-- Strip the hidden Windows line-ending character from the last column
SET shipping_mode = TRIM(TRAILING '\r' FROM @last_col);

-- =========================================================
-- Check that it worked
-- =========================================================
-- Should be roughly 180,519 rows
SELECT COUNT(*) AS total_rows FROM raw_orders;

-- Eyeball a few rows: do the columns line up?
SELECT order_id, order_date, shipping_mode, delivery_status,
       days_shipping_real, days_shipping_scheduled, market, sales
FROM raw_orders
LIMIT 10;
