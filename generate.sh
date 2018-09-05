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

configtxgen -profile 2P1OGenesis_Solo -channelID systemchannel -outputBlock ./channel-artifacts/genesis.block


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

# generate anchor peer transactions
configtxgen -profile 2PSecureChannel -outputAnchorPeersUpdate ./channel-artifacts/PeersAMSPanchors.tx -channelID $CHANNEL_NAME -asOrg PeersA
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for PeersAMSP..."
  exit 1
fi


# copy key to easier name in case of users
cd crypto-config/peerOrganizations
export PEERORGS_CERTS_PATH=${PWD}

cd blockchain-a.com/users/User1@blockchain-a.com/msp/keystore
cp $(ls) User1@blockchain-a.com-priv.pem

cd ../../../Admin@blockchain-a.com/msp/keystore
cp $(ls) Admin@blockchain-a.com-priv.pem

cd $PEERORGS_CERTS_PATH # back to peer orgs
