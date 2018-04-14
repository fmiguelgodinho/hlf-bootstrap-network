
import org.apache.log4j.Logger;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.hyperledger.fabric.sdk.ChaincodeID;
import org.hyperledger.fabric.sdk.Channel;
import org.hyperledger.fabric.sdk.Enrollment;
import org.hyperledger.fabric.sdk.EventHub;
import org.hyperledger.fabric.sdk.HFClient;
import org.hyperledger.fabric.sdk.Orderer;
import org.hyperledger.fabric.sdk.Peer;
import org.hyperledger.fabric.sdk.ProposalResponse;
import org.hyperledger.fabric.sdk.QueryByChaincodeRequest;
import org.hyperledger.fabric.sdk.TransactionProposalRequest;
import org.hyperledger.fabric.sdk.exception.CryptoException;
import org.hyperledger.fabric.sdk.exception.InvalidArgumentException;
import org.hyperledger.fabric.sdk.exception.ProposalException;
import org.hyperledger.fabric.sdk.exception.TransactionException;
import org.hyperledger.fabric.sdk.security.CryptoSuite;
import org.hyperledger.fabric_ca.sdk.HFCAClient;
import org.hyperledger.fabric_ca.sdk.RegistrationRequest;

import java.io.File;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.Security;
import java.util.Collection;
import java.util.Properties;

/**
 * <h1>HFJavaSDKBasicExample</h1>
 * <p>
 * Simple example showcasing basic fabric-ca and fabric actions.
 * The demo required fabcar fabric up and running.
 * <p>
 * The demo shows
 * <ul>
 * <li>connecting to fabric-ca</li>
 * <li>enrolling admin to get new key-pair, certificate</li>
 * <li>registering and enrolling a new user using admin</li>
 * <li>creating HF client and initializing channel</li>
 * <li>invoking chaincode query</li>
 * </ul>
 *
 * @author lkolisko
 */
public class HLFJavaClient {

	public static final String HLF_USER_NAME = "User1@blockchain-a.com";
	public static final String HLF_CLIENT_ORG = "PeersA";
	public static final String HLF_CLIENT_MSPID = "PeersAMSP";
	public static final String HLF_CLIENT_CRT_PATH = "../../crypto-config/peerOrganizations/blockchain-a.com/users/User1@blockchain-a.com/msp/signcerts/User1@blockchain-a.com-cert.pem";
	public static final String HLF_CLIENT_KEY_PATH = "../../crypto-config/peerOrganizations/blockchain-a.com/users/User1@blockchain-a.com/msp/keystore/User1@blockchain-a.com-priv.pem";
	public static final String HLF_CHANNEL_NAME = "mainchannel";
	public static final String HLF_CHAINCODE_NAME = "econtract";
	
    private static final Logger log = Logger.getLogger(HLFJavaClient.class);


    public static void main(String[] args) throws Exception {
    	
    	Security.addProvider(new BouncyCastleProvider());
    	
        // create fabric-ca client
//      HFCAClient caClient = getHfCaClient("http://localhost:7054", null);

        // enroll or load admin
//      AppUser admin = getAdmin(caClient);
//      log.info(admin);

        // register and enroll new user
        AppUser appUser = getUser(HLF_CLIENT_CRT_PATH, HLF_CLIENT_KEY_PATH, HLF_USER_NAME);
        log.info(appUser);

        // get HFC client instance
        HFClient client = getHfClient();
        // set user context
        client.setUserContext(appUser);

        // get HFC channel using the client
        Channel channel = getChannel(client);
        log.info("Channel: " + channel.getName());
        
        // call invoke
        addProperty(client, new String[] {"PROPERTY1", "doge", "Example of a marvelous doge", "nil", "shock and awe", "20"});
        
        // wait a few secs...
        Thread.sleep(10000);

        // call query blockchain
        queryAll(client);
    }


