#!/bin/bash
set -e

# fully reboot docker containers and network, removing volumes
while true; do
    read -p "What do you want to run (Y for Kafka HLF, N for BFTsmart HLF)?" yn
    case $yn in
        [Yy]* ) docker-compose -f docker-compose.yaml -f docker-compose-couch.yaml -f docker-compose-kafka.yaml down; docker volume prune -f; docker-compose -f docker-compose.yaml -f docker-compose-couch.yaml -f docker-compose-kafka.yaml up -d; break;;
        [Nn]* ) docker-compose -f docker-compose.yaml -f docker-compose-couch.yaml -f docker-compose-bftsmart.yaml down; docker volume prune -f; docker-compose -f docker-compose.yaml -f docker-compose-couch.yaml -f docker-compose-bftsmart.yaml up -d; break;;
        * ) echo "Please answer Y or N.";;
    esac
done

# wait for Hyperledger Fabric to start
export FABRIC_START_TIMEOUT=50
sleep ${FABRIC_START_TIMEOUT}

# export environment variables for docker network
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/users/Admin@fgodinho.com/msp
export CORE_PEER_ADDRESS=peer0.fgodinho.com:7051
export CORE_PEER_LOCALMSPID="PeersMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/peers/peer0.fgodinho.com/tls/ca.crt
export CHANNEL_NAME=mainchannel
export CORE_PEER_TLS_ENABLED=true

echo "1. Creating channel $CHANNEL_NAME"

# Create the channel
docker exec \
-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/peers/peer0.fgodinho.com/tls/ca.crt" \
-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/users/Admin@fgodinho.com/msp" \
-e "CORE_PEER_LOCALMSPID=PeersMSP" \
-e "CORE_PEER_ADDRESS=peer0.fgodinho.com:7051" \
cli peer channel create -o orderer0.consensus.com:7050 -c ${CHANNEL_NAME} -f ./channel-artifacts/channel.tx --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem -t 30


echo "2. Peers will start joining channel $CHANNEL_NAME"
sleep 15

# peer joins channel
for ((i=0; i<=5; i++)); do
    docker exec \
    -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/peers/peer$i.fgodinho.com/tls/ca.crt" \
    -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/users/Admin@fgodinho.com/msp" \
    -e "CORE_PEER_LOCALMSPID=PeersMSP" \
    -e "CORE_PEER_ADDRESS=peer$i.fgodinho.com:7051" \
    cli peer channel join -b ${CHANNEL_NAME}.block

done

echo "3. Updating channel $CHANNEL_NAME information"
sleep 15

docker exec \
-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/peers/peer0.fgodinho.com/tls/ca.crt" \
-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/fgodinho.com/users/Admin@fgodinho.com/msp" \
-e "CORE_PEER_LOCALMSPID=PeersMSP" \
-e "CORE_PEER_ADDRESS=peer0.fgodinho.com:7051" \
cli peer channel update -o orderer0.consensus.com:7050 -c ${CHANNEL_NAME} -f ./channel-artifacts/PeersMSPanchors.tx --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem


# chaincode deployment
export CHAINCODE_FILENAME_NOEXT=econtract

echo "4. Installing chaincode $CHAINCODE_FILENAME_NOEXT on peers"

# install chaincode on peer
for ((i=0; i<=5; i++)); do
  docker exec \
  -e "CORE_PEER_ADDRESS=peer$i.fgodinho.com:7051" \
  cli peer chaincode install -n ${CHAINCODE_FILENAME_NOEXT} -v 1.0 -p github.com/hyperledger/fabric/chaincode/go/${CHAINCODE_FILENAME_NOEXT}
done

echo "5. Instantiating chaincode $CHAINCODE_FILENAME_NOEXT on channel $CHANNEL_NAME"

# instantiate chain code - CHANGE ARGS AS YOU WISH
docker exec \
-e "CORE_PEER_ADDRESS=peer0.fgodinho.com:7051" \
cli peer chaincode instantiate -o orderer0.consensus.com:7050 -C ${CHANNEL_NAME} -n ${CHAINCODE_FILENAME_NOEXT} -v 1.0 -c '{"Args":[""]}' -P "OR ('PeersMSP.member','PeersMSP.member')" --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem

echo "6. Invoking chaincode $CHAINCODE_FILENAME_NOEXT on channel $CHANNEL_NAME"
sleep 30

# invoke ledger initiation
docker exec \
-e "CORE_PEER_ADDRESS=peer0.fgodinho.com:7051" \
cli peer chaincode invoke -o orderer0.consensus.com:7050 --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem -C ${CHANNEL_NAME} -n ${CHAINCODE_FILENAME_NOEXT} -c '{"function":"initLedger","Args":[""]}'

echo "7. DONE!"
