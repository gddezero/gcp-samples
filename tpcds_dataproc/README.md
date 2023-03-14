# Spark TPC-DS on Dataproc
TPC-DS is one of the most popular benchmark for OLAP. This guide describes the steps to run TPC-DS on Dataproc.

The demo is delivered in **Linux Shell** scripts. You can start a **Cloud Shell** sesstion to run the scripts.
## Prerequisites

1. VPC including networks, firewall rules, NAT are setup
2. Google APIs (Dataflow, Bigquery, Cloud Storage) are already enabled

## Environment variables

```bash
export CLUSTER_NAME=tpc-ds-cluster
export PROJECT=forrest-test-project-333203
export REGION=us-central1
export NETWORK=bigdata-network
export SUBNET=dataflow-network
export DATAPROC_BUCKET=forrest-dataproc-bucket
export DW_BUCKET=forrest-bigdata-bucket
export DPMS_NAME=hms
gcloud config set project ${PROJECT}
```

## Create DPMS

Create a managed hive metastore. Wait for 15-20 minutes to complete.
```bash
gcloud metastore services create ${DPMS_NAME} \
  --location=${REGION} \
  --hive-metastore-version=3.1.2 \
  --tier=developer \
  --network=${NETWORK} \
  --hive-metastore-configs="hive.metastore.warehouse.dir=gs://${DW_BUCKET}/dw"
```

## Create dataproc cluster
```bash
git clone https://github.com/gddezero/gcp-samples.git
gsutil cp gcp-samples/tpcds_dataproc/tpcds_bootstrap.sh gs://${DATAPROC_BUCKET}/bootstrap/

gcloud dataproc clusters create ${CLUSTER_NAME} \
  --project ${PROJECT} \
  --bucket ${DATAPROC_BUCKET} \
  --region ${REGION} \
  --subnet ${SUBNET} \
  --dataproc-metastore=projects/${PROJECT}/locations/${REGION}/services/${DPMS_NAME} \
  --no-address \
  --scopes cloud-platform \
  --enable-component-gateway \
  --num-masters 1 \
  --num-workers 2 \
  --num-secondary-workers 0 \
  --master-machine-type n2d-highmem-4 \
  --master-min-cpu-platform "AMD Milan" \
  --master-boot-disk-type pd-balanced \
  --master-boot-disk-size 300GB \
  --image-version 2.1-debian11 \
  --worker-machine-type n2d-highmem-8 \
  --worker-min-cpu-platform "AMD Milan" \
  --worker-boot-disk-type pd-balanced \
  --worker-boot-disk-size 300GB \
  --secondary-worker-type spot \
  --secondary-worker-boot-disk-type pd-balanced \
  --worker-boot-disk-size 300GB \
  --initialization-actions gs://${DATAPROC_BUCKET}/bootstrap/tpcds_bootstrap.sh \
  --metadata DW_BUCKET=${DW_BUCKET} \
  --properties "hive:yarn.log-aggregation-enable=true" \
  --properties "spark:spark.checkpoint.compress=true" \
  --properties "spark:spark.eventLog.compress=true" \
  --properties "spark:spark.eventLog.compression.codec=zstd" \
  --properties "spark:spark.eventLog.rolling.enabled=true" \
  --properties "spark:spark.io.compression.codec=zstd" \
  --properties "spark:spark.sql.parquet.compression.codec=zstd" 
```

## Generate TPC-DS 1000 data

After dataproc cluster is deployed, login with SSH to the master node of the Dataproc cluster. Suggest to run the command in tmux or screen session because it takes several minitues to hours to generate TPC-DS 1000GB data

```bash
cd /opt/gcp-samples/tpcds_dataproc
spark-shell --jars spark-sql-perf_2.12-0.5.1-SNAPSHOT.jar -I datagen.scala
```

If you want to generate a different data size, change the following variables in datagen.scala before generating data:

- val scaleFactor = "1000"
- val databaseName = "tpcds1000"

Also change the the value of variable `databaseName` in tpcds.scala

## Run TPC-DS 1000 tests

After TPC-DS data is generated, run the following command to run tests. Suggest to run in tmux or screen session because it takes several minitues to hours to run TPC-DS tests depending on number of executors. Please change `num-executors` according to your worker vcores.

```bash
cd /opt/gcp-samples/tpcds_dataproc
spark-shell \
  --jars spark-sql-perf_2.12-0.5.1-SNAPSHOT.jar \
  --executor-memory 18971M \
  --executor-cores 4 \
  --driver-memory 8192M \
  --deploy-mode client \
  --master yarn \
  --num-executors 10 \
  --conf spark.dynamicAllocation.enabled=false \
  -I tpcds.scala
```
