'use strict';
/*
* Copyright IBM Corp All Rights Reserved
*
* SPDX-License-Identifier: Apache-2.0
*/
/*
 * Chaincode query
 */

var Fabric_Client = require('fabric-client');
var path = require('path');
var util = require('util');
var os = require('os');
var fs = require('fs');

//
var fabric_client = new Fabric_Client();

// setup the fabric network
var channel = fabric_client.newChannel('mainchannel');
var peer = fabric_client.newPeer('grpcs://localhost:7051', {
	pem: fs.readFileSync('../../crypto-config/peerOrganizations/blockchain-a.com/tlsca/tlsca.blockchain-a.com-cert.pem').toString(),
	'ssl-target-name-override': 'peer0.blockchain-a.com'
});
channel.addPeer(peer);

//
var member_user = null;
var store_path = path.join(__dirname, '.hfc-keystore');
console.log('Store path:'+store_path);
var tx_id = null;

// create the key value store as defined in the fabric-client/config/default.json 'key-value-store' setting
Fabric_Client.newDefaultKeyValueStore({ path: store_path
}).then((state_store) => {
	// assign the store to the fabric client
	fabric_client.setStateStore(state_store);
	var crypto_suite = Fabric_Client.newCryptoSuite();
	// use the same location for the state store (where the users' certificate are kept)
	// and the crypto store (where the users' keys are kept)
	var crypto_store = Fabric_Client.newCryptoKeyStore({path: store_path});
	crypto_suite.setCryptoKeyStore(crypto_store);
	fabric_client.setCryptoSuite(crypto_suite);

	var privKey = fs.readFileSync('../../crypto-config/peerOrganizations/blockchain-a.com/users/User1@blockchain-a.com/msp/keystore/User1@blockchain-a.com-priv.pem').toString();
	var signCrt = fs.readFileSync('../../crypto-config/peerOrganizations/blockchain-a.com/users/User1@blockchain-a.com/msp/signcerts/User1@blockchain-a.com-cert.pem').toString();

	// get the enrolled user from persistence, this user will sign all requests
	return fabric_client.createUser({
		username: 'User1@blockchain-a.com',
		mspid: 'PeersAMSP',
		cryptoContent: {
			privateKeyPEM: privKey,
			signedCertPEM: signCrt
		}
	});
}).then((new_user) => {
	member_user = new_user;
	return fabric_client.setUserContext(member_user);
}).then((user_contextset) => {
	console.log('Successfully set context');

	const request = {
		//targets : --- letting this default to the peers assigned to the channel
		chaincodeId: 'xcc',
		fcn: 'getContractDefinition', //query //queryAll
		args: []//['280f06d6-2c1d-48fc-a5ba-3bfacc42ba08', 'true']
	};

	// send the query proposal to the peer
	return channel.queryByChaincode(request);
}).then((query_responses) => {
	console.log("Query has completed, checking results");
	// query_responses could have more than one  results if there multiple peers were used as targets
	if (query_responses && query_responses.length == 1) {
		if (query_responses[0] instanceof Error) {
			console.error("error from query = ", query_responses[0]);
		} else {
			console.log("Response is ", query_responses[0].toString());
		}
	} else {
		console.log("No payloads were returned from query");
	}
}).catch((err) => {
	console.error('Failed to query successfully :: ' + err);
});