    /**
     * Invoke blockchain query
     *
     * @param client The HF Client
     * @throws ProposalException
     * @throws InvalidArgumentException
     */
    static void queryAll(HFClient client) throws ProposalException, InvalidArgumentException {
        // get channel instance from client
        Channel channel = client.getChannel(HLF_CHANNEL_NAME);
        // create chaincode request
        QueryByChaincodeRequest qpr = client.newQueryProposalRequest();
        // build cc id providing the chaincode name. Version is omitted here.
        ChaincodeID CCId = ChaincodeID.newBuilder().setName(HLF_CHAINCODE_NAME).build();
        qpr.setChaincodeID(CCId);
        // CC function to be called
        qpr.setFcn("queryAll");
        Collection<ProposalResponse> res = channel.queryByChaincode(qpr);
        
        System.out.println("Sending query request, function 'queryAll', through chaincode '" + HLF_CHAINCODE_NAME + "'...");
        
        // display response
        for (ProposalResponse pres : res) {
            String stringResponse = new String(pres.getChaincodeActionResponsePayload());
            log.info(stringResponse);
            System.out.println(stringResponse);
        }

    }
    
    static void addProperty(HFClient client, String[] property) throws ProposalException, InvalidArgumentException {
        // get channel instance from client
        Channel channel = client.getChannel(HLF_CHANNEL_NAME);
        // create chaincode request
        TransactionProposalRequest tpr = client.newTransactionProposalRequest();
        // build cc id providing the chaincode name. Version is omitted here.
        ChaincodeID CCId = ChaincodeID.newBuilder().setName(HLF_CHAINCODE_NAME).build();
        tpr.setChaincodeID(CCId);
        // CC function to be called
        tpr.setFcn("addProperty");
        tpr.setArgs(property);
        
        System.out.println("Sending transaction proposal, function 'addProperty', through chaincode '" + HLF_CHAINCODE_NAME + "'...");

        Collection<ProposalResponse> res = channel.sendTransactionProposal(tpr);
        // display response
        for (ProposalResponse pres : res) {
            String stringResponse = "Response from endorser is: " + pres.getChaincodeActionResponseStatus();
            log.info(stringResponse);
            System.out.println(stringResponse);
        }
        
        System.out.println("Collecting endorsements and sending transaction...");

        // send transaction with endorsements
        channel.sendTransaction(res);
        System.out.println("Transaction sent.");
    }


    /**
     * Initialize and get HF channel
     *
     * @param client The HFC client
     * @return Initialized channel
     * @throws InvalidArgumentException
     * @throws TransactionException
     */
    static Channel getChannel(HFClient client) throws InvalidArgumentException, TransactionException {
        
        File tlsACrt = Paths.get("../../crypto-config/peerOrganizations/blockchain-a.com/tlsca", "tlsca.blockchain-a.com-cert.pem").toFile();
        File tlsBCrt = Paths.get("../../crypto-config/peerOrganizations/blockchain-b.com/tlsca", "tlsca.blockchain-b.com-cert.pem").toFile();
        File tlsOrdCrt = Paths.get("../../crypto-config/ordererOrganizations/consensus.com/tlsca", "tlsca.consensus.com-cert.pem").toFile();
        
    	
        if (!tlsACrt.exists() || !tlsBCrt.exists() || !tlsOrdCrt.exists())
        	throw new RuntimeException("Missing TLS cert files");
        
        Properties secPeerAProperties = new Properties();
        secPeerAProperties.setProperty("hostnameOverride", "peer0.blockchain-a.com");
        secPeerAProperties.setProperty("sslProvider", "openSSL");
        secPeerAProperties.setProperty("negotiationType", "TLS");
        secPeerAProperties.setProperty("pemFile", tlsACrt.getAbsolutePath());
        
        Properties secPeerBProperties = new Properties();
        secPeerBProperties.setProperty("hostnameOverride", "peer0.blockchain-b.com");
        secPeerBProperties.setProperty("sslProvider", "openSSL");
        secPeerBProperties.setProperty("negotiationType", "TLS");
        secPeerBProperties.setProperty("pemFile", tlsBCrt.getAbsolutePath());
        
        Properties secOrdererProperties = new Properties();
        secOrdererProperties.setProperty("hostnameOverride", "orderer0.consensus.com");
        secOrdererProperties.setProperty("sslProvider", "openSSL");
        secOrdererProperties.setProperty("negotiationType", "TLS");
        secOrdererProperties.setProperty("pemFile", tlsOrdCrt.getAbsolutePath());
    	
    	// initialize channel
        // peer name and endpoint in fabcar network
        Peer peerA = client.newPeer("peer0.blockchain-a.com", "grpcs://localhost:7051", secPeerAProperties);
        Peer peerB = client.newPeer("peer0.blockchain-b.com", "grpcs://localhost:10051", secPeerBProperties);
        // eventhub name and endpoint in fabcar network
        EventHub eventHub = client.newEventHub("eventhub01", "grpcs://localhost:7053", secPeerAProperties);
        // orderer name and endpoint in fabcar network
        Orderer orderer = client.newOrderer("orderer0.consensus.com", "grpcs://localhost:7050", secOrdererProperties);
        
        
        Channel channel = client.newChannel(HLF_CHANNEL_NAME);
        channel.addPeer(peerA);
        channel.addPeer(peerB);
        channel.addEventHub(eventHub);
        channel.addOrderer(orderer);
        channel.initialize();
        
        return channel;
    }

