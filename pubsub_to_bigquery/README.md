# Variables
- Make sure the service account used for the pubsub (SA_PUBSUB) has the permission to write to BQ and read BQ metadata
- Make sure the service account used for the dataflow (SA_DATAFLOW) has the permission to write to pubsub

```shell
export PROJECT=forrest-test-project-333203
export PROJECT_NUMBER=49133816376
export REGION=us-central1
export PUBSUB_TOPIC_WITH_SCHEMA=pubsub_to_bq_with_schema
export PUBSUB_TOPIC_NO_SCHEMA=pubsub_to_bq_no_schema
export PUBSUB_SUB_WITH_SCHEMA=pubsub_to_bq_with_schema
export PUBSUB_SUB_NO_SCHEMA=pubsub_to_bq_no_schema
export PUBSUB_SCHEMA=user_events
export SA_DATAFLOW=notebook@forrest-test-project-333203.iam.gserviceaccount.com
export SA_PUBSUB=service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com
export NETWORK=bigdata-network
export SUBNETWORK=dataflow-network
export JOB_NAME="streaming-datagenerator-`date +%Y%m%d-%H%M%S`"
export DATAGEN_SCHEMA_LOCATION="gs://forrest-bigdata-bucket/dataflow/datagen/datagen_schema.json"
export QPS=10
export BQ_TABLE_WITH_SCHEMA=test.pubsub_with_schema
export BQ_TABLE_NO_SCHEMA=test.pubsub_no_schema
export BQ_TABLE_LATENCY=test.pubsub_latency
```

# Copy schemafile to gcs
gsutil cp datagen_schema.json ${DATAGEN_SCHEMA_LOCATION}

# Assign BigQuery roles to the Pub/Sub service account
gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/bigquery.dataEditor \
--member "serviceAccount:${SA_PUBSUB}"

gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/bigquery.metadataViewer \
--member "serviceAccount:${SA_PUBSUB}"

########################################
# Demo for pubsub topic without schema #
########################################

# Create pubsub topic
gcloud pubsub topics create ${PUBSUB_TOPIC_NO_SCHEMA} --project ${PROJECT}

# Start a dataflow pipeline to generate random data
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

# Create BQ table
bq mk \
-t \
--description "Test table for pubsub_to_bq without pubsub schema" \
${PROJECT}:${BQ_TABLE_NO_SCHEMA} \
subscription_name:STRING,message_id:STRING,publish_time:TIMESTAMP,data:STRING,attributes:STRING

# Create pubsub subsciption for bq with schema
gcloud pubsub subscriptions create ${PUBSUB_SUB_NO_SCHEMA} \
--project=${PROJECT} \
--topic-project=${PROJECT} \
--topic=${PUBSUB_TOPIC_NO_SCHEMA} \
--bigquery-table=${PROJECT}:${BQ_TABLE_NO_SCHEMA} \
--write-metadata

# Query BQ table
bq query --use_legacy_sql=false --project_id=${PROJECT} \
'SELECT * FROM '"${BQ_TABLE_NO_SCHEMA}"' ORDER BY publish_time DESC LIMIT 10'



#####################################
# Demo for pubsub topic with schema #
#####################################
# Create pubsub schema
gcloud pubsub schemas create ${PUBSUB_SCHEMA} \
--project=${PROJECT} \
--type=AVRO \
--definition-file=pubsub_schema.json

# Create pubsub topic
gcloud pubsub topics create ${PUBSUB_TOPIC_WITH_SCHEMA} \
--project=${PROJECT} \
--schema=${PUBSUB_SCHEMA} \
--message-encoding=json

# Test publishing a well formed message
x=$(cat wellformed_message.json) && gcloud pubsub topics publish ${PUBSUB_TOPIC_WITH_SCHEMA} \
--project=${PROJECT} \
--message="${x}"

# Test publishing a malformed message where a new kv ("fakeKey": "fakeValue") is added on the top
x=$(cat wellformed_message.json) && gcloud pubsub topics publish ${PUBSUB_TOPIC_WITH_SCHEMA} \
--project=${PROJECT} \
--message="${x}"

# Start a dataflow pipeline to generate data
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

# Create BQ tables
bq mk \
-t \
--description "PUBSUB test table with schema" \
--schema bq_table_with_schema.json \
--time_partitioning_field publish_time \
--time_partitioning_type DAY \
${PROJECT}:${BQ_TABLE_WITH_SCHEMA}



# Create pubsub subsciption for bq with schema
gcloud pubsub subscriptions create ${PUBSUB_SUB_WITH_SCHEMA} \
--project=${PROJECT} \
--topic-project=${PROJECT} \
--topic=${PUBSUB_TOPIC_WITH_SCHEMA} \
--bigquery-table=${PROJECT}:${BQ_TABLE_WITH_SCHEMA} \
--use-topic-schema \
--write-metadata

# Query BQ table
bq query --use_legacy_sql=false --project_id=${PROJECT} \
'SELECT * FROM '"${BQ_TABLE_WITH_SCHEMA}"' ORDER BY publish_time DESC LIMIT 10'

# Check latency of message delivery
bq query --use_legacy_sql=false --project_id=${PROJECT} \
'SELECT CURRENT_TIMESTAMP() - max(publish_time) as latency FROM '"${BQ_TABLE_WITH_SCHEMA}"' WHERE DATE(publish_time) = CURRENT_DATE()'


# log latency
bq mk \
-t \
--description "PUBSUB to BQ latency" \
--schema 'qps:INTEGER,latency:INTEGER,ts:TIMESTAMP' \
${PROJECT}:${BQ_TABLE_LATENCY}

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

# Notes
# BigQuery does not have any unsigned type and so uint64 is not representable. Therefore, any Pub/Sub schema that contains a uint64 or fixed64 type cannot be connected to a BigQuery table.
# Latency: (avg message size: 1KB, ingest to bigquery with pubsub schema)
# QPS=1000  avg: 4845.728 ms, median: 5076 ms, min: 289 ms, max:11376 ms
# QPS=5000  avg: 1978.1782178217816 ms, median: 1478 ms, min: 223 ms, max: 7611 ms
# QPS=20000 avg: 424.21 median: 355, min: 217, max: 1755
