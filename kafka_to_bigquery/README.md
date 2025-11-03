# Streaming from Kafka to BigQuery guide
Dataflow Template makes it easy to stream data from Kafka to BigQuery. This is a step by step guide of how to create a dataflow pipeline to stream data from Kafka to BigQuery with customized UDF to transform data.

The demo is delivered in **Linux Shell** scripts. You can start a **Cloud Shell** sesstion to run the scripts.

## Prerequisites

1. VPC including networks, firewall rules, NAT are setup
2. Google APIs (Dataflow, Bigquery, Cloud Storage) are already enabled

## Environment variables

Change these environment variables according to your environment.

```bash
export PROJECT=forrest-datastream
export REGION=us-central1
export ZONE=us-central1-f
export NETWORK=bigdata-network
export SUBNET=us-central1-subnet
export GSA_NAME=dataflow-sa
export GSA_FULL="${GSA_NAME}@${PROJECT}.iam.gserviceaccount.com"
export GCS_DATAFLOW=gs://forrest-bigdata-ds-bucket/dataflow
```

## Service account for dataflow

Create a service account for dataflow worker with GCS and BQ permission

```bash
gcloud projects add-iam-policy-binding "${PROJECT}" \
  --project=${PROJECT} \
  --role=roles/bigquery.admin \
  --member="serviceAccount:${GSA_FULL}"

gcloud projects add-iam-policy-binding "${PROJECT}" \
  --project=${PROJECT} \
  --role=roles/dataflow.worker \
  --member="serviceAccount:${GSA_FULL}"

gcloud projects add-iam-policy-binding "${PROJECT}" \
  --project=${PROJECT} \
  --role=roles/storage.objectAdmin \
  --member="serviceAccount:${GSA_FULL}"
```

## Deploy Kafka VM

The following script will create a VM, upload js udf to GCS and run kafka in docker:

```bash
gcloud compute instances create kafka-vm \
  --project=${PROJECT} \
  --zone=${ZONE} \
  --network=${NETWORK} \
  --subnet=${SUBNET} \
  --machine-type=e2-small \
  --boot-disk-size=20GB \
  --scopes=cloud-platform \
  --service-account=${GSA_FULL} \
  --no-address \
  --shielded-secure-boot \
  --metadata=startup-script='#! /bin/bash
  apt update
  apt install git docker-compose -y
  git clone https://github.com/gddezero/gcp-samples.git
  cd gcp-samples/kafka_to_bigquery
  gsutil cp simple_udf.js $GCS_DATAFLOW/scripts/
  export IP=$(ip -o route get to 8.8.8.8 | sed -n "s/.*src \([0-9.]\+\).*/\1/p")
  echo ${IP}
  docker-compose up -d
  docker run -v /gcp-samples/kafka_to_bigquery:/script -w /script -it --network=host --rm apache/kafka bash -c "/script/gen_order.sh"
  '
```

Now a VM is deployed with Kafka broker running. The background running script will generate one message per second. Here is the sample message:

```json
{
    "e": "depthUpdate",
    "t": 1676525078,
    "s": "BTCUSDT",
    "i": 162,
    "l": 160,
    "b":
    [
        "0.0024",
        "10"
    ],
    "a":
    [
        "0.0026",
        "100"
    ]
}
```

We use a JavaScript UDF to transform each message:

1. Transform the key to human readable
2. Transform the Array to structure
3. Add a new key called dt, which is derived from the key "t", to serve as partition key in BigQuery

Run the following command to get IP of Kafka VM, which will be used in dataflow pipeline

```bash
export KAFKA_IP=$(gcloud compute instances describe kafka-vm \
  --project=${PROJECT} \
  --zone=${ZONE} \
  --format json \
  | jq .networkInterfaces[0].networkIP -r)
```

## Create BigQuery tables

Create BigQuery dataset
```bash
bq --location=US mk -d ${PROJECT}:crypto
```

