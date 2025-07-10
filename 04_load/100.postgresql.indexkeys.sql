-- ===================================================================
-- TPC-DS Index Creation Script (PostgreSQL Syntax)
-- Applicable to all core tables in TPC-DS benchmark
-- Optimization Strategy: High-frequency join fields, time range filters, aggregation operations
-- ===================================================================

-- Start transaction (ensure atomicity)

-- Set search path (adjust based on actual schema name)
set search_path=:DB_SCHEMA_NAME,public;

-- ===================================================================
-- Fact Table Indexes
-- ===================================================================


-- 1. store_sales table indexes
COMMENT ON TABLE store_sales IS 'Sales fact table (store channel)';
-- Optimization: Merge redundant indexes, keep most effective composite indexes
CREATE INDEX idx_store_sales_customer_date ON store_sales (ss_customer_sk, ss_sold_date_sk) INCLUDE (ss_item_sk, ss_store_sk, ss_promo_sk, ss_quantity, ss_net_paid);
CREATE INDEX idx_store_sales_item_date ON store_sales (ss_item_sk, ss_sold_date_sk) INCLUDE (ss_customer_sk, ss_quantity, ss_sales_price);
CREATE INDEX idx_store_sales_ticket ON store_sales (ss_ticket_number);

-- 2. web_sales table indexes
COMMENT ON TABLE web_sales IS 'Sales fact table (online channel)';
CREATE INDEX idx_web_sales_customer_date ON web_sales (ws_bill_customer_sk, ws_sold_date_sk) INCLUDE (ws_item_sk, ws_web_page_sk, ws_promo_sk, ws_quantity);
CREATE INDEX idx_web_sales_item_date ON web_sales (ws_item_sk, ws_sold_date_sk) INCLUDE (ws_bill_customer_sk, ws_quantity, ws_sales_price);
CREATE INDEX idx_web_sales_order ON web_sales (ws_order_number);

-- 3. catalog_sales table indexes
COMMENT ON TABLE catalog_sales IS 'Sales fact table (catalog channel)';
CREATE INDEX idx_catalog_sales_customer_date ON catalog_sales (cs_bill_customer_sk, cs_sold_date_sk) INCLUDE (cs_item_sk, cs_catalog_page_sk, cs_quantity);
CREATE INDEX idx_catalog_sales_item_date ON catalog_sales (cs_item_sk, cs_sold_date_sk) INCLUDE (cs_bill_customer_sk, cs_quantity, cs_sales_price);

-- 4. Return fact table indexes
CREATE INDEX idx_store_returns_sale ON store_returns (sr_item_sk, sr_ticket_number) INCLUDE (sr_returned_date_sk, sr_return_amt);
CREATE INDEX idx_store_returns_date ON store_returns(sr_returned_date_sk);
CREATE INDEX idx_web_returns_sale ON web_returns (wr_item_sk, wr_order_number) INCLUDE (wr_returned_date_sk, wr_return_amt);
CREATE INDEX idx_catalog_returns_sale ON catalog_returns (cr_item_sk, cr_order_number) INCLUDE (cr_returned_date_sk, cr_return_amount);

-- ===================================================================
-- Dimension Table Indexes
-- ===================================================================

-- 1. customer table
COMMENT ON TABLE customer IS 'Customer dimension table';
CREATE UNIQUE INDEX idx_customer_sk ON customer (c_customer_sk);
CREATE INDEX idx_customer_name ON customer (c_last_name, c_first_name);
CREATE INDEX idx_customer_demographic ON customer (c_current_cdemo_sk, c_current_hdemo_sk, c_current_addr_sk);
-- Add: Customer creation date index (TPC-DS queries often filter by new customers)
CREATE INDEX idx_customer_create_date ON customer (c_customer_sk, c_first_sales_date_sk);

-- 2. item table
COMMENT ON TABLE item IS 'Product dimension table';
CREATE UNIQUE INDEX idx_item_sk ON item (i_item_sk);
CREATE INDEX idx_item_category ON item (i_category, i_class, i_brand);
-- Add: Product price and availability index
CREATE INDEX idx_item_price ON item (i_item_sk, i_current_price, i_units);

-- 3. date_dim table
COMMENT ON TABLE date_dim IS 'Date dimension table';
CREATE UNIQUE INDEX idx_date_dim_key ON date_dim (d_date_sk);
CREATE INDEX idx_date_dim_year_month ON date_dim (d_year, d_moy, d_date_sk);
CREATE INDEX idx_date_dim_quarter ON date_dim (d_qoy, d_year, d_date_sk);
-- Add: Date range query optimization index
CREATE INDEX idx_date_dim_range ON date_dim (d_date_sk, d_year, d_moy, d_dom);
CREATE INDEX idx_date_dim_year ON date_dim(d_year);

-- 4. store table
COMMENT ON TABLE store IS 'Store dimension table';
CREATE UNIQUE INDEX idx_store_id ON store (s_store_sk);
CREATE INDEX idx_store_address ON store (s_county, s_state, s_store_sk);
-- Add: Store performance metrics index
CREATE INDEX idx_store_perf ON store (s_store_sk, s_floor_space, s_number_employees); -- Use valid columns
CREATE INDEX idx_store_state ON store(s_state);

-- 5. web_page and catalog_page
CREATE INDEX idx_web_page_url ON web_page (wp_web_page_sk, wp_access_date_sk, wp_type);
CREATE INDEX idx_catalog_page_category ON catalog_page (cp_department, cp_type, cp_catalog_page_sk);

-- 6. promotion table
CREATE INDEX idx_promotion_type ON promotion (p_channel_dmail, p_promo_sk, p_start_date_sk, p_end_date_sk);
-- Add: Promotion effectiveness index
CREATE INDEX idx_promotion_date ON promotion (p_promo_sk, p_start_date_sk, p_end_date_sk, p_channel_email);

-- ===================================================================
-- Advanced Optimization Indexes
-- ===================================================================

-- Cross-table join optimization
CREATE INDEX idx_store_sales_customer_item ON store_sales (ss_customer_sk, ss_item_sk, ss_sold_date_sk);
CREATE INDEX idx_web_sales_customer_item ON web_sales (ws_bill_customer_sk, ws_item_sk, ws_sold_date_sk);

-- Partial index (for commonly used time ranges)
CREATE INDEX idx_store_sales_recent ON store_sales (ss_sold_date_sk, ss_customer_sk)
WHERE ss_sold_date_sk >= 2452275; -- Use the actual value from step 1

-- Expression index
CREATE INDEX idx_store_returns_amount_expr ON store_returns ((sr_return_amt * 0.9));
-- Prompt message
\echo 'TPC-DS index creation completed!'