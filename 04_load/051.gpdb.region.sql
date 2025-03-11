INSERT INTO :schema_name.region 
(r_regionkey, r_name, r_comment)
SELECT r_regionkey, r_name, r_comment 
FROM :ext_schema_name.region;
