INSERT INTO :schema_name.supplier 
(s_suppkey, s_name, s_address, s_nationkey, s_phone, s_acctbal, 
            s_comment)
SELECT s_suppkey, s_name, s_address, s_nationkey, s_phone, s_acctbal, 
            s_comment 
FROM :ext_schema_name.supplier;
