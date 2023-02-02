CREATE CATALOG iceberg_catalog WITH (
 'type'='iceberg',
 'catalog-type'='hadoop',
 'warehouse'='<replace with ${WAREHOUSE_DIR}>'
);

USE CATALOG iceberg_catalog;

CREATE DATABASE IF NOT EXISTS iceberg_test_db;
USE iceberg_test_db;

CREATE TABLE IF NOT EXISTS t_iceberg_test (
  id BIGINT COMMENT 'unique id',
  data STRING,
  PRIMARY KEY(`id`) NOT ENFORCED
) with (
  'format-version'='2',
  'write.upsert.enabled'='true',
  'write.parquet.compression-codec'='ZSTD');

CREATE TEMPORARY TABLE t_gen_iceberg_test
WITH (
  'connector' = 'datagen',
  'rows-per-second' = '10',
  'fields.id.kind' = 'sequence',
  'fields.id.start' = '1',
  'fields.id.end' = '10000'
)
LIKE t_iceberg_test (EXCLUDING ALL);