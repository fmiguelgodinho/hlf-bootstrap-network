#!/bin/bash
set -e

export PATH=./bin:$GOPATH/src/github.com/hyperledger/fabric/build/bin:${PWD}/../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
CHANNEL_NAME=mainchannel

# remove previous crypto material and config transactions
rm -fr channel-artifacts/*
rm -fr crypto-config/*

# generate crypto material
cryptogen generate --config=./crypto-config.yaml
if [ "$?" -ne 0 ]; then
  echo "Failed to generate crypto material..."
  exit 1
fi

while true; do
    read -p "Going to proceed with a Kafka-based ordering service (Y to continue, N for BFTsmart)?" yn
    case $yn in
        [Yy]* ) echo "Generating Kafka-based genesis block..."; configtxgen -profile 2P1OGenesis_Kafka -channelID systemchannel -outputBlock ./channel-artifacts/genesis.block; break;;
        [Nn]* ) echo "Generating BFTsmart-based genesis block..."; configtxgen -profile 2P1OGenesis_BFTsmart -channelID systemchannel -outputBlock ./channel-artifacts/genesis.block; break;;
        * ) echo "Please answer Y or N.";;
    esac
done

if [ "$?" -ne 0 ]; then
  echo "Failed to generate orderer genesis block..."
  exit 1
fi

# generate channel configuration transaction
configtxgen -profile 2PSecureChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME
if [ "$?" -ne 0 ]; then
  echo "Failed to generate channel configuration transaction..."
  exit 1
fi

for l in {a..f}; do
  L=${l^^}
  # generate anchor peer transactions
  configtxgen -profile 2PSecureChannel -outputAnchorPeersUpdate ./channel-artifacts/Peers${L}MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Peers${L}
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate anchor peer update for Peers${L}MSP..."
    exit 1
  fi
done

# copy key and certificates in case of bft smart
# TODO:REPLACE BY SOMETHING BETTER, WE'RE REUSING CERTIFICATES :(
mkdir crypto-config/bftsmart
cp -r crypto-config/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/keystore crypto-config/bftsmart/
cd crypto-config/bftsmart/keystore
mv $(ls) key.pem
cd ../../..
cp -r crypto-config/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/signcerts crypto-config/bftsmart/
cd crypto-config/bftsmart/signcerts
mv $(ls) peer.pem


# copy key to easier name in case of users
cd ../../../crypto-config/peerOrganizations
export PEERORGS_CERTS_PATH=${PWD}

for l in {a..f}; do
  cd blockchain-${l}.com/users/User1@blockchain-${l}.com/msp/keystore
  cp $(ls) User1@blockchain-${l}.com-priv.pem

  cd ../../../Admin@blockchain-${l}.com/msp/keystore
  cp $(ls) Admin@blockchain-${l}.com-priv.pem

  cd $PEERORGS_CERTS_PATH # back to peer orgs
done
