#!/bin/bash

# Copy initialization script to GCS
gsutil cp init_iceberg.sh gs://${DATAPROC_BUCKET}/init_scripts/

# Deply dataproc cluster
gcloud dataproc clusters create ${CLUSTER_NAME} \
--project ${PROJECT} \
--single-node \
--scopes cloud-platform \
--region us-central1 \
--enable-component-gateway \
--no-address \
--subnet ${SUBNET} \
--bucket ${DATAPROC_BUCKET} \
--temp-bucket ${DATAPROC_BUCKET} \
--service-account ${SA_NAME}@${PROJECT}.iam.gserviceaccount.com \
--master-machine-type n2d-highmem-4 \
--master-boot-disk-size 100 \
--master-boot-disk-type pd-balanced \
--image-version 2.1-debian11 \
--optional-components "Flink" \
--initialization-actions gs://${DATAPROC_BUCKET}/init_scripts/init_iceberg.sh \
--metadata flink-start-yarn-session=true \
--metadata DATAPROC_BUCKET=${DATAPROC_BUCKET} \
--metadata WAREHOUSE_DIR=${WAREHOUSE_DIR} \
--metadata CONNECTION=${CONNECTION} \
--metadata PROJECT=${PROJECT}
