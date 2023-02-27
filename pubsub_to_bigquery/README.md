# Pubsub BigQuery subscrption guide
Pubsub supports tngesting messages to BigQuery directly using Pubsub BigQuery subscription. In this demo we will
- Deploy a pipeline from Dataflow template to generate messages and send to Pubsub
- Deploy 2 kinds of Pubsub topics  
  - Pubsub topic with schema. The messages will be delivered to BigQuery table preseving the Pubsub schema.
  - Pubsub topic without schema. The whole message will be delivered to the BigQuery destination table in a string column.

The demo is delivered in **Linux Shell** scripts. You can start a **Cloud Shell** sesstion to run the scripts

## Declare variables
- Make sure the service account used for the pubsub (SA_PUBSUB) has the permission to write to BQ and read BQ metadata
- Make sure the service account used for the dataflow (SA_DATAFLOW) has the permission to write to pubsub

```shell
# You can keep these variables unchanged
export PUBSUB_TOPIC_WITH_SCHEMA=pubsub_to_bq_with_schema
export PUBSUB_TOPIC_NO_SCHEMA=pubsub_to_bq_no_schema
export PUBSUB_SUB_WITH_SCHEMA=pubsub_to_bq_with_schema
export PUBSUB_SUB_NO_SCHEMA=pubsub_to_bq_no_schema
export PUBSUB_SCHEMA=user_events
export BQ_TABLE_WITH_SCHEMA=test.pubsub_with_schema
export BQ_TABLE_NO_SCHEMA=test.pubsub_no_schema
export BQ_TABLE_LATENCY=test.pubsub_latency
export JOB_NAME="streaming-datagenerator-`date +%Y%m%d-%H%M%S`"

# Make sure to change these variables
export PROJECT=forrest-test-project-333203
export PROJECT_NUMBER=49133816376
export REGION=us-central1
export SA_DATAFLOW=notebook@${PROJECT}.iam.gserviceaccount.com
export SA_PUBSUB=service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com
export NETWORK=bigdata-network
export SUBNETWORK=dataflow-network
export DATAGEN_SCHEMA_LOCATION="gs://forrest-bigdata-bucket/dataflow/datagen/datagen_schema.json"
export QPS=10
```

## Copy schemafile to gcs
gsutil cp datagen_schema.json ${DATAGEN_SCHEMA_LOCATION}

## Assign BigQuery roles to the Pub/Sub service account
```shell
gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/bigquery.dataEditor \
--member "serviceAccount:${SA_PUBSUB}"

gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/bigquery.metadataViewer \
--member "serviceAccount:${SA_PUBSUB}"
```

## Demo1: pubsub topic without schema

### Create pubsub topic
```shell
gcloud pubsub topics create ${PUBSUB_TOPIC_NO_SCHEMA} --project ${PROJECT}
```

### Start a dataflow pipeline to generate random data
```shell
gcloud dataflow flex-template run "streaming-datagen-no-schema-`date +%Y%m%d-%H%M%S`" \
--project=${PROJECT} \
--region=${REGION} \
--template-file-gcs-location=gs://dataflow-templates/latest/flex/Streaming_Data_Generator \
--service-account-email=${SA_DATAFLOW} \
--network=${NETWORK} \
--subnetwork=regions/us-central1/subnetworks/${SUBNETWORK} \
--disable-public-ips \
--enable-streaming-engine \
--worker-machine-type=n1-standard-1 \
--parameters \
schemaLocation="${DATAGEN_SCHEMA_LOCATION}",\
topic="projects/${PROJECT}/topics/${PUBSUB_TOPIC_NO_SCHEMA}",\
qps=${QPS},\
messagesLimit=10000
```

### Create BigQuery table
For Pubsub topics without schema, the message body will be ingested to the <mark>data</mark> column of the BigQuery table. The data column can be either string or byte.
Pubsub can also ingest metadata to BigQuery table. Add the following colunns:
- subscription_name:STRING
- message_id:STRING
- publish_time:TIMESTAMP
- attributes:STRING

```shell
bq mk \
-t \
--description "Test table for pubsub_to_bq without pubsub schema" \
${PROJECT}:${BQ_TABLE_NO_SCHEMA} \
subscription_name:STRING,message_id:STRING,publish_time:TIMESTAMP,data:STRING,attributes:STRING
```

### Create pubsub subsciption for bq with schema
```shell
gcloud pubsub subscriptions create ${PUBSUB_SUB_NO_SCHEMA} \
--project=${PROJECT} \
--topic-project=${PROJECT} \
--topic=${PUBSUB_TOPIC_NO_SCHEMA} \
--bigquery-table=${PROJECT}:${BQ_TABLE_NO_SCHEMA} \
--write-metadata
```

### Query BQ table
```shell
bq query --use_legacy_sql=false --project_id=${PROJECT} \
'SELECT * FROM '"${BQ_TABLE_NO_SCHEMA}"' ORDER BY publish_time DESC LIMIT 10'
```

## Demo2: pubsub topic with schema

### Create pubsub schema
```shell
gcloud pubsub schemas create ${PUBSUB_SCHEMA} \
--project=${PROJECT} \
--type=AVRO \
--definition-file=pubsub_schema.json
```

### Create pubsub topic
```shell
gcloud pubsub topics create ${PUBSUB_TOPIC_WITH_SCHEMA} \
--project=${PROJECT} \
--schema=${PUBSUB_SCHEMA} \
--message-encoding=json
```

### Test publishing a well formed message
```shell
x=$(cat wellformed_message.json) && gcloud pubsub topics publish ${PUBSUB_TOPIC_WITH_SCHEMA} \
--project=${PROJECT} \
--message="${x}"
```
The message should be published to pubsub successfully.

### Test publishing a malformed message where a new kv ("fakeKey": "fakeValue") is added on the top
```shell
x=$(cat malformed_message.json) && gcloud pubsub topics publish ${PUBSUB_TOPIC_WITH_SCHEMA} \
--project=${PROJECT} \
--message="${x}"
```
Pubsub will deny this message due to unmatched schema

### Start a dataflow pipeline to generate data
```shell
gcloud dataflow flex-template run "streaming-datagen-with-schema-`date +%Y%m%d-%H%M%S`" \
--project=${PROJECT} \
--region=${REGION} \
--template-file-gcs-location=gs://dataflow-templates/latest/flex/Streaming_Data_Generator \
--service-account-email=${SA_DATAFLOW} \
--network=${NETWORK} \
--subnetwork=regions/us-central1/subnetworks/${SUBNETWORK} \
--disable-public-ips \
--enable-streaming-engine \
--worker-machine-type=n1-standard-1 \
--parameters \
schemaLocation="${DATAGEN_SCHEMA_LOCATION}",\
topic="projects/${PROJECT}/topics/${PUBSUB_TOPIC_WITH_SCHEMA}",\
qps=${QPS},\
messagesLimit=100000
```

### Create BQ tables
```shell
bq mk \
-t \
--description "PUBSUB test table with schema" \
--schema bq_table_with_schema.json \
--time_partitioning_field publish_time \
--time_partitioning_type DAY \
${PROJECT}:${BQ_TABLE_WITH_SCHEMA}
```

### Create pubsub subsciption for bq with schema
```shell
gcloud pubsub subscriptions create ${PUBSUB_SUB_WITH_SCHEMA} \
--project=${PROJECT} \
--topic-project=${PROJECT} \
--topic=${PUBSUB_TOPIC_WITH_SCHEMA} \
--bigquery-table=${PROJECT}:${BQ_TABLE_WITH_SCHEMA} \
--use-topic-schema \
--write-metadata
```

### Query BQ table
```shell
bq query --use_legacy_sql=false --project_id=${PROJECT} \
'SELECT * FROM '"${BQ_TABLE_WITH_SCHEMA}"' ORDER BY publish_time DESC LIMIT 10'
```

### Check latency of message delivery
```shell
bq query --use_legacy_sql=false --project_id=${PROJECT} \
'SELECT CURRENT_TIMESTAMP() - max(publish_time) as latency FROM '"${BQ_TABLE_WITH_SCHEMA}"' WHERE DATE(publish_time) = CURRENT_DATE()'
```

## [optional] Test latency with different QPS
### Create Bigquery table for latency statistics
```shell
bq mk \
-t \
--description "PUBSUB to BQ latency" \
--schema 'qps:INTEGER,latency:INTEGER,ts:TIMESTAMP' \
${PROJECT}:${BQ_TABLE_LATENCY}
```

```shell
# Change QPS and run data generator pipeline
QPS=20000
gcloud dataflow flex-template run "streaming-datagen-with-schema-`date +%Y%m%d-%H%M%S`" \
--project=${PROJECT} \
--region=${REGION} \
--template-file-gcs-location=gs://dataflow-templates/latest/flex/Streaming_Data_Generator \
--service-account-email=${SA_DATAFLOW} \
--network=${NETWORK} \
--subnetwork=regions/us-central1/subnetworks/${SUBNETWORK} \
--disable-public-ips \
--enable-streaming-engine \
--worker-machine-type=n1-standard-2 \
--num-workers=10 \
--max-workers=30 \
--parameters \
schemaLocation="${DATAGEN_SCHEMA_LOCATION}",\
topic="projects/${PROJECT}/topics/${PUBSUB_TOPIC_WITH_SCHEMA}",\
qps=${QPS}
```

Wait until the QPS stablized and then run the following script to get 100 samples of latency
```shell
for i in {1..100}
do 
  bq query \
  --use_legacy_sql=false \
  --project_id=${PROJECT} \
  --destination_table=${PROJECT}:${BQ_TABLE_LATENCY} \
  --append_table=true \
  --batch=true \
  --synchronous_mode=false \
  'SELECT '"${QPS}"' as qps, TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),max(publish_time),MILLISECOND) as latency, CURRENT_TIMESTAMP() as ts FROM '"${BQ_TABLE_WITH_SCHEMA}"' WHERE DATE(publish_time) = CURRENT_DATE()'
  sleep 1
  echo $i/100
done
```

You can change QPS, run the data generator pipeline and sampling script if you want to test with different QPS

### Query latency statistics
```shell
bq query --use_legacy_sql=false --project_id=${PROJECT} \
'SELECT qps, '\
'count(1) num_data, '\
'avg(latency) avg_ms, '\
'APPROX_QUANTILES(latency, 2)[OFFSET(1)] median_ms, '\
'APPROX_QUANTILES(latency, 100)[OFFSET(98)] P99_ms, '\
'min(latency) min_ms, '\
'max(latency) max_ms FROM '\
"${BQ_TABLE_LATENCY}"\
' GROUP BY qps'
```

Here is a reference latency with different QPS
| QPS   | avg_ms   | median_ms | min_ms | max_ms |
| ----- | -------- | --------- | ------ | ------ |
| 1000  | 4845.728 | 5076      | 289    | 11376  |
| 5000  | 1978.178 | 1478      | 223    | 7611   |
| 20000 | 424.21   | 355       | 217    | 1755   |
