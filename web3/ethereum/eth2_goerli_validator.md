# Running Ethereum Goerli Validator on Google Cloud (debian)
- [Running Ethereum Goerli Validator on Google Cloud (debian)](#running-ethereum-goerli-validator-on-google-cloud-debian)
  - [Request approval for staking 0.0001 GoETH to become a validator](#request-approval-for-staking-00001-goeth-to-become-a-validator)
  - [Deploy Virtual Machine](#deploy-virtual-machine)
  - [Consensus layer](#consensus-layer)
    - [Install prysm](#install-prysm)
    - [Generate jwt](#generate-jwt)
    - [Run prysm](#run-prysm)
  - [Execution Layer](#execution-layer)
    - [Install geth from binary](#install-geth-from-binary)
  - [Run geth](#run-geth)
  - [Validator](#validator)
    - [Install staking deposit cli](#install-staking-deposit-cli)
    - [Generate key pair](#generate-key-pair)
  - [Import key to consensus](#import-key-to-consensus)
  - [Deposit 0.0001 GoETH](#deposit-00001-goeth)
  - [Run validator](#run-validator)

## Request approval for staking 0.0001 GoETH to become a validator
32 ETH is required to become a validator. However, requesting faucet on goerli testnet is time consuming (usually takes weeks to reach 32 ETH). There is a shortcut to become a validator with 0.0001 GoETH. Follow the guide below:
- Join discord server: https://discord.gg/MbBCmGPg
- Go to #cheap-goerli-validator
- Run command /cheap-goerli-deposit and follow the instructions to sign a message and whitelist your address

## Deploy Virtual Machine
`<TBD>`

## Consensus layer
### Install prysm
```shell
mkdir -p /data/consensus/prysm /data/execution /data/validator
cd /data/consensus/prysm
curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output prysm.sh && chmod +x prysm.sh
```

### Generate jwt
```shell
./prysm.sh beacon-chain generate-auth-secret
```

### Run prysm
Afther THE MERGE, concensus layer must be fully synced before execution layer can begin to sync. We use checkpoint for fast sync.
```shell
./prysm.sh beacon-chain \
--datadir /data/consensus/prysm/data \
--execution-endpoint=http://localhost:8551 \
--prater \
--jwt-secret=/data/jwt.hex \
--suggested-fee-recipient=0xc68398414F161a481c3A1e1Dca84618D505A78d6 \
--checkpoint-sync-url=https://goerli.checkpoint-sync.ethpandaops.io \
--genesis-beacon-api-url=https://goerli.checkpoint-sync.ethpandaops.io
```

## Execution Layer
### Install geth from binary
```shell
bin=geth-alltools-linux-amd64-1.10.24-972007a5
wget https://gethstore.blob.core.windows.net/builds/${bin}.tar.gz -P /data/execution
tar -zxvf ${bin}.tar.gz
mv ${bin} bin
```

## Run geth
```shell
bin/geth --goerli --datadir /data/execution --http --http.api eth,net,engine,admin --authrpc.jwtsecret /data/jwt.hex
```

## Validator
### Install staking deposit cli
```shell
wget https://github.com/ethereum/staking-deposit-cli/releases/download/v2.3.0/staking_deposit-cli-76ed782-linux-amd64.tar.gz -P /data/ethereum/validator
cd /data/ethereum/validator
tar -zxvf staking_deposit-cli-76ed782-linux-amd64.tar.gz
```

### Generate key pair
```shell
staking_deposit-cli-76ed782-linux-amd64/deposit new-mnemonic --num_validators=1 --mnemonic_language=english --chain=prater
```

Enter a password to secure validator keystore and Make sure to **write down you mnemonic offline and store it safely**.

## Import key to consensus
```shell
cd /data/ethereum/consensus/prysm
./prysm.sh validator accounts import --keys-dir=/data/validator/validator_keys --prater
```

Enter wallet directory: /data/consensus
Wallet password: 
Successfully imported 1 accounts, view all of them by running accounts list


## Deposit 0.0001 GoETH
- Go to https://goerli.launchpad.ethstaker.cc/en/
- Copy the `deposit_data-<timestamp>.json` from VM to your local machine
- Upload your `deposit_data-<timestamp>.json`
- Connect metamask
**Make sure the account is what you applied in discord ethstaker**
- Follow the instructions to deposit 0.0001 GoETH

## Run validator
```shell
./prysm.sh validator --wallet-dir=/data/consensus --prater
```

If you see the validator shows a message like:
Waiting for deposit to be observed by beacon node pubKey=0xa00d1471085b status=UNKNOWN_STATU

That means your execution layer is far behind the latest block. Wait until the execution layer is fully synced.
It usually takes 1 week for your validator to be activated. Check the goerli explorer for your validator status: https://goerli.beaconcha.in/validator/<validator_pubkey>#deposits
