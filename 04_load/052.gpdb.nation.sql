INSERT INTO :DB_SCHEMA_NAME.nation 
(n_nationkey, n_name, n_regionkey, n_comment)
SELECT n_nationkey, n_name, n_regionkey, n_comment
FROM :ext_schema_name.nation;
