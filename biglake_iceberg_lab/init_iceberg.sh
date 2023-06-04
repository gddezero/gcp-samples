FLINK_VERSION=1.15
ICEBERG_VERSION=1.2.0

apt install wget -y
/usr/lib/flink
wget -c https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-flink-runtime-${FLINK_VERSION}/${ICEBERG_VERSION}/iceberg-flink-runtime-${FLINK_VERSION}-${ICEBERG_VERSION}.jar -P lib
cp /usr/lib/spark/jars/libthrift-0.12.0.jar lib/
cp /usr/lib/hive/lib/hive-common-3.1.3.jar lib/
gsutil cp gs://spark-lib/biglake/biglake-catalog-iceberg${ICEBERG_VERSION}-0.1.0-with-dependencies.jar lib/


cat <<EOF > init.sql
CREATE CATALOG blms WITH (
 'type'='iceberg',
 'warehouse'='#WAREHOUSE#',
 'catalog-impl'='org.apache.iceberg.gcp.biglake.BigLakeCatalog',
 'gcp_project'='#PROJECT#',
 'gcp_location'='us-central1',
 'blms_catalog'='iceberg'
);

USE CATALOG blms;

CREATE DATABASE IF NOT EXISTS iceberg_dataset;
USE iceberg_dataset;

CREATE TABLE IF NOT EXISTS orders (
  id BIGINT,
  user_id BIGINT,
  product_id BIGINT,
  price DECIMAL(10,2),
  quantity INT,
  region_id TINYINT,
  status TINYINT COMMENT '0: created, 1: paid, 3: dispatched, 4: delivered, 5: cancelled, 6: fulfiled, 7: confirmed',
  dt DATE,
  created_at TIMESTAMP(6),
  modified_at TIMESTAMP(6),
  PRIMARY KEY(`id`, `dt`, `region_id`) NOT ENFORCED
) 
PARTITIONED BY (`dt`, `region_id`)
WITH (
  'format-version'='2',
  'write.upsert.enabled'='true',
  'write.parquet.compression-codec'='ZSTD',
  'write.metadata.delete-after-commit.enabled'='true',
  'write.metadata.previous-versions-max'='100',
  'bq_table'='iceberg_dataset.orders', 
  'bq_connection'='projects/#PROJECT#/locations/us-central1/connections/#CONNECTION#');

CREATE OR REPLACE TEMPORARY TABLE orders_gen
WITH (
  'connector' = 'datagen',
  'rows-per-second' = '10000',

  'fields.id.kind' = 'random',
  'fields.id.min' = '1',
  'fields.id.max' = '1000000000',

  'fields.user_id.kind' = 'random',
  'fields.user_id.min' = '1',
  'fields.user_id.max' = '100000',

  'fields.product_id.kind' = 'random',
  'fields.product_id.min' = '1',
  'fields.product_id.max' = '100',

  'fields.price.kind' = 'random',
  'fields.price.min' = '0.01',
  'fields.price.max' = '100',

  'fields.quantity.kind' = 'random',
  'fields.quantity.min' = '1',
  'fields.quantity.max' = '100',

  'fields.region_id.kind' = 'random',
  'fields.region_id.min' = '1',
  'fields.region_id.max' = '10',

  'fields.status.kind' = 'random',
  'fields.status.min' = '0',
  'fields.status.max' = '7'
)
LIKE orders (EXCLUDING ALL);
EOF