CREATE TABLE tpch_reports.compile_tpch
(id int, description varchar, tuples bigint, duration time, start_epoch_seconds bigint, end_spoch_seconds bigint)
DISTRIBUTED BY (id);
