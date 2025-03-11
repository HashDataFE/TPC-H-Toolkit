INSERT INTO :schema_name.nation 
(n_nationkey, n_name, n_regionkey, n_comment)
SELECT n_nationkey, n_name, n_regionkey, n_comment
FROM :ext_schema_name.nation;
