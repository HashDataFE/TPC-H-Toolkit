CREATE TABLE :schema_name.region
(R_REGIONKEY INTEGER, 
R_NAME CHAR(25),
R_COMMENT VARCHAR(152),
dummy text);
ALTER TABLE :schema_name.region ADD PRIMARY KEY (r_regionkey);
