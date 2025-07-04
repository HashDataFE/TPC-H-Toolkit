SELECT split_part(description, '.', 1) as schema_name, round(extract('epoch' from duration)) AS seconds 
FROM :report_schema.sql 
WHERE id = 1
ORDER BY 1;