    /**
     * Create new HLF client
     *
     * @return new HLF client instance. Never null.
     * @throws CryptoException
     * @throws InvalidArgumentException
     */
    static HFClient getHfClient() throws Exception {
        // initialize default cryptosuite
        CryptoSuite cryptoSuite = CryptoSuite.Factory.getCryptoSuite();
        // setup the client
        HFClient client = HFClient.createNewInstance();
        client.setCryptoSuite(cryptoSuite);
        return client;
    }


    /**
     * Register and enroll user with userId.
     * If AppUser object with the name already exist on fs it will be loaded and
     * registration and enrollment will be skipped.
     *
     * @param caClient  The fabric-ca client.
     * @param registrar The registrar to be used.
     * @param userId    The user id.
     * @return AppUser instance with userId, affiliation,mspId and enrollment set.
     * @throws Exception
     */
    static AppUser getUser(String certPath, String keyPath, String userId) throws Exception {
        AppUser appUser = null;//tryDeserialize(userId);
        if (appUser == null) {
            //String enrollmentSecret = caClient.register(rr, registrar);
            //Enrollment enrollment = caClient.enroll(userId, enrollmentSecret);
            appUser = new AppUser(userId, HLF_CLIENT_ORG, HLF_CLIENT_MSPID, certPath, keyPath);
            //serialize(appUser);
        }
        return appUser;
    }

    /**
     * Enroll admin into fabric-ca using {@code admin/adminpw} credentials.
     * If AppUser object already exist serialized on fs it will be loaded and
     * new enrollment will not be executed.
     *
     * @param caClient The fabric-ca client
     * @return AppUser instance with userid, affiliation, mspId and enrollment set
     * @throws Exception
     */
//    static AppUser getAdmin(HFCAClient caClient) throws Exception {
//        AppUser admin = tryDeserialize("admin");
//        if (admin == null) {
//            Enrollment adminEnrollment = caClient.enroll("admin", "adminpw");
//            admin = new AppUser("admin", "org1", "Org1MSP", adminEnrollment);
//            serialize(admin);
//        }
//        return admin;
//    }

    /**
     * Get new fabic-ca client
     *
     * @param caUrl              The fabric-ca-server endpoint url
     * @param caClientProperties The fabri-ca client properties. Can be null.
     * @return new client instance. never null.
     * @throws Exception
     */
//    static HFCAClient getHfCaClient(String caUrl, Properties caClientProperties) throws Exception {
//        CryptoSuite cryptoSuite = CryptoSuite.Factory.getCryptoSuite();
//        HFCAClient caClient = HFCAClient.createNewInstance(caUrl, caClientProperties);
//        caClient.setCryptoSuite(cryptoSuite);
//        return caClient;
//    }


    // user serialization and deserialization utility functions
    // files are stored in the base directory

    /**
     * Serialize AppUser object to file
     *
     * @param appUser The object to be serialized
     * @throws IOException
     */
    static void serialize(AppUser appUser) throws IOException {
        try (ObjectOutputStream oos = new ObjectOutputStream(Files.newOutputStream(
                Paths.get(appUser.getName() + ".jso")))) {
            oos.writeObject(appUser);
        }
    }

    /**
     * Deserialize AppUser object from file
     *
     * @param name The name of the user. Used to build file name ${name}.jso
     * @return
     * @throws Exception
     */
    static AppUser tryDeserialize(String name) throws Exception {
        if (Files.exists(Paths.get(name + ".jso"))) {
            return deserialize(name);
        }
        return null;
    }

    static AppUser deserialize(String name) throws Exception {
        try (ObjectInputStream decoder = new ObjectInputStream(
                Files.newInputStream(Paths.get(name + ".jso")))) {
            return (AppUser) decoder.readObject();
        }
    }
}