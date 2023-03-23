# Pubsub BigQuery subscrption guide

Pubsub supports ingesting messages to BigQuery directly using Pubsub BigQuery subscription, which has the following advantages:

- Simple deployment. You can set up a BigQuery subscription through a single workflow in the console, Google Cloud CLI, client library, or Pub/Sub API.
- Offers low costs. Removes the additional cost and latency of similar Pub/Sub pipelines that include Dataflow jobs. This cost optimization is useful for messaging systems that do not require additional processing before storage.
- Minimizes monitoring. BigQuery subscriptions are part of the multi-tenant Pub/Sub service and do not require you to run separate monitoring jobs.

In this demo we will:

- Deploy a pipeline from Dataflow template to generate messages and send to Pubsub
- Deploy 2 kinds of Pubsub topics  
  - Pubsub topic with schema. The messages will be delivered to BigQuery table preseving the Pubsub schema. We will also demostrate a smooth schema evolution where message with old and new schemas can co exist from source (Pubsub topc) to sink (Bigquery).
  - Pubsub topic without schema. The whole message will be delivered to the BigQuery destination table in a string column.

The demo is delivered in **Linux Shell** scripts. You can start a **Cloud Shell** sesstion to run the scripts

**Table of Contents**
- [Pubsub BigQuery subscrption guide](#pubsub-bigquery-subscrption-guide)
  - [Declare variables](#declare-variables)
  - [Copy schemafile to gcs](#copy-schemafile-to-gcs)
  - [Assign BigQuery roles to the Pub/Sub service account](#assign-bigquery-roles-to-the-pubsub-service-account)
  - [Demo1: pubsub topic without schema](#demo1-pubsub-topic-without-schema)
    - [Create pubsub topic for receiveing message and dead letter queue](#create-pubsub-topic-for-receiveing-message-and-dead-letter-queue)
    - [Start a dataflow pipeline to generate random data](#start-a-dataflow-pipeline-to-generate-random-data)
    - [Create BigQuery table](#create-bigquery-table)
    - [Create pubsub subsciption for bq with schema](#create-pubsub-subsciption-for-bq-with-schema)
    - [Query BQ table](#query-bq-table)
  - [Demo2: pubsub topic with schema](#demo2-pubsub-topic-with-schema)
    - [Create pubsub schema](#create-pubsub-schema)
    - [Create pubsub topic](#create-pubsub-topic)
    - [Test publishing a well formed message](#test-publishing-a-well-formed-message)
    - [Test publishing a malformed message by changing the value of "clientId" from string to integer](#test-publishing-a-malformed-message-by-changing-the-value-of-clientid-from-string-to-integer)
    - [Start a dataflow pipeline to generate data](#start-a-dataflow-pipeline-to-generate-data)
    - [Create BQ tables](#create-bq-tables)
    - [Create pubsub subsciption for bq with schema](#create-pubsub-subsciption-for-bq-with-schema-1)
    - [Query BQ table](#query-bq-table-1)
    - [Check latency of message delivery](#check-latency-of-message-delivery)
    - [Schema evolution](#schema-evolution)
      - [1. Add the OPTIONAL field to the BigQuery table schema](#1-add-the-optional-field-to-the-bigquery-table-schema)
      - [2. Add optional field to your Pub/Sub schema](#2-add-optional-field-to-your-pubsub-schema)
      - [3. Ensure the new revision is included in the range of revisions accepted by the topic](#3-ensure-the-new-revision-is-included-in-the-range-of-revisions-accepted-by-the-topic)
      - [4. Start publishing messages with the new schema revision](#4-start-publishing-messages-with-the-new-schema-revision)
      - [5. Validate data in BigQuery](#5-validate-data-in-bigquery)
  - [(Optional) Test latency with different QPS](#optional-test-latency-with-different-qps)
    - [Create Bigquery table for latency statistics](#create-bigquery-table-for-latency-statistics)
    - [Query latency statistics](#query-latency-statistics)



## Declare variables

- Make sure the service account used for the pubsub (SA_PUBSUB) has the permission to write to BQ and read BQ metadata
- Make sure the service account used for the dataflow (SA_DATAFLOW) has the permission to write to pubsub

```shell
# You can keep these variables unchanged
export PUBSUB_TOPIC_WITH_SCHEMA=pubsub_to_bq_with_schema
export PUBSUB_TOPIC_NO_SCHEMA=pubsub_to_bq_no_schema
export PUBSUB_TOPIC_DEAD_LETTER=pubsub_to_bq_dead_letter
export PUBSUB_SUB_WITH_SCHEMA=pubsub_to_bq_with_schema
export PUBSUB_SUB_NO_SCHEMA=pubsub_to_bq_no_schema
export PUBSUB_SUB_DEAD_LETTER=pubsub_to_bq_dead_letter
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
export DATAGEN_SCHEMA_LOCATION="gs://forrest-bigdata-bucket/dataflow/datagen"
export QPS=10
```

## Copy schemafile to gcs

gsutil cp datagen_schema.json ${DATAGEN_SCHEMA_LOCATION}/

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

### Create pubsub topic for receiveing message and dead letter queue

```shell
gcloud pubsub topics create ${PUBSUB_TOPIC_NO_SCHEMA} --project ${PROJECT}
gcloud pubsub topics create ${PUBSUB_TOPIC_DEAD_LETTER} --project ${PROJECT}
gcloud pubsub subscriptions create ${PUBSUB_SUB_DEAD_LETTER} \
  --project=${PROJECT} \
  --topic-project=${PROJECT} \
  --topic=${PUBSUB_TOPIC_DEAD_LETTER}
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
  --max-workers=1 \
  --parameters \
schemaTemplate="GAME_EVENT",\
topic="projects/${PROJECT}/topics/${PUBSUB_TOPIC_NO_SCHEMA}",\
qps=${QPS},\
messagesLimit=10000
```

### Create BigQuery table

For Pubsub topics without schema, the message body will be ingested to the <mark>data</mark> column of the BigQuery table. The data column can be either string, byte or json. In this demo we will use JSON type.
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
  subscription_name:STRING,message_id:STRING,publish_time:TIMESTAMP,data:JSON,attributes:STRING
```

### Create pubsub subsciption for bq with schema

```shell
gcloud pubsub subscriptions create ${PUBSUB_SUB_NO_SCHEMA} \
  --project=${PROJECT} \
  --topic-project=${PROJECT} \
  --topic=${PUBSUB_TOPIC_NO_SCHEMA} \
  --bigquery-table=${PROJECT}:${BQ_TABLE_NO_SCHEMA} \
  --write-metadata \
  --dead-letter-topic=${PUBSUB_TOPIC_DEAD_LETTER} 
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

### Test publishing a malformed message by changing the value of "clientId" from string to integer

```shell
x=$(cat malformed_message.json) && gcloud pubsub topics publish ${PUBSUB_TOPIC_WITH_SCHEMA} \
  --project=${PROJECT} \
  --message="${x}"
```

Pubsub will not accept that message and display the error message:
```
ERROR: (gcloud.pubsub.topics.publish) INVALID_ARGUMENT: Invalid data in message: Message failed schema validation.
- '@type': type.googleapis.com/google.rpc.ErrorInfo
  domain: pubsub.googleapis.com
  metadata:
    message: Message failed schema validation
  reason: INVALID_JSON_AVRO_MESSAGE
```

However if you add new fields to the message, Pubsub will accept the message and ingest into BigQuery. However the new fields are discarded in BigQuery. We will cover how to deal with message schema change in [Schema evolution](#schema-evolution).

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
  --max-workers=1 \
  --parameters \
schemaLocation="${DATAGEN_SCHEMA_LOCATION}/datagen_schema.json",\
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
  --write-metadata \
  --dead-letter-topic=${PUBSUB_TOPIC_DEAD_LETTER} 
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

### Schema evolution

Schema evolution, designed to allow the safe and convenient update of schemas with zero downtime for publishers or subscribers. We will add new key to the datagen pipeline and change the schema of pubsub and BigQuery without interrupting the running subscription.
#### 1. Add the OPTIONAL field to the BigQuery table schema

In the `bq_table_with_schema_new.json`, we added a new nested field called "uniquePageViews" to `visits`:

```json
  {
    "name": "visits",
    "type": "RECORD",
    "mode": "REPEATED",
    "fields": [
      {
        "name": "pageURL",
        "type": "STRING"
      },
      {
        "name": "pageViews",
        "type": "INTEGER"
      },
      {
        "name": "uniqueuePageViews",
        "type": "INTEGER"
      }
    ]
  }
```

Run the following command to update BigQuery table schema
```shell
bq update ${PROJECT}:${BQ_TABLE_WITH_SCHEMA} bq_table_with_schema_new.json
```

Verify the new table schema is effective:
```shell
bq show \
  --schema \
  --format=prettyjson \
  ${PROJECT}:${BQ_TABLE_WITH_SCHEMA}
```

#### 2. Add optional field to your Pub/Sub schema
We added a new nested field called "uniquePageViews" to `visits` in the `pubsub_schema_new.json`:

```json
    {
      "name": "visits",
      "type": {
        "type": "array",
        "items": {
          "name": "visits",
          "type": "record",
          "fields": [
            {
              "name": "pageURL",
              "type": "string"
            },
            {
              "name": "pageViews",
              "type": "int"
            },
            {
              "name": "uniquePageViews",
              "type": "int",
              "default": 0
            }
          ]
        }
      }
    }
``` 

Run the following command to add a revision to pubsub schema

```shell
gcloud pubsub schemas commit ${PUBSUB_SCHEMA} \
  --project=${PROJECT} \
  --type=AVRO \
  --definition-file=pubsub_schema_new.json
```

Check the revision is created:

```shell
gcloud pubsub schemas list-revisions ${PUBSUB_SCHEMA} --project=${PROJECT}
```

#### 3. Ensure the new revision is included in the range of revisions accepted by the topic

By default, Pubsub schema will accept all schema revisions. In this demo we do not need to change it. If you want to modify which revisions should be accepted later, run the following command:

```shell
gcloud pubsub topics update ${PUBSUB_TOPIC_WITH_SCHEMA} \
  --project=${PROJECT} \
  --message-encoding=avro \
  --schema=${PUBSUB_SCHEMA} \
  --first-revision-id=<FIRST_REVISION_ID> \
  --last-revision-id=<LAST_REVISION_ID> \
```

#### 4. Start publishing messages with the new schema revision

Now start a new dataflow pipeline:

```shell
gsutil cp datagen_schema_new.json ${DATAGEN_SCHEMA_LOCATION}/

gcloud dataflow flex-template run "streaming-datagen-with-schema-new-`date +%Y%m%d-%H%M%S`" \
  --project=${PROJECT} \
  --region=${REGION} \
  --template-file-gcs-location=gs://dataflow-templates/latest/flex/Streaming_Data_Generator \
  --service-account-email=${SA_DATAFLOW} \
  --network=${NETWORK} \
  --subnetwork=regions/us-central1/subnetworks/${SUBNETWORK} \
  --disable-public-ips \
  --enable-streaming-engine \
  --worker-machine-type=n1-standard-1 \
  --max-workers=1 \
  --parameters \
schemaLocation="${DATAGEN_SCHEMA_LOCATION}/datagen_schema_new.json",\
topic="projects/${PROJECT}/topics/${PUBSUB_TOPIC_WITH_SCHEMA}",\
qps=${QPS},\
messagesLimit=100000
```

#### 5. Validate data in BigQuery

```sql
bq query --use_legacy_sql=false --project_id=${PROJECT} --format=pretty \
'SELECT * FROM ( ' \
'SELECT publish_time, visits FROM ' \
"${BQ_TABLE_WITH_SCHEMA}" \
'WHERE DATE(publish_time) = "2023-03-23" ' \
'AND array_length(visits) > 0 ' \
'AND visits[0].uniquePageViews IS NULL ' \
'ORDER BY publish_time DESC LIMIT 1) ' \
'UNION ALL ' \
'SELECT * FROM ( ' \
'SELECT publish_time, visits FROM ' \
"${BQ_TABLE_WITH_SCHEMA}" \
'WHERE DATE(publish_time) = "2023-03-23" ' \
'AND array_length(visits) > 0 ' \
'AND visits[0].uniquePageViews IS NOT NULL ' \
'ORDER BY publish_time DESC LIMIT 1)'
```

The results shows that messages with both new and old schemas are successfully ingested into BigQuery. This ensures a smooth schema evolution.

## (Optional) Test latency with different QPS

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
