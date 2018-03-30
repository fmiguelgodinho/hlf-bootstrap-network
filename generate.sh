#!/bin/sh
set -e

export PATH=$GOPATH/src/github.com/hyperledger/fabric/build/bin:${PWD}/../bin:${PWD}:$PATH
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
        [Yy]* ) echo "Generating Kafka-based genesis block..."; configtxgen -profile OneOrgOrdererGenesisKafka -channelID systemchannel -outputBlock ./channel-artifacts/genesis.block; break;;
        [Nn]* ) echo "Generating BFTsmart-based genesis block..."; configtxgen -profile OneOrgOrdererGenesisBFTsmart -channelID systemchannel -outputBlock ./channel-artifacts/genesis.block; break;;
        * ) echo "Please answer Y or N.";;
    esac
done

if [ "$?" -ne 0 ]; then
  echo "Failed to generate orderer genesis block..."
  exit 1
fi

# generate channel configuration transaction
configtxgen -profile OneOrgChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME
if [ "$?" -ne 0 ]; then
  echo "Failed to generate channel configuration transaction..."
  exit 1
fi

# generate anchor peer transaction
configtxgen -profile OneOrgChannel -outputAnchorPeersUpdate ./channel-artifacts/PeersMSPanchors.tx -channelID $CHANNEL_NAME -asOrg Peers
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org1MSP..."
  exit 1
fi

#copy key and certificates in case of bft smart
# TODO:REPLACE BY SOMETHING BETTER, WE'RE REUSING CERTIFICATES :(
mkdir crypto-config/bftsmart
cp -r crypto-config/ordererOrganizations/fgodinho.com/orderers/orderer0.fgodinho.com/msp/keystore crypto-config/bftsmart/
cd crypto-config/bftsmart/keystore
mv $(ls) key.pem
cd ../../..
cp -r crypto-config/ordererOrganizations/fgodinho.com/orderers/orderer0.fgodinho.com/msp/signcerts crypto-config/bftsmart/
cd crypto-config/bftsmart/signcerts
mv $(ls) peer.pem
