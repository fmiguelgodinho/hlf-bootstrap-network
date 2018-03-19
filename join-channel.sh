#!/bin/bash
# Copyright London Stock Exchange Group All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#set -e
#export CHANNEL_NAME=main_channel

#peer channel create -o orderer.blockchain.fgodinho.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/blockchain.fgodinho.com/orderers/orderer.blockchain.fgodinho.com/msp/tlscacerts/tlsca.blockchain.fgodinho.com-cert.pem


# now we will join the channel and start the chain with myc.block serving as the
# channel's first block (i.e. the genesis block)
#peer channel join -b ./channel-artifacts/genesis.block

# Now the user can proceed to build and start chaincode in one terminal
# And leverage the CLI container to issue install instantiate invoke query commands in another

#we should have bailed if above commands failed.
#we are here, so they worked
#sleep 600000
exit 0
