CREATE TABLE :schema_name.partsupp
(PS_PARTKEY INT,
PS_SUPPKEY INT,
PS_AVAILQTY INTEGER,
PS_SUPPLYCOST DECIMAL(15,2),
PS_COMMENT VARCHAR(199),
dummy text);
ALTER TABLE :schema_name.partsupp ADD PRIMARY KEY (ps_partkey, ps_suppkey);
