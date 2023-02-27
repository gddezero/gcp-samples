# Query Hive table on Google Cloud Storage (GCS) using StarRocks

StarRocks is a next-gen, high-performance analytical data warehouse that enables real-time, multi-dimensional, and highly concurrent data analysis. You can load data into StarRocks table or connect to external catalogs like Hive, Iceberg, Hudi, Delta Lake. This guide shows how to connect to Hive metastore and query data on Google Cloud Storage (GCS)。

**Table of Contents**
- [Query Hive table on Google Cloud Storage (GCS) using StarRocks](#query-hive-table-on-google-cloud-storage-gcs-using-starrocks)
  - [Prerequisites](#prerequisites)
  - [Environment varialbes](#environment-varialbes)
  - [1. Install StarRocks](#1-install-starrocks)
    - [1.1 Install StarRocks](#11-install-starrocks)
    - [1.2 Install GCS connector](#12-install-gcs-connector)
    - [1.3 Configure StarRocks](#13-configure-starrocks)
    - [1.4 Start FE](#14-start-fe)
    - [1.4 Start BE](#14-start-be)
    - [1.5 Install MySQL client](#15-install-mysql-client)
    - [1.6 Setup StarRocks cluster](#16-setup-starrocks-cluster)
  - [2. Query Hive table on GCS](#2-query-hive-table-on-gcs)
    - [2.1 Create Hive catalog](#21-create-hive-catalog)
    - [2.2 Query Hive table on GCS](#22-query-hive-table-on-gcs)
  - [3. Issues](#3-issues)
    - [3.1 CA cert issue](#31-ca-cert-issue)
    - [3.2 gs scheme not recognized](#32-gs-scheme-not-recognized)
    - [3.3 Error querying partitioned table](#33-error-querying-partitioned-table)

## Prerequisites

1. We validated on StarRocks 2.5.2
2. This guide is based on Debian 11. However it should also work on Ubuntu.
3. Java8 and Java11 are supported
4. Get your GCS credential in the GCP console: 
   - Navigate to: Cloud Storage -> Settings -> INTEROPERABILITY
   - We recommend to create key for service account. Make sure your service account have the right permission to read GCS bucket where your data resides.
   - Save your `Access Key` and `Secret Key` safely. You will need these keys when creating Hive catalog.
5. A Hive metastore is mandatory to query Hive table.

## Environment varialbes

```bash
export STARROCKS_BASE=/data
export STARROCKS_HOME=$STARROCKS_BASE/starrocks
export JAVA_HOME=/lib/jvm/default-java
```

## 1. Install StarRocks

If you have already installed StarRocks, You can skip the steps except [1.2 Install GCS connector](#12-install-gcs-connector). GCS connector is required to read data from GCS.

### 1.1 Install StarRocks

```bash
sudo apt update
sudo apt upgrade
wget https://releases.starrocks.io/starrocks/StarRocks-2.5.2.tar.gz -P /tmp
tar -zxvf /tmp/StarRocks-2.5.2.tar.gz -C $STARROCKS_BASE
ln -s StarRocks-2.5.2 starrocks
```

### 1.2 Install GCS connector

```bash
wget https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-latest.jar -P $STARROCKS_HOME/fe/lib
```

### 1.3 Configure StarRocks

```bash
cd $STARROCK_HOME
mkdir -p fe/meta
mkdir -p be/storage
```

Edit fe/conf/fe.conf and be/conf/be.conf. Change priority_networks to your ip or subnet:
`priority_networks=<your ip or subnet>`

### 1.4 Start FE

```bash
fe/bin/start_fe.sh --daemon
cat fe/log/fe.log | grep thrift
```

If the FE started successfully, you will se message in the log like:
```2023-02-17 04:20:28,087 INFO (UNKNOWN 192.168.0.10_9010_1676607618320(-1)|1) [FeServer.start():52] thrift server started with port 9020.```

### 1.4 Start BE

```bash
be/bin/start_be.sh --daemon
cat be/log/be.INFO | grep heartbeat
```

If the BE started successfully, you will se message in the log like:
```I0217 03:37:23.692181 2591550 thrift_server.cpp:375] heartbeat has started listening port on 9050```

### 1.5 Install MySQL client

```bash
sudo apt install mysql-client-core-8.0
```

### 1.6 Setup StarRocks cluster

Connect to StarRocks:

```bash
mysql -h <ip> -P9030 -uroot
```

Check the status of FE

```mysql
SHOW PROC '/frontends'\G

mysql> SHOW PROC '/frontends'\G
*************************** 1. row ***************************
             Name: 192.168.0.10_9010_1676607618320
               IP: 192.168.0.10
      EditLogPort: 9010
         HttpPort: 8030
        QueryPort: 9030
          RpcPort: 9020
             Role: LEADER
        ClusterId: 1262703115
             Join: true
            Alive: true
ReplayedJournalId: 1077
    LastHeartbeat: 2023-02-17 05:19:48
         IsHelper: true
           ErrMsg: 
        StartTime: 2023-02-17 04:20:27
          Version: 2.5.1-f1d669f
1 row in set (0.05 sec)
```

Add BE

```mysql
ALTER SYSTEM ADD BACKEND "<IP of BE>:9050";
```

Check the status of BE

```mysql
SHOW PROC '/backends'\G

*************************** 1. row ***************************
            BackendId: 10003
                   IP: 192.168.0.10
        HeartbeatPort: 9050
               BePort: 9060
             HttpPort: 8040
             BrpcPort: 8060
        LastStartTime: 2023-02-17 05:20:44
        LastHeartbeat: 2023-02-17 05:20:54
                Alive: true
 SystemDecommissioned: false
ClusterDecommissioned: false
            TabletNum: 30
     DataUsedCapacity: 0.000 
        AvailCapacity: 109.119 GB
        TotalCapacity: 392.653 GB
              UsedPct: 72.21 %
       MaxDiskUsedPct: 72.21 %
               ErrMsg: 
              Version: 2.5.1-f1d669f
               Status: {"lastSuccessReportTabletsTime":"2023-02-17 05:20:45"}
    DataTotalCapacity: 109.119 GB
          DataUsedPct: 0.00 %
             CpuCores: 4
    NumRunningQueries: 0
           MemUsedPct: 0.95 %
           CpuUsedPct: 0.2 %
1 row in set (0.00 sec)
```

## 2. Query Hive table on GCS

### 2.1 Create Hive catalog

```mysql
CREATE EXTERNAL CATALOG hive_catalog_hms
PROPERTIES
(
    "type" = "hive",
    "aws.s3.use_instance_profile" = "false",
    "aws.s3.enable_ssl" = "false",
    "aws.s3.enable_path_style_access" = "true",
    "aws.s3.access_key" = "<GCS Access Key>",
    "aws.s3.secret_key" = "<GCS Secret Key>",
    "aws.s3.endpoint" = "storage.googleapis.com",
    "aws.s3.region" = "us-central1",
    "hive.metastore.uris" = "thrift://<IP or hostname of Hive Metastore>:9083"
);
```

### 2.2 Query Hive table on GCS

Now you can write SQL to query Hive table on GCS. For example:

```sql
use hive_catalog_hms.<database>;
select * from <table> limit 10;
```

## 3. Issues

### 3.1 CA cert issue

```sql
mysql> select custkey, name  from hive_catalog_hms.tpch_sf1000_parquet.customer limit 10;
```

Error Message:

```
ERROR 1064 (HY000): code=-1(SdkErrorType:99), message=curlCode: 77, Problem with the SSL CA cert (path? access rights?):file = gs://forrest-tpch/sf1000/parquet/customer/20220311_110759_00089_i7eg5_e68932fd-1b70-434d-bb16-575b0ed148a5`
```

**Root cause**: The ssl over Google Storage endpoint is not supported on aws-cpp-sdk version 1.9.179

**Solution**: The best solution is to upgrade aws-cpp-sdk. But this will require rebuilding the BE. A workaround is to disable ssl when creating the Hive catalog:
```
CREATE EXTERNAL CATALOG hive_catalog_hms
PROPERTIES
(
    "aws.s3.enable_ssl" = "false",
    ...
)
```

### 3.2 gs scheme not recognized

```sql
mysql> select custkey, name  from hive_catalog_hms.tpch_sf1000_parquet.customer limit 10;
```

Error Message:

```
ERROR 1064 (HY000): Failed to get remote files, msg: com.starrocks.connector.exception.StarRocksConnectorException: Failed to get hive remote file's metadata on path: RemotePathKey{path='gs://forrest-tpch/sf1000/parquet/customer', isRecursive=false}. msg: No FileSystem for scheme "gs"
```

**Root cause**: GCS connector is not installed
**Solution**: Install GCS connector as described in [1.2 Install GCS connector](#12-install-gcs-connector)

### 3.3 Error querying partitioned table

```sql
mysql> select * from hive_catalog_hms.tpch_sf1000_parquet.test_partitioned limit 10;
```

Error message:

```
ERROR 1064 (HY000): code=403(SdkErrorType:22), message=The request signature we calculated does not match the signature you provided. Check your Google secret key and signing method.


I0221 07:36:34.147534 3307570 fragment_executor.cpp:158] Prepare(): query_id=774027c1-b1ba-11ed-a93b-024213766ee0 fragment_instance_id=774027c1-b1ba-11ed-a93b-024213766ee2 backend_num=0
I0221 07:36:34.149526 3307564 fragment_executor.cpp:158] Prepare(): query_id=774027c1-b1ba-11ed-a93b-024213766ee0 fragment_instance_id=774027c1-b1ba-11ed-a93b-024213766ee1 backend_num=1
I0221 07:36:34.150056 3307472 hdfs_scanner.cpp:151] open file success: gs://forrest-tpch/sf1000/parquet/test_partitioned/dt=2023-01-02/000000_0
I0221 07:36:34.150540 3307444 hdfs_scanner.cpp:151] open file success: gs://forrest-tpch/sf1000/parquet/test_partitioned/dt=2023-01-01/000000_0
W0221 07:36:34.175235 3307472 hdfs_scanner_text.cpp:243] Status is not ok code=403(SdkErrorType:22), message=The request signature we calculated does not match the signature you provided. Check your Google secret key and signing method.
E0221 07:36:34.175277 3307472 hdfs_scanner.cpp:134] failed to read file: gs://forrest-tpch/sf1000/parquet/test_partitioned/dt=2023-01-02/000000_0

W0221 07:36:34.175367 3307389 pipeline_driver.cpp:226] pull_chunk returns not ok status IO error: code=403(SdkErrorType:22), message=The request signature we calculated does not match the signature you provided. Check your Google secret key and signing method.
/root/starrocks/be/src/exec/vectorized/hdfs_scanner.cpp:23 value_or_err_L23
/root/starrocks/be/src/exec/vectorized/hdfs_scanner_text.cpp:92 value_or_err_L92
/root/starrocks/be/src/formats/csv/csv_reader.cpp:19 _fill_buffer()
/root/starrocks/be/src/exec/vectorized/hdfs_scanner_text.cpp:67 CSVReader::next_record(record)
/root/starrocks/be/src/exec/vectorized/hdfs_scanner_text.cpp:194 parse_csv(runtime_state->chunk_size(), chunk)
/root/starrocks/be/src/connector/hive_connector.cpp:405 _scanner->get_next(state, chunk)
/root/starrocks/be/src/exec/pipeline/scan/scan_operator.cpp:197 _get_scan_status()
W0221 07:36:34.175385 3307389 pipeline_driver_executor.cpp:139] [Driver] Process error, query_id=774027c1-b1ba-11ed-a93b-024213766ee0, inst
ance_id=774027c1-b1ba-11ed-a93b-024213766ee1, status=IO error: code=403(SdkErrorType:22), message=The request signature we calculated does 
not match the signature you provided. Check your Google secret key and signing method.
/root/starrocks/be/src/exec/vectorized/hdfs_scanner.cpp:23 value_or_err_L23
/root/starrocks/be/src/exec/vectorized/hdfs_scanner_text.cpp:92 value_or_err_L92
/root/starrocks/be/src/formats/csv/csv_reader.cpp:19 _fill_buffer()
/root/starrocks/be/src/exec/vectorized/hdfs_scanner_text.cpp:67 CSVReader::next_record(record)
/root/starrocks/be/src/exec/vectorized/hdfs_scanner_text.cpp:194 parse_csv(runtime_state->chunk_size(), chunk)
/root/starrocks/be/src/connector/hive_connector.cpp:405 _scanner->get_next(state, chunk)
/root/starrocks/be/src/exec/pipeline/scan/scan_operator.cpp:197 _get_scan_status()
```

**Root cause**: The object name of the partition table contain sepcial character of '='. StarRocks depens on aws-sdk-cpp to request object on GCS. Currently StarRocks is build with aws-sdk-cpp 1.9.179 which does not encode special characters properly for GCS. Check the details in Github issue: [Objects with "=" in name cause 403 error on some providers. #1224](https://github.com/aws/aws-sdk-cpp/issues/1224)

**Solution**: Build the BE with aws-sdk-cpp 1.9.272.