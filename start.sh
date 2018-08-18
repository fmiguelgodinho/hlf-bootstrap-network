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
cli peer channel create -o orderer0.consensus.com:7050 -c ${CHANNEL_NAME} -f ./channel-artifacts/channel.tx --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem -t 15


echo "2. Peers will start joining channel $CHANNEL_NAME"
sleep 15

# peer joins channel
for l in {a..z}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/peers/peer0.blockchain-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/users/Admin@blockchain-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=Peers${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.blockchain-${l}.com:7051" \
  cli peer channel join -b ${CHANNEL_NAME}.block
done

for l in {a..x}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/bl0ckch41n-${l}.com/peers/peer0.bl0ckch41n-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/bl0ckch41n-${l}.com/users/Admin@bl0ckch41n-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=P33rs${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.bl0ckch41n-${l}.com:7051" \
  cli peer channel join -b ${CHANNEL_NAME}.block
done

echo "3. Updating channel $CHANNEL_NAME information"
sleep 15

for l in {a..z}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/peers/peer0.blockchain-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/users/Admin@blockchain-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=Peers${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.blockchain-${l}.com:7051" \
  cli peer channel update -o orderer0.consensus.com:7050 -c ${CHANNEL_NAME} -f ./channel-artifacts/Peers${L}MSPanchors.tx --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem

  sleep 5
done
for l in {a..x}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/bl0ckch41n-${l}.com/peers/peer0.bl0ckch41n-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/bl0ckch41n-${l}.com/users/Admin@bl0ckch41n-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=P33rs${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.bl0ckch41n-${l}.com:7051" \
  cli peer channel update -o orderer0.consensus.com:7050 -c ${CHANNEL_NAME} -f ./channel-artifacts/P33rs${L}MSPanchors.tx --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem

  sleep 5
done

# chaincode deployment
export CHAINCODE_FILENAME_NOEXT=xcc
export CHAINCODE_ENDORSEMENT_POLICY="OR('PeersAMSP.member','PeersBMSP.member','PeersCMSP.member','PeersDMSP.member','PeersEMSP.member','PeersFMSP.member','PeersGMSP.member','PeersHMSP.member','PeersIMSP.member','PeersJMSP.member','PeersKMSP.member','PeersLMSP.member','PeersMMSP.member','PeersNMSP.member','PeersOMSP.member','PeersPMSP.member','PeersQMSP.member','PeersRMSP.member','PeersSMSP.member','PeersTMSP.member')"
export CHAINCODE_INSTANTIATE_ARGS='{"Args":["{\"contract-id\":\"xcc\",\"contract-version\":1,\"available-functions\":[[\"type:query\",\"fn:query\",\"arg0:key(string)\",\"arg1:viewHistory(bool)\"],[\"type:query\",\"fn:queryAll\"],[\"type:invoke\",\"fn:put\",\"arg0:key(string)\",\"arg1:value(string)\"]],\"installed-on-nodes\":[\"peer0.blockchain-a.com\",\"peer0.blockchain-b.com\",\"peer0.blockchain-c.com\",\"peer0.blockchain-d.com\",\"peer0.blockchain-e.com\",\"peer0.blockchain-f.com\",\"peer0.blockchain-g.com\",\"peer0.blockchain-h.com\",\"peer0.blockchain-i.com\",\"peer0.blockchain-j.com\",\"peer0.blockchain-k.com\",\"peer0.blockchain-l.com\",\"peer0.blockchain-m.com\",\"peer0.blockchain-n.com\",\"peer0.blockchain-o.com\",\"peer0.blockchain-p.com\",\"peer0.blockchain-q.com\",\"peer0.blockchain-r.com\",\"peer0.blockchain-s.com\",\"peer0.blockchain-t.com\"],\"channel\":\"mainchannel\",\"signature-type\":\"threshsig\",\"expires-on\":\"2019-12-31T23:59:59\",\"valid-from\":\"2018-01-01T08:00:00\",\"signing-nodes\":[{\"name\":\"peer0.blockchain-a.com\",\"host\":\"51.255.64.183\",\"port\":7051,\"event-hub-port\":7053},{\"name\":\"peer0.blockchain-b.com\",\"host\":\"51.255.64.183\",\"port\":10051,\"event-hub-port\":10053},{\"name\":\"peer0.blockchain-d.com\",\"host\":\"51.255.64.183\",\"port\":9051,\"event-hub-port\":9053},{\"name\":\"peer0.blockchain-g.com\",\"host\":\"51.255.64.183\",\"port\":13051,\"event-hub-port\":13053},{\"name\":\"peer0.blockchain-k.com\",\"host\":\"51.255.64.183\",\"port\":26051,\"event-hub-port\":26053},{\"name\":\"peer0.blockchain-o.com\",\"host\":\"51.255.64.183\",\"port\":20051,\"event-hub-port\":20053},{\"name\":\"peer0.blockchain-t.com\",\"host\":\"51.255.64.183\",\"port\":25051,\"event-hub-port\":25053}],\"consensus-type\":\"bft\",\"consensus-nodes\":[{\"name\":\"orderer0.consensus.com\",\"host\":\"51.255.64.183\",\"port\":7050},{\"name\":\"orderer1.consensus.com\",\"host\":\"51.255.64.183\",\"port\":8050},{\"name\":\"orderer2.consensus.com\",\"host\":\"51.255.64.183\",\"port\":9050},{\"name\":\"orderer3.consensus.com\",\"host\":\"51.255.64.183\",\"port\":10050}]}","{\"max-records\":100,\"total-records\":0}"]}'

echo "4. Installing chaincode $CHAINCODE_FILENAME_NOEXT on peers"

# install chaincode on peer

for l in {a..z}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/peers/peer0.blockchain-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/users/Admin@blockchain-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=Peers${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.blockchain-${l}.com:7051" \
  cli peer chaincode install -n ${CHAINCODE_FILENAME_NOEXT} -v 1.0 -p github.com/hyperledger/fabric/chaincode/go/${CHAINCODE_FILENAME_NOEXT}
done
for l in {a..x}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/bl0ckch41n-${l}.com/peers/peer0.bl0ckch41n-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/bl0ckch41n-${l}.com/users/Admin@bl0ckch41n-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=P33rs${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.bl0ckch41n-${l}.com:7051" \
  cli peer chaincode install -n ${CHAINCODE_FILENAME_NOEXT} -v 1.0 -p github.com/hyperledger/fabric/chaincode/go/${CHAINCODE_FILENAME_NOEXT}
done


echo "5. Instantiating chaincode $CHAINCODE_FILENAME_NOEXT on channel $CHANNEL_NAME"

# instantiate chain code - CHANGE ARGS AS YOU WISH
docker exec \
-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-a.com/peers/peer0.blockchain-a.com/tls/ca.crt" \
-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-a.com/users/Admin@blockchain-a.com/msp" \
-e "CORE_PEER_LOCALMSPID=PeersAMSP" \
-e "CORE_PEER_ADDRESS=peer0.blockchain-a.com:7051" \
cli peer chaincode instantiate -o orderer0.consensus.com:7050 -C ${CHANNEL_NAME} -n ${CHAINCODE_FILENAME_NOEXT} -v 1.0 -c ${CHAINCODE_INSTANTIATE_ARGS} -P ${CHAINCODE_ENDORSEMENT_POLICY} --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem

#echo "6. Invoking chaincode $CHAINCODE_FILENAME_NOEXT on channel $CHANNEL_NAME"
sleep 15

echo "6. Querying all peers to trigger chaincode for the first time!"

# query chaincode on each peer to fire up its chaincode container
for l in {a..z}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/peers/peer0.blockchain-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/blockchain-${l}.com/users/Admin@blockchain-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=Peers${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.blockchain-${l}.com:7051" \
  cli peer chaincode invoke -o orderer0.consensus.com:7050 --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem -C ${CHANNEL_NAME} -n ${CHAINCODE_FILENAME_NOEXT} -c '{"function":"getContractDefinition","Args":[""]}'
done
for l in {a..x}; do
  L=${l^^}
  docker exec \
  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/bl0ckch41n-${l}.com/peers/peer0.bl0ckch41n-${l}.com/tls/ca.crt" \
  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/bl0ckch41n-${l}.com/users/Admin@bl0ckch41n-${l}.com/msp" \
  -e "CORE_PEER_LOCALMSPID=P33rs${L}MSP" \
  -e "CORE_PEER_ADDRESS=peer0.bl0ckch41n-${l}.com:7051" \
  cli peer chaincode invoke -o orderer0.consensus.com:7050 --tls ${CORE_PEER_TLS_ENABLED} --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consensus.com/orderers/orderer0.consensus.com/msp/tlscacerts/tlsca.consensus.com-cert.pem -C ${CHANNEL_NAME} -n ${CHAINCODE_FILENAME_NOEXT} -c '{"function":"getContractDefinition","Args":[""]}'
done


echo "7. DONE!"
