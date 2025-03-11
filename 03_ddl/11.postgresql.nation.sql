CREATE TABLE :schema_name.nation
(N_NATIONKEY INTEGER, 
N_NAME CHAR(25), 
N_REGIONKEY INTEGER, 
N_COMMENT VARCHAR(152),
dummy text);
ALTER TABLE :schema_name.nation ADD PRIMARY KEY (n_nationkey);
