#!/bin/bash
set -ev

# fully reboot docker containers and network, removing volumes
docker-compose -f docker-compose-cli.yaml -f docker-compose-couch.yaml -f docker-compose-kafka.yaml down

docker volume prune -f

docker-compose -f docker-compose-cli.yaml -f docker-compose-couch.yaml -f docker-compose-kafka.yaml up -d

# wait for Hyperledger Fabric to start
export FABRIC_START_TIMEOUT=120
sleep ${FABRIC_START_TIMEOUT}

# export environment variables for docker network
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/users/Admin@fgodinho.com/msp
export CORE_PEER_ADDRESS=peer0.fgodinho.com:7051
export CORE_PEER_LOCALMSPID="PeersMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/peers/peer0.fgodinho.com/tls/ca.crt
export CHANNEL_NAME=mainchannel
export CORE_PEER_TLS_ENABLED=true

# Create the channel
docker exec \
-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/peers/peer0.fgodinho.com/tls/ca.crt" \
-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/users/Admin@fgodinho.com/msp" \
-e "CORE_PEER_LOCALMSPID=PeersMSP" \
-e "CORE_PEER_ADDRESS=peer0.fgodinho.com:7051" \
cli peer channel create -o orderer0.fgodinho.com:7050 -c ${CHANNEL_NAME} -f ./channel-artifacts/channel.tx --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fgodinho.com/orderers/orderer0.fgodinho.com/msp/tlscacerts/tlsca.fgodinho.com-cert.pem -t 30

# peer joins channel
for ((i=0; i<=5; i++)); do
    docker exec \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/peers/peer0.fgodinho.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/users/Admin@fgodinho.com/msp" \
    -e "CORE_PEER_LOCALMSPID=PeersMSP" \
    -e "CORE_PEER_ADDRESS=peer$i.fgodinho.com:7051" \
    cli peer channel join -b ${CHANNEL_NAME}.block
done

# chaincode deployment
export CHAINCODE_FILENAME_NOEXT=econtract

# install chaincode on peer
for ((i=0; i<=5; i++)); do
  docker exec \
  -e "CORE_PEER_ADDRESS=peer$i.fgodinho.com:7051" \
  cli peer chaincode install -n ${CHAINCODE_FILENAME_NOEXT} -v 1.0 -p github.com/hyperledger/fabric/chaincode/go/${CHAINCODE_FILENAME_NOEXT}
done

# instantiate chain code - CHANGE ARGS AS YOU WISH
docker exec \
-e "CORE_PEER_ADDRESS=peer0.fgodinho.com:7051" \
cli peer chaincode instantiate -o orderer0.fgodinho.com:7050 --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fgodinho.com/orderers/orderer0.fgodinho.com/msp/tlscacerts/tlsca.fgodinho.com-cert.pem -C ${CHANNEL_NAME} \
-n ${CHAINCODE_FILENAME_NOEXT} -v 1.0 -c '{"Args":[""]}' -P "OR ('OrderersMSP.member','PeersMSP.member')"

sleep 15

# invoke ledger initiation
docker exec \
-e "CORE_PEER_ADDRESS=peer0.fgodinho.com:7051" \
cli peer chaincode invoke -o orderer0.fgodinho.com:7050 --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/fgodinho.com/orderers/orderer0.fgodinho.com/msp/tlscacerts/tlsca.fgodinho.com-cert.pem -C ${CHANNEL_NAME} -n ${CHAINCODE_FILENAME_NOEXT} -c '{"function":"initLedger","Args":[""]}'
