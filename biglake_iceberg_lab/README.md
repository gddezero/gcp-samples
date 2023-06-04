# BigLake lab: Integrate Biglake with Iceberg

This is a step by step guide of how to stream data to Google Cloud Storage (GCS) with Flink using iceberg format.

Components used in this lab:

- **Apache Iceberg** is an open table format for huge analytic datasets. Iceberg adds tables to compute engines including Google BigLake, Spark, Trino, PrestoDB, Flink, Hive and Impala using a high-performance table format that works just like a SQL table.
- **Apache Flink** is a popular framework and distributed processing engine for stateful computations over unbounded and bounded data streams.
- **Cloud Storage** is a managed service for storing structured and unstructured data. Store any amount of data and retrieve it as often as you like.
- **BigQuery**
- **BigLake** 
- **Dataproc** 

## Prerequisitions

1. Create a GCP project
2. Setup vpc, network, firwall rule in your GCP project in **us-central1**
3. You need permission of BigQuery admin, Dataproc admin and Storage Admin
4. Create GCS buckets for dataproc staging and iceberg table

## Environment variables

Change these varaibles in your environment

```bash
export PROJECT=forrest-test-project-333203
export SUBNET=dataflow-network
export CLUSTER_NAME=iceberg-demo-cluster
export DATAPROC_BUCKET=forrest-dataproc-bucket
export SA_NAME=iceberg-demo
export CONNECTION=biglake-iceberg
export WAREHOUSE_DIR=gs://my-dw-bucket/iceberg
export DATAPROC_BUCKET=gs://my-dataproc-bucket
```

## Steps

Open cloud shell in your GCP console

### 1. Setup service account for dataproc

Create service account:

```bash
gcloud iam service-accounts create "${SA_NAME}" \
--description "Service account for Dataproc to run flink."
```

Bind roles to service account:

```bash
gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/dataproc.worker \
--member "serviceAccount:${SA}@${PROJECT}iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/bigquery.connectionAdmin \
--member "serviceAccount:${SA}@${PROJECT}iam.gserviceaccount.com"
```

### 2. Create BigQuery connection for BigLake table

Create a BigQuery connection for BigLake

```bash
bq mk --connection --location=us-central1 --project_id=${PROJECT} \
    --connection_type=CLOUD_RESOURCE ${CONNECTION}
```

The BigQuery connection will create a service account which will be used to read data from GCS. You can check the service account using the bq tool:

```bash
bq show --connection ${PROJECT_ID}.us-central1.${CONNECTION}
```

Assign IAM role to the service account

```bash
SA_CONNECTION=$(bq show --connection ${PROJECT_ID}.us-central1.${CONNECTION})

gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/biglake.admin \
--member "serviceAccount:${SA_CONNECTION}"

gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/storage.objectViewer \
--member "serviceAccount:${SA_CONNECTION}"
```

### 3. Create Dataproc cluster

Clone git repository

```bash
git clone https://github.com/gddezero/gcp-samples.git
cd biglake_iceberg_lab
```

Upload the initialization action script to GCS

```bash
gsutil cp init_iceberg.sh gs://${DATAPROC_BUCKET}/init_scripts/
```

Create Dataproc Cluster

```bash
gcloud dataproc clusters create ${CLUSTER_NAME} \
--project $PROJECT \
--single-node \
--scopes cloud-platform \
--region us-central1 \
--enable-component-gateway \
--no-address \
--subnet ${SUBNET} \
--bucket ${DATAPROC_BUCKET} \
--temp-bucket ${DATAPROC_BUCKET} \
--service-account ${SA}@${PROJECT}iam.gserviceaccount.com \
--master-machine-type n2d-highmem-4 \
--master-boot-disk-size 100 \
--master-boot-disk-type pd-balanced \
--image-version 2.1-debian11 \
--optional-components "Flink" \
--initialization-actions ${DATAPROC_BUCKET}/init_scripts/init_iceberg.sh
```

### 4. Start Flink SQL client

```bash
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1
```

```bash
cd /usr/lib/flink
export HADOOP_CLASSPATH=`hadoop classpath`
sudo bin/sql-client.sh embedded -s yarn-session
```

### 5. Start Flink job

In the Flink SQL shell,

```sql
INSERT INTO orders SELECT * FROM orders_gen;
```
   
### 6. Verify Flink job is running

Now you can check the job status from the YARN Web UI. If the job is running correctly, you can find iceberg files on GCS ${WAREHOUSE_DIR}/iceberg_dataset.db/orders

### 7. Query data from BigQuery

### 8. Setup Row and Column access control

### 9. Create Materialized View for BigLake table

### 10. [Optional] Visualize with Looker Studio

### Clean up