import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Security;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Collection;
import java.util.Date;
import java.util.HashSet;
import java.util.Properties;
import java.util.Random;
import java.util.Set;

import javax.xml.bind.DatatypeConverter;

import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.hyperledger.fabric.sdk.ChaincodeID;
import org.hyperledger.fabric.sdk.Channel;
import org.hyperledger.fabric.sdk.Enrollment;
import org.hyperledger.fabric.sdk.HFClient;
import org.hyperledger.fabric.sdk.ProposalResponse;
import org.hyperledger.fabric.sdk.QueryByChaincodeRequest;
import org.hyperledger.fabric.sdk.TransactionProposalRequest;
import org.hyperledger.fabric.sdk.User;
import org.hyperledger.fabric.sdk.security.CryptoSuite;

public class BootstrapClient {

    private static HFClient client = null;
    

    public static void main(String[] args) throws Throwable {
    	
    	Security.addProvider(new BouncyCastleProvider());

        // just new objects, without any payload inside
        client = HFClient.createNewInstance();
        CryptoSuite cs = CryptoSuite.Factory.getCryptoSuite();
        client.setCryptoSuite(cs);

        // We implement User interface below in code
        // folder c:\tmp\creds should contain PeerAdmin.cert (extracted from HF's fabcar
        // example's PeerAdmin json file)
        // and PeerAdmin.priv (copy from
        // cd96d5260ad4757551ed4a5a991e62130f8008a0bf996e4e4b84cd097a747fec-priv)
        User user = new BootstrapUser("crt", "User1@blockchain-a.com");
        // "Log in"
        client.setUserContext(user);
     
        File tlsACrt = Paths.get("../../crypto-config/peerOrganizations/blockchain-a.com/tlsca", "tlsca.blockchain-a.com-cert.pem").toFile();
        File tlsBCrt = Paths.get("../../crypto-config/peerOrganizations/blockchain-b.com/tlsca", "tlsca.blockchain-b.com-cert.pem").toFile();
        File tlsOrdCrt = Paths.get("../../crypto-config/ordererOrganizations/consensus.com/tlsca", "tlsca.consensus.com-cert.pem").toFile();
        
        if (!tlsACrt.exists() || !tlsBCrt.exists())
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
        //secProperties.setProperty("trustServerCertificate", "true");
        
        // Instantiate channel
        Channel channel = client.newChannel("mainchannel");
        channel.addPeer(client.newPeer("peer0.blockchain-a.com", "grpcs://localhost:7051", secPeerAProperties));
        channel.addPeer(client.newPeer("peer0.blockchain-b.com", "grpcs://localhost:10051", secPeerBProperties));
        // It always wants orderer, otherwise even query does not work
        channel.addOrderer(client.newOrderer("orderer0.consensus.com", "grpcs://localhost:7050", secOrdererProperties));
        channel.initialize();

        // below is querying and setting new owner

        query(channel, "PROPERTY0");
        //updateCarOwner(channel, "CAR1", newOwner, false);

        //System.out.println("after request for transaction without commit");
        //queryAll(channel);
        //updateCarOwner(channel, "CAR1", newOwner, true);

        //System.out.println("after request for transaction WITH commit");
        //queryFabcar(channel, "CAR1");

        //System.out.println("Sleeping 5s");
        //hread.sleep(5000); // 5secs
        //queryFabcar(channel, "CAR1");
        System.out.println("all done");
    }

    private static void query(Channel channel, String key) throws Exception {
    	
        QueryByChaincodeRequest req = client.newQueryProposalRequest();
        
        ChaincodeID cid = ChaincodeID.newBuilder().setName("econtract").build();
        req.setChaincodeID(cid);
        req.setFcn("query");
        req.setArgs(new String[] { key });
        
        System.out.println("Querying for " + key);
        
        Collection<ProposalResponse> resps = channel.queryByChaincode(req);
        for (ProposalResponse resp : resps) {
            String payload = new String(resp.getChaincodeActionResponsePayload());
            System.out.println("response: " + payload);
        }

    }

//    private static void updateCarOwner(Channel channel, String key, String newOwner, Boolean doCommit)
//            throws Exception {
//        TransactionProposalRequest req = client.newTransactionProposalRequest();
//        ChaincodeID cid = ChaincodeID.newBuilder().setName("fabcar").build();
//        req.setChaincodeID(cid);
//        req.setFcn("changeCarOwner");
//        req.setArgs(new String[] { key, newOwner });
//        System.out.println("Executing for " + key);
//        Collection<ProposalResponse> resps = channel.sendTransactionProposal(req);
//        if (doCommit) {
//            channel.sendTransaction(resps);
//        }
//    }

}

/***
 * Implementation of user. main business logic (as for fabcar example) is in
 * getEnrollment - get user's private key and cert
 * 
 */
class BootstrapUser implements User {
	

    public static final String PeerOrganizationsMSPID = "PeersAMSP";
	
    private final String certFolder;
    private final String userName;

    public BootstrapUser(String certFolder, String userName) throws IOException {
        this.certFolder = certFolder;
        this.userName = userName;
    }

    @Override
    public String getName() {
        return userName;
    }

    @Override
    public Set<String> getRoles() {
        return new HashSet<String>();
    }

    @Override
    public String getAccount() {
        return "";
    }

    @Override
    public String getAffiliation() {
        return "";
    }

    @Override
    public Enrollment getEnrollment() {
        return new Enrollment() {

            @Override
            public PrivateKey getKey() {
                try {
                    return loadPrivateKey(Paths.get(certFolder, userName + "-priv.pem"));
                } catch (Exception e) {
                    return null;
                }
            }

            @Override
            public String getCert() {
                try {
                	return new String(Files.readAllBytes(Paths.get(certFolder, userName + "-cert.pem")));
                } catch (Exception e) {
                    return "";
                }
            }

        };
    }

    @Override
    public String getMspId() {
        return PeerOrganizationsMSPID;
    }
    /***
     * loading private key from .pem-formatted file, ECDSA algorithm
     * (from some example on StackOverflow, slightly changed)
     * @param fileName - file with the key
     * @return Private Key usable
     * @throws IOException
     * @throws GeneralSecurityException
     */
    public static PrivateKey loadPrivateKey(Path fileName) throws IOException, GeneralSecurityException {
        PrivateKey key = null;
        InputStream is = null;
        try {
            is = new FileInputStream(fileName.toString());
            BufferedReader br = new BufferedReader(new InputStreamReader(is));
            StringBuilder builder = new StringBuilder();
            boolean inKey = false;
            for (String line = br.readLine(); line != null; line = br.readLine()) {
                if (!inKey) {
                    if (line.startsWith("-----BEGIN ") && line.endsWith(" PRIVATE KEY-----")) {
                        inKey = true;
                    }
                    continue;
                } else {
                    if (line.startsWith("-----END ") && line.endsWith(" PRIVATE KEY-----")) {
                        inKey = false;
                        break;
                    }
                    builder.append(line);
                }
            }
            //
            byte[] encoded = DatatypeConverter.parseBase64Binary(builder.toString());
            PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(encoded);
            KeyFactory kf = KeyFactory.getInstance("ECDSA", "BC");
            key = kf.generatePrivate(keySpec);
        } finally {
            is.close();
        }
        return key;
    }
}