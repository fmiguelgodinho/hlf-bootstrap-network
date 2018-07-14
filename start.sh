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
export FABRIC_START_TIMEOUT=60
sleep ${FABRIC_START_TIMEOUT}

# export environment variables for docker network
export CHANNEL_NAME=mainchannel
export CORE_PEER_TLS_ENABLED=true

echo "1. Creating channel $CHANNEL_NAME"

# Create the channel
docker exec \
-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-a.com/peers/peer0.blockchain-a.com/tls/ca.crt" \
-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-a.com/users/Admin@blockchain-a.com/msp" \
-e "CORE_PEER_LOCALMSPID=PeersAMSP" \
-e "CORE_PEER_ADDRESS=peer0.blockchain-a.com:7051" \
cli peer channel create -o orderer0.consensus.com:7050 -c ${CHANNEL_NAME} -f ./channel-artifacts/channel.tx --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem -t 30


echo "2. Peers will start joining channel $CHANNEL_NAME"
sleep 15

# peer joins channel
for l in {a..f}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/peers/peer0.blockchain-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/users/Admin@blockchain-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=Peers${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.blockchain-${l}.com:7051" \
  cli peer channel join -b ${CHANNEL_NAME}.block
done

echo "3. Updating channel $CHANNEL_NAME information"
sleep 15

for l in {a..f}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/peers/peer0.blockchain-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/users/Admin@blockchain-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=Peers${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.blockchain-${l}.com:7051" \
  cli peer channel update -o orderer0.consensus.com:7050 -c ${CHANNEL_NAME} -f ./channel-artifacts/Peers${L}MSPanchors.tx --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem

  sleep 15
done

# chaincode deployment
export CHAINCODE_FILENAME_NOEXT=xcc
export CHAINCODE_INSTANTIATE_ARGS='{"Args":["{\"contract-id\":\"xcc\",\"contract-version\":1,\"available-functions\":[[\"type:query\",\"fn:query\",\"arg0:key(string)\",\"arg1:viewHistory(bool)\"],[\"type:query\",\"fn:queryAll\"],[\"type:invoke\",\"fn:put\",\"arg0:key(string)\",\"arg1:value(string)\"]],\"installed-on-nodes\":[\"peer0.blockchain-a.com\",\"peer0.blockchain-b.com\",\"peer0.blockchain-c.com\",\"peer0.blockchain-d.com\",\"peer0.blockchain-e.com\",\"peer0.blockchain-f.com\"],\"channel\":\"mainchannel\",\"signature-type\":\"threshsig\",\"expires-on\":\"2018-12-31T23:59:59\",\"signing-nodes\":[\"peer0.blockchain-a.com\",\"peer0.blockchain-b.com\",\"peer0.blockchain-c.com\",\"peer0.blockchain-d.com\",\"peer0.blockchain-e.com\",\"peer0.blockchain-f.com\"],\"consensus-type\":\"bft\",\"consensus-nodes\":[\"orderer0.consensus.com\",\"orderer1.consensus.com\"]}","{\"max-records\":100,\"total-records\":0}"]}'

echo "4. Installing chaincode $CHAINCODE_FILENAME_NOEXT on peers"

# install chaincode on peer
for l in {a..f}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/peers/peer0.blockchain-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/users/Admin@blockchain-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=Peers${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.blockchain-${l}.com:7051" \
  cli peer chaincode install -n ${CHAINCODE_FILENAME_NOEXT} -v 1.0 -p github.com/hyperledger/fabric/chaincode/go/${CHAINCODE_FILENAME_NOEXT}
done

echo "5. Instantiating chaincode $CHAINCODE_FILENAME_NOEXT on channel $CHANNEL_NAME"

# instantiate chain code - CHANGE ARGS AS YOU WISH
docker exec \
-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-a.com/peers/peer0.blockchain-a.com/tls/ca.crt" \
-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-a.com/users/Admin@blockchain-a.com/msp" \
-e "CORE_PEER_LOCALMSPID=PeersAMSP" \
-e "CORE_PEER_ADDRESS=peer0.blockchain-a.com:7051" \
cli peer chaincode instantiate -o orderer0.consensus.com:7050 -C ${CHANNEL_NAME} -n ${CHAINCODE_FILENAME_NOEXT} -v 1.0 -c ${CHAINCODE_INSTANTIATE_ARGS} -P "AND('PeersAMSP.member','PeersBMSP.member','PeersCMSP.member','PeersDMSP.member','PeersEMSP.member','PeersFMSP.member')" --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem

#echo "6. Invoking chaincode $CHAINCODE_FILENAME_NOEXT on channel $CHANNEL_NAME"
sleep 30

# invoke ledger initiation
##docker exec \
#-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-a.com/peers/peer0.blockchain-a.com/tls/ca.crt" \
#-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-a.com/users/Admin@blockchain-a.com/msp" \
#-e "CORE_PEER_LOCALMSPID=PeersAMSP" \
#-e "CORE_PEER_ADDRESS=peer0.blockchain-a.com:7051" \
#cli peer chaincode invoke -o orderer0.consensus.com:7050 --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem -C ${CHANNEL_NAME} -n ${CHAINCODE_FILENAME_NOEXT} -c '{"function":"initLedger","Args":[""]}'

echo "6. DONE!"
