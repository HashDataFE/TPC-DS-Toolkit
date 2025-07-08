-- ===================================================================
-- TPC-DS Index Creation Script (PostgreSQL Syntax)
-- Applicable to all core tables in TPC-DS benchmark
-- Optimization Strategy: High-frequency join fields, time range filters, aggregation operations
-- ===================================================================

-- Start transaction (ensure atomicity)
BEGIN;

-- Set search path (adjust based on actual schema name)
set search_path=:DB_SCHEMA_NAME,public;

-- ===================================================================
-- Fact Table Indexes
-- ===================================================================

-- 1. store_sales table indexes
COMMENT ON TABLE store_sales IS 'Sales fact table (store channel)';
CREATE INDEX idx_store_sales_customer ON store_sales (ss_customer_sk, ss_sold_date_sk);
CREATE INDEX idx_store_sales_item ON store_sales (ss_item_sk, ss_sold_date_sk);
CREATE INDEX idx_store_sales_store ON store_sales (ss_store_sk, ss_sold_date_sk);
CREATE INDEX idx_store_sales_date ON store_sales (ss_sold_date_sk);
CREATE INDEX idx_store_sales_ticket ON store_sales (ss_ticket_number, ss_customer_sk);

-- 2. web_sales table indexes
COMMENT ON TABLE web_sales IS 'Sales fact table (online channel)';
CREATE INDEX idx_web_sales_customer ON web_sales (ws_bill_customer_sk, ws_sold_date_sk);
CREATE INDEX idx_web_sales_item ON web_sales (ws_item_sk, ws_sold_date_sk);
CREATE INDEX idx_web_sales_web_page ON web_sales (ws_web_page_sk, ws_sold_date_sk);
CREATE INDEX idx_web_sales_date ON web_sales (ws_sold_date_sk);
CREATE INDEX idx_web_sales_promo ON web_sales (ws_promo_sk, ws_sold_date_sk);

-- 3. catalog_sales table indexes
COMMENT ON TABLE catalog_sales IS 'Sales fact table (catalog channel)';
CREATE INDEX idx_catalog_sales_customer ON catalog_sales (cs_bill_customer_sk, cs_sold_date_sk);
CREATE INDEX idx_catalog_sales_item ON catalog_sales (cs_item_sk, cs_sold_date_sk);
CREATE INDEX idx_catalog_sales_catalog ON catalog_sales (cs_catalog_page_sk, cs_sold_date_sk);
CREATE INDEX idx_catalog_sales_date ON catalog_sales (cs_sold_date_sk);

-- 4. Return fact table indexes
CREATE INDEX idx_store_returns_sale ON store_returns (sr_item_sk, sr_ticket_number);
CREATE INDEX idx_web_returns_sale ON web_returns (wr_item_sk, wr_order_number);
CREATE INDEX idx_catalog_returns_sale ON catalog_returns (cr_item_sk, cr_order_number);
CREATE INDEX idx_store_returns_reason ON store_returns (sr_reason_sk);

-- ===================================================================
-- Dimension Table Indexes
-- ===================================================================

-- 1. customer table
COMMENT ON TABLE customer IS 'Customer dimension table';
CREATE UNIQUE INDEX idx_customer_id ON customer (c_customer_sk);
CREATE INDEX idx_customer_name ON customer (c_last_name, c_first_name);
CREATE INDEX idx_customer_demographic ON customer (c_current_cdemo_sk);

-- 2. item table
COMMENT ON TABLE item IS 'Product dimension table';
CREATE UNIQUE INDEX idx_item_id ON item (i_item_sk);
CREATE INDEX idx_item_category ON item (i_category, i_class);

-- 3. date_dim table
COMMENT ON TABLE date_dim IS 'Date dimension table';
CREATE UNIQUE INDEX idx_date_dim_key ON date_dim (d_date_sk);
CREATE INDEX idx_date_dim_year_month ON date_dim (d_year, d_moy);
CREATE INDEX idx_date_dim_quarter ON date_dim (d_qoy, d_year);

-- 4. store table
COMMENT ON TABLE store IS 'Store dimension table';
CREATE UNIQUE INDEX idx_store_id ON store (s_store_sk);
CREATE INDEX idx_store_address ON store (s_county, s_state);

-- 5. web_page and catalog_page
CREATE INDEX idx_web_page_url ON web_page (wp_web_page_sk, wp_access_date_sk);
CREATE INDEX idx_catalog_page_category ON catalog_page (cp_department, cp_category);

-- 6. promotion table
CREATE INDEX idx_promotion_type ON promotion (p_channel_dmail, p_promo_sk);

-- ===================================================================
-- Advanced Optimization Indexes
-- ===================================================================

-- Cross-table join optimization
CREATE INDEX idx_store_sales_customer_date ON store_sales (ss_customer_sk, ss_sold_date_sk) INCLUDE (ss_item_sk);
CREATE INDEX idx_web_sales_page_date ON web_sales (ws_web_page_sk, ws_sold_date_sk);

-- Expression index (cover computed fields)
CREATE INDEX idx_store_returns_amount_expr ON store_returns ((sr_return_amt * 0.9));

-- ===================================================================
-- Index Verification (Optional)
-- ===================================================================

-- Check if indexes are created successfully
SELECT tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY tablename, indexname;

-- Commit transaction
COMMIT;

-- Prompt message
\echo 'TPC-DS index creation completed!'