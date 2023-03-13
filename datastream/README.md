
# Datastream to synchronize MySQL data to BigQuery

The demo is delivered in **Linux Shell** scripts. You can start a **Cloud Shell** sesstion to run the scripts. Make sure to create a new project to run these shell scripts because we will create network, subnet, NAT, firewall rules, service accounts in the project, which might conflict with you existing network and other configurations.


## Environment variables

```bash
export PROJECT=forrest-datastream
export REGION=us-central1
export ZONE=us-central1-f
export SQL_INSTANCE=dev-mysql
export NETWORK=bigdata-network
export SUBNET=us-central1-subnet
export PROXY_URL="https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.1.1"
export PROXY=sql-proxy
export GSA_NAME=cloudsql-sa
export GSA_FULL="${GSA_NAME}@${PROJECT}.iam.gserviceaccount.com"
export ROOT_PASSWORD=***
```

Make sure to replace ROOT_PASSWORD with your password

## Enable API
```bash
gcloud services enable compute.googleapis.com --project ${PROJECT}
gcloud services enable dns.googleapis.com --project ${PROJECT}
gcloud services enable servicenetworking.googleapis.com --project ${PROJECT}
gcloud services enable sqladmin.googleapis.com --project ${PROJECT}
gcloud services enable datastream.googleapis.com --project ${PROJECT}
gcloud services enable --project ${PROJECT}
gcloud services enable --project ${PROJECT}
gcloud services enable --project ${PROJECT}
gcloud services enable --project ${PROJECT}
```

## VPC

```bash
gcloud compute networks create ${NETWORK} \
  --project=${PROJECT} \
  --subnet-mode=custom \
  --mtu=1460 \
  --bgp-routing-mode=regional

gcloud compute networks subnets create ${SUBNET} \
  --project=${PROJECT} \
  --range=10.0.0.0/22 \
  --stack-type=IPV4_ONLY \
  --network=${NETWORK} \
  --region=${REGION} \
  --enable-private-ip-google-access

gcloud compute addresses create google-managed-services-${NETWORK} \
  --project=${PROJECT} \
  --global \
  --purpose=VPC_PEERING \
  --addresses=10.0.4.0 \
  --prefix-length=22 \
  --network=${NETWORK}

gcloud services vpc-peerings connect \
  --project=${PROJECT} \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-${NETWORK} \
  --network=${NETWORK}

gcloud compute firewall-rules create cloud-iap \
  --project=${PROJECT} \
  --allow=tcp:22 \
  --source-ranges=35.235.240.0/20 \
  --network=${NETWORK}

gcloud compute firewall-rules create mysql \
  --project=${PROJECT} \
  --allow=tcp:3306 \
  --source-ranges=10.0.0.0/8 \
  --network=${NETWORK}

gcloud compute routers create nat-router \
  --project=${PROJECT} \
  --region=${REGION} \
  --network=${NETWORK}  


gcloud compute routers nats create nat-bigdata \
  --project=${PROJECT} \
  --region=${REGION} \
  --router=nat-router \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges
```

## Cloud SQL

### Create Cloud SQL instance

```bash
gcloud sql instances create ${SQL_INSTANCE} \
  --project=${PROJECT} \
  --database-version=MYSQL_5_7 \
  --storage-size=100GB \
  --storage-type=SSD \
  --storage-auto-increase \
  --no-assign-ip \
  --enable-google-private-path \
  --enable-bin-log \
  --region=${REGION} \
  --zone=${ZONE} \
  --network=${NETWORK} \
  --root-password=${ROOT_PASSWORD}
```

### Create service account

```bash
gcloud iam service-accounts create "${GSA_NAME}" \
  --project=${PROJECT} \
  --description="Used by Cloud SQL proxy"

gcloud projects add-iam-policy-binding "${PROJECT}" \
  --project=${PROJECT} \
  --role=roles/cloudsql.admin \
  --member="serviceAccount:${GSA_FULL}"
```

### Create a VM with SQL proxy

```bash
gcloud compute instances create ${PROXY} \
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
  --metadata=startup-script="#! /bin/bash
  apt update
  apt install default-mysql-client-core -y
  curl $PROXY_URL/cloud-sql-proxy.linux.amd64 -o cloud-sql-proxy
  chmod +x cloud-sql-proxy
  ./cloud-sql-proxy --private-ip --address 0.0.0.0 ${PROJECT}:${REGION}:${SQL_INSTANCE}"
```

Get IP for the VM

```bash
export SQL_IP=$(gcloud compute instances describe ${PROXY} --project=${PROJECT} --zone=${ZONE} --format json | jq .networkInterfaces[0].networkIP -r)
```

## Datastream configuration

### Create Datastream private connection

```bash
gcloud datastream private-connections create conn-bigdata \
  --project=${PROJECT} \
  --location=${REGION} \
  --display-name=conn-bigdata \
  --vpc=${NETWORK} \
  --subnet=10.0.8.0/29
```

### Create Datastream profile for MySQL

```bash
gcloud datastream connection-profiles create prof-mysql \
  --project=${PROJECT} \
  --location=${REGION} \
  --type=mysql \
  --mysql-username=root \
  --mysql-password=${ROOT_PASSWORD} \
  --display-name=prof-mysql \
  --mysql-hostname=${SQL_IP} \
  --mysql-port=3306 \
  --private-connection=conn-bigdata
```

### Create Datastream profile for BigQuery

```bash
gcloud datastream connection-profiles create prof-bq \
  --project=${PROJECT} \
  --location=${REGION} \
  --type=bigquery \
  --display-name=prof-bq
```

### Create Datastream stream

```bash
gcloud datastream streams create stream-mysql-to-bq \
  --project=${PROJECT} \
  --location=${REGION} \
  --display-name=stream-mysql-to-bq \
  --source=prof-mysql \
  --mysql-source-config=mysql_config.json \
  --destination=prof-bq \
  --bigquery-destination-config=bq_config.json \
  --backfill-all
```

### Start the steam

```bash
gcloud datastream streams update stream-mysql-to-bq \
  --project=${PROJECT} \
  --location=${REGION} \
  --state=RUNNING \
  --update-mask=state
```
