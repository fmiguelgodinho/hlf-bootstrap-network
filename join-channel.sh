#!/bin/bash
# Copyright London Stock Exchange Group All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
set -e

export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain.fgodinho.com/users/Admin@blockchain.fgodinho.com/msp
export CORE_PEER_ADDRESS=peer0.blockchain.fgodinho.com:7051
export CORE_PEER_LOCALMSPID="PeersMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain.fgodinho.com/peers/peer0.blockchain.fgodinho.com/tls/ca.crt
export CHANNEL_NAME=mainchannel

peer channel create -o orderer.consensus.fgodinho.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.fgodinho.com/orderers/orderer.consensus.fgodinho.com/msp/tlscacerts/tlsca.consensus.fgodinho.com-cert.pem


# now we will join the channel and start the chain with myc.block serving as the
# channel's first block (i.e. the genesis block)

peer channel join -b mainchannel.block

export CORE_PEER_ADDRESS=peer1.blockchain.fgodinho.com:7051
peer channel join -b mainchannel.block

export CORE_PEER_ADDRESS=peer2.blockchain.fgodinho.com:7051
peer channel join -b mainchannel.block

export CORE_PEER_ADDRESS=peer3.blockchain.fgodinho.com:7051
peer channel join -b mainchannel.block

export CORE_PEER_ADDRESS=peer4.blockchain.fgodinho.com:7051
peer channel join -b mainchannel.block

export CORE_PEER_ADDRESS=peer5.blockchain.fgodinho.com:7051
peer channel join -b mainchannel.block


# Now the user can proceed to build and start chaincode in one terminal
# And leverage the CLI container to issue install instantiate invoke query commands in another

#we should have bailed if above commands failed.
#we are here, so they worked
#sleep 600000
exit 0
