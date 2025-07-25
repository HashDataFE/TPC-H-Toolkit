SELECT split_part(description, '.', 2) as table_name, sum(tuples) as tuples, round(sum(extract('epoch' from duration))) AS seconds 
FROM :report_schema.load 
WHERE tuples >= 0 
GROUP BY split_part(description, '.', 2)
ORDER BY 1;