Create BigQuery table
```bash
bq query --use_legacy_sql=false --project_id=${PROJECT} \
"create table ${PROJECT}.crypto.orderbook (
    event_name string,
    event_time int,
    symbol string,
    first_update_id int,
    final_update_id int,
    bids struct<price decimal(10,4), quantity int>,
    asks struct<price decimal(10,4), quantity int>,
    dt date
)
partition by dt"
```

## Deploy dataflow pipeline

```bash
JOB_ID=kafka-to-bq-$(date +%s)
gcloud dataflow flex-template run ${JOB_ID} \
    --template-file-gcs-location="gs://dataflow-templates-us-central1/latest/flex/Kafka_to_BigQuery_Flex" \
    --region ${REGION} \
    --project ${PROJECT} \
    --temp-location ${GCS_DATAFLOW}/temp \
    --network ${NETWORK} \
    --subnetwork regions/${REGION}/subnetworks/${SUBNET} \
    --enable-streaming-engine \
    --worker-machine-type n1-standard-1 \
    --disable-public-ips \
    --service-account-email ${GSA_FULL} \
    --parameters "readBootstrapServerAndTopic=$KAFKA_IP:9092;orderbook" \
    --parameters "kafkaReadAuthenticationMode=NONE" \
    --parameters "writeMode=SINGLE_TABLE_NAME" \
    --parameters "messageFormat=JSON" \
    --parameters "useBigQueryDLQ=false" \
    --parameters "outputTableSpec=${PROJECT}:crypto.orderbook" \
    --parameters "javascriptTextTransformGcsPath=${GCS_DATAFLOW}/scripts/simple_udf.js" \
    --parameters "javascriptTextTransformFunctionName=transform" \
    --parameters "numStorageWriteApiStreams=1" \
    --parameters "storageWriteApiTriggeringFrequencySec=5" \
    --parameters "stagingLocation=${GCS_DATAFLOW}/staging" \
    --parameters "maxNumWorkers=10" \
    --parameters "saveHeapDumpsToGcsPath=${GCS_DATAFLOW}/dump" \
    --parameters "kafkaReadOffset=earliest" \
    --parameters "enableCommitOffsets=true" \
    --parameters "consumerGroupId=dataflow-consumer"
```

## Query data

```bash
bq query --use_legacy_sql=false --project_id=${PROJECT} \
"select * from ${PROJECT}.crypto.orderbook order by event_time desc limit 20"
```

| event_name  | event_time | symbol  | first_update_id | final_update_id |                bids                |                asks                |     dt     |
|-------------|------------|---------|-----------------|-----------------|------------------------------------|------------------------------------|------------|
| depthUpdate | 1678194676 | BTCUSDT |             335 |             333 | {"price":"4.7201","quantity":"27"} | {"price":"7.0086","quantity":"16"} | 2023-03-07 |
| depthUpdate | 1678194675 | BTCUSDT |             334 |             332 | {"price":"9.0755","quantity":"55"} | {"price":"0.2344","quantity":"67"} | 2023-03-07 |
| depthUpdate | 1678194674 | BTCUSDT |             333 |             331 |  {"price":"0.186","quantity":"66"} | {"price":"9.9133","quantity":"71"} | 2023-03-07 |
| depthUpdate | 1678194673 | BTCUSDT |             332 |             330 | {"price":"0.3535","quantity":"76"} |   {"price":"7.874","quantity":"6"} | 2023-03-07 |
| depthUpdate | 1678194672 | BTCUSDT |             331 |             329 |  {"price":"9.0123","quantity":"9"} | {"price":"7.9256","quantity":"50"} | 2023-03-07 |
| depthUpdate | 1678194671 | BTCUSDT |             330 |             328 | {"price":"1.9524","quantity":"91"} | {"price":"7.9874","quantity":"92"} | 2023-03-07 |

## Clean up

Stop dataflow pipeline

```bash
gcloud dataflow jobs cancel ${JOB_ID}
```

Terminate kafka VM

```bash
gcloud compute instances delete kafka-vm \
  --project=${PROJECT} \
  --zone=${ZONE}
```

Delete BigQuery dataset and table

```bash
bq rm -r -f -d ${PROJECT}:crypto
```
