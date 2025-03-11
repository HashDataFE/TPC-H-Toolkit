INSERT INTO :schema_name.partsupp 
(ps_partkey, ps_suppkey, ps_availqty, ps_supplycost, ps_comment)
SELECT ps_partkey, ps_suppkey, ps_availqty, ps_supplycost, ps_comment 
FROM :ext_schema_name.partsupp;
