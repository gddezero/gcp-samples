# Streaming data to GCS with Flink using iceberg format

Contributed by @DigitalWNZ

Apache Iceberg is an open table format for huge analytic datasets. Iceberg adds tables to compute engines including Google BigLake, Spark, Trino, PrestoDB, Flink, Hive and Impala using a high-performance table format that works just like a SQL table.

Apache Flink is a framework and distributed processing engine for stateful computations over unbounded and bounded data streams.

Cloud Storage is a managed service for storing structured and unstructured data. Store any amount of data and retrieve it as often as you like.

This is a step by step guide of how to stream data to Google Cloud Storage (GCS) with Flink using iceberg format.

## Prerequisitions

1. Create a service account in Google Cloud with GCS read and write permissions on the desired bucket
2. Download GCP credential json file
3. Install java 11 on your VM or MAC
4. The minimum Flink version supported is 1.15. Flink 1.15 is validated in our lab.

## Environment variables

Change these varaibles in your environment

```bash
export FLINK_HOME=/home/maxwellx/flink
export HADOOP_HOME=/home/maxwellx/hadoop
export FLINK_VERSION=1.15
export ICEBERG_VERSION=1.1.0
export HADOOP_VERSION=3.3.4
export GCS_CONNECTOR_VERSION=2.2.11
export GOOGLE_APPLICATION_CREDENTIALS=/home/maxwellx/gcs_rw_credential.json
export FLINK_GCS=gs://<bucket name>/flink
export WAREHOUSE_DIR=gs://<bucket name>/path
```

## Steps

### Install and configure Hadoop

1. Install Hadoop

   ```bash
   mkdir -p ${HADOOP_HOME}
   wget -c https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz -P /tmp
   tar -xxzf /tmp/hadoop-${HADOOP_VERSION}.tar.gz -C ${HADOOP_HOME}
   ```

2. Configure core-site.xml

   Paste the following contents to file ${HADOOP_HOME}/etc/hadoop/core-site.xml. Make sure to change:

   - fs.gs.project.id
   - fs.gs.auth.service.account.json.keyfile

   ```xml
   <configuration>
     <property>
       <name>fs.gs.project.id</name>
       <value>replace with your gcp project id</value>
       <description>
         Optional. Google Cloud Project ID with access to GCS buckets.
         Required only for list buckets and create bucket operations.
       </description>
     </property>
     <property>
       <name>fs.gs.auth.type</name>
       <value>SERVICE_ACCOUNT_JSON_KEYFILE</value>
       <description>
         Authentication type to use for GCS access.
       </description>
     </property>
     <property>
       <name>fs.gs.auth.service.account.json.keyfile</name>
       <value>replace with GOOGLE_APPLICATION_CREDENTIALS</value>
     </property>
   </configuration>
   ```

### Install GCS connector for Hadoop

```bash
wget -c https://github.com/GoogleCloudDataproc/hadoop-connectors/releases/download/v${GCS_CONNECTOR_VERSION}/gcs-connector-hadoop3-${GCS_CONNECTOR_VERSION}-shaded.jar -P ${HADOOP_HOME}/share/hadoop/common/lib
```

### Install and configure Flink

1. Install Flink
Flink binaries can be found here: https://flink.apache.org/downloads.html

   ```bash
   mkdir -p ${FLINK_HOME}
   wget -c https://archive.apache.org/dist/flink/${FLINK_VERSION}.0/flink-${FLINK_VERSION}.0-bin-scala_2.12.tgz -P /tmp
   tar -xzf /tmp/flink-${FLINK_VERSION}.0-bin-scala_2.12.tgz -C ${FLINK_HOME}
   ```

2. Enable GCS support for Flink
   
   ```bash
   mkdir -p ${FLINK_HOME}/plugins/gs-fs-hadoop
   cp ${FLINK_HOME}/opt/flink-gs-fs-hadoop-${FLINK_VERSION}.0.jar ${FLINK_HOME}/plugins/gs-fs-hadoop/
   ```

3. Install Iceberg runtime for flink
Iceberg runtime for Flink can be found here: https://repo1.maven.org/maven2/org/apache/iceberg/
   ```bash
   wget -c https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-flink-runtime-${FLINK_VERSION}/${ICEBERG_VERSION}/iceberg-flink-runtime-${FLINK_VERSION}-${ICEBERG_VERSION}.jar -C ${FLINK_HOME}/lib
   ```

4. Configure Flink
Update the following parameters in Flink configuration file: ${FLINK_HOME}/conf/flink-conf.yaml

   ```yaml
   execution.checkpointing.interval: 1min
   state.backend: hashmap
   state.checkpoints.dir: <replace with ${FLINK_GCS}>/checkpoints
   state.savepoints.dir: <replace with ${FLINK_GCS}>/savepoints
   env.hadoop.conf.dir: <replace with ${HADOOP_HOME}>/etc/hadoop
   classloader.resolve-order: parent-first
   ```
   
### Stream data using Flink SQL

1. Start Flink standalone

   ```bash
   export HADOOP_CLASSPATH=`${HADOOP_HOME}/bin/hadoop classpath`
   cd ${FLINK_HOME}
   ./bin/start-cluster.sh
   ```

   **Notice it's ` instead of '**

2. An init.sql file is created for you to initialize the catalog, database and tables.
We use datagen to generate random data and write to iceberg table on GCS. Make sure to replace the **warehouse** parameter in line 5.

   ```sql
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
   ```

1. Start Flink SQL client

   ```bash
   cd ${FLINK_HOME}
   ./bin/sql-client.sh embedded -j ./lib/iceberg-flink-runtime-1.15-1.1.0.jar -i init.sql shell
   ```

2. Stream data to iceberg table on GCS
   
   ```sql
   INSERT INTO t_iceberg_test
   SELECT * from t_gen_iceberg_test;
   ```

Now you can check the job status from the Flink [WebUI](http://localhost:8081). If the job is running, you can find iceberg files on GCS ${WAREHOUSE_DIR}/iceberg_test_db/t_iceberg_test

### Clean up

1. Exit Flink SQL client
2. Cancel the Flink SQL job on [WebUI](http://localhost:8081). 
3. Stop Flink cluster
   ```bash
   cd ${FLINK_HOME}
   ./bin/stop-cluster.sh
   ```