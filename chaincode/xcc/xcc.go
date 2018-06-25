package main

// Simple Contract Chaincode

/* Imports
 * 4 utility libraries for formatting, handling bytes, reading and writing JSON, and string manipulation
 * 2 specific Hyperledger Fabric specific libraries for Smart Contracts
 */
import (
	"bytes"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	sc "github.com/hyperledger/fabric/protos/peer"
)

// Define the Smart Contract structure
type SmartContract struct {
}

type ExtendedContractProperties struct {
	ContractId						string `json:"contract-id"`
	ContractVersion				int `json:"contract-version"`
	AvailableFunctions		[][]string `json:"available-functions"`
	InstalledOnNodes			[]string `json:"installed-on-nodes"`
	SignatureType					string `json:"signature-type"`			// multisig, threshsig, set?
	SigningNodes					[]string `json:"signing-nodes"`
	ConsensusType					string `json:"consensus-type"`			// bft, failstop
	ConsensusNodes				[]string `json:"consensus-nodes"`
}

type ApplicationSpecificProperties struct {
	MaxRecords						int `json:"max-records"`
	TotalRecords					int `json:"total-records"`
	// ...for example purposes only
}



// Structure tags are used by encoding/json library
type Record struct {
	Data  								string `json:"data"`							// this where all application context gets stored
}

/*
 * The Init method is called when the Smart Contract is instantiated by the blockchain network
 * Best practice is to have any Ledger initialization in separate function -- see initLedger()
 */
func (s *SmartContract) Init(APIstub shim.ChaincodeStubInterface) sc.Response {

	args := APIstub.GetStringArgs()
	if len(args) != 2 {
		return shim.Error("Incorrect number of arguments for invoking: initContract. Expecting 2 (1 JSON for ExtendedContractProperties, 1 JSON for ApplicationSpecificProperties)")
	}


	// unmarshalled for validation only
	var extProps ExtendedContractProperties
	var appProps ApplicationSpecificProperties

	// EXT PROPS
	err := json.Unmarshal([]byte(args[0]), &extProps)
	if err != nil {
		return shim.Error(err.Error())
	}

	// APP PROPS
	err = json.Unmarshal([]byte(args[1]), &appProps)
	if err != nil {
		return shim.Error(err.Error())
	}

	// if no errors, then it's okay and we can move one

	extPropsCompositeKey, _ := APIstub.CreateCompositeKey("props", []string{"EXTENDED_CONTRACT_PROPERTIES"})
	extPropsAsBytes := json.RawMessage(args[0])
	APIstub.PutState(extPropsCompositeKey, extPropsAsBytes)		//store according to key

	appPropsCompositeKey, _ := APIstub.CreateCompositeKey("props", []string{"APPLICATION_SPECIFIC_PROPERTIES"})
	appPropsAsBytes := json.RawMessage(args[1])
	APIstub.PutState(appPropsCompositeKey, appPropsAsBytes)		//store according to key

	return shim.Success(nil)
}

/*
 * The Invoke method is called as a result of an application request to run the Smart Contract
 * The calling application program has also specified the particular smart contract function to be called, with arguments
 */
func (s *SmartContract) Invoke(APIstub shim.ChaincodeStubInterface) sc.Response {

	// Retrieve the requested Smart Contract function and arguments
	function, args := APIstub.GetFunctionAndParameters()
	// Route to the appropriate handler function to interact with the ledger appropriately
	if function == "getContractDefinition" {
		return s.getContractDefinition(APIstub)
	} else if function == "query" {
		return s.query(APIstub, args)
	} else if function == "queryAll" {
		return s.queryAll(APIstub)
	} else if function == "put" {
		return s.put(APIstub, args)
	}
	// search using shim.GetQueryResult?

	return shim.Error("Invalid contract function name.")
}

func (s *SmartContract) query(APIstub shim.ChaincodeStubInterface, args []string) sc.Response {

	if len(args) < 1 {
		return shim.Error("Incorrect number of arguments for invoking: query. Expecting at least 1")
	}

	returnHistory := false
	if len(args) == 2 {
		returnHistory, _ = strconv.ParseBool(args[1])
	}

	// create key
	dataCompositeKey, err := APIstub.CreateCompositeKey("data", []string{args[0]})
	if err != nil {
		return shim.Error(err.Error())
	}
	// read record
	dataAsBytes, err := APIstub.GetState(dataCompositeKey)
	if err != nil {
		return shim.Error(err.Error())
	}

	var buffer bytes.Buffer
	buffer.WriteString("{\"key\":")
	buffer.WriteString("\"")
	buffer.WriteString(args[0])
	buffer.WriteString("\"")
	buffer.WriteString(", \"record\":")
	buffer.WriteString(string(dataAsBytes))

	if returnHistory {

		resultsIterator, err := APIstub.GetHistoryForKey(dataCompositeKey)
		if err != nil {
			return shim.Error(err.Error())
		}
		defer resultsIterator.Close()

		// buffer is a JSON array containing QueryResults

		buffer.WriteString(", \"history\": [")

		bArrayMemberAlreadyWritten := false
		for resultsIterator.HasNext() {
			queryResponse, err := resultsIterator.Next()
			if err != nil {
				return shim.Error(err.Error())
			}
			// Add a comma before array members, suppress it for the first array member
			if bArrayMemberAlreadyWritten == true {
				buffer.WriteString(",")
			}
			buffer.WriteString("{\"timestamp\":")
			buffer.WriteString(queryResponse.Timestamp.String())

			buffer.WriteString(", \"record\":")
			buffer.WriteString(string(queryResponse.Value))

			buffer.WriteString(", \"txid\":")
			buffer.WriteString(queryResponse.TxId)

			buffer.WriteString(", \"is-delete\":")
			buffer.WriteString("\"")
			buffer.WriteString(strconv.FormatBool(queryResponse.IsDelete))
			buffer.WriteString("\"")

			buffer.WriteString("}")
			bArrayMemberAlreadyWritten = true
		}
		buffer.WriteString("]")
	}

	buffer.WriteString("}")
	return shim.Success(buffer.Bytes())
}

func (s *SmartContract) queryAll(APIstub shim.ChaincodeStubInterface) sc.Response {

	resultsIterator, err := APIstub.GetStateByPartialCompositeKey("data", []string{})
	if err != nil {
		return shim.Error(err.Error())
	}
	defer resultsIterator.Close()

	// buffer is a JSON array containing QueryResults
	var buffer bytes.Buffer
	buffer.WriteString("[")

	bArrayMemberAlreadyWritten := false
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return shim.Error(err.Error())
		}
		// Add a comma before array members, suppress it for the first array member
		if bArrayMemberAlreadyWritten == true {
			buffer.WriteString(",")
		}
		buffer.WriteString("{\"key\":")
		buffer.WriteString("\"")
		buffer.WriteString(strings.Trim(queryResponse.Key, "data"))
		buffer.WriteString("\"")

		buffer.WriteString(", \"record\":")
		// Record is a JSON object, so we write as-is
		buffer.WriteString(string(queryResponse.Value))
		buffer.WriteString("}")
		bArrayMemberAlreadyWritten = true
	}
	buffer.WriteString("]")

	return shim.Success(buffer.Bytes())
}

func (s *SmartContract) put(APIstub shim.ChaincodeStubInterface, args []string) sc.Response {
	if len(args) != 2 {
		return shim.Error("Incorrect number of arguments for invoking: put. Expecting 2")
	}

	// get application specific properties first
	var appProps ApplicationSpecificProperties
	appPropsCompositeKey, _ := APIstub.CreateCompositeKey("props", []string{"APPLICATION_SPECIFIC_PROPERTIES"})
	appPropsAsBytes, err := APIstub.GetState(appPropsCompositeKey)
	if err != nil {
		return shim.Error(err.Error())
	}
	err = json.Unmarshal(appPropsAsBytes, &appProps)
	if err != nil {
		return shim.Error(err.Error())
	}

	// perform application specific validation
	if appProps.TotalRecords == appProps.MaxRecords {
		return shim.Error(fmt.Sprintf("Max number of records reached (total: %d, max: %d)!",  appProps.TotalRecords,  appProps.MaxRecords))
	}

	dataCompositeKey, err := APIstub.CreateCompositeKey("data", []string{args[0]})
	if err != nil {
		return shim.Error(err.Error())
	}
	// check if data exists
	exists, _ := APIstub.GetState(dataCompositeKey)

	// store the data
	var newRecord = Record{
		Data: args[1],
	}
	dataAsBytes, _ := json.Marshal(newRecord)
	APIstub.PutState(dataCompositeKey, dataAsBytes)		//store according to key

	if exists == nil {
		appProps.TotalRecords++
		// update app specific properties
		propertyAsBytes, _ := json.Marshal(appProps)
		APIstub.PutState(appPropsCompositeKey, propertyAsBytes)
	}

	return shim.Success(nil)
}

func (s *SmartContract) getContractDefinition(APIstub shim.ChaincodeStubInterface) sc.Response {

	// gen composite keys
	extPropsCompositeKey, _ := APIstub.CreateCompositeKey("props", []string{"EXTENDED_CONTRACT_PROPERTIES"})
	appPropsCompositeKey, _ := APIstub.CreateCompositeKey("props", []string{"APPLICATION_SPECIFIC_PROPERTIES"})

	// read records
	extPropsAsBytes, err := APIstub.GetState(extPropsCompositeKey)
	if err != nil {
		return shim.Error(err.Error())
	}
	appPropsAsBytes, err := APIstub.GetState(appPropsCompositeKey)
	if err != nil {
		return shim.Error(err.Error())
	}

	var buffer bytes.Buffer
	buffer.WriteString("{\"extended-contract-properties\":")
	buffer.WriteString(string(extPropsAsBytes))
	buffer.WriteString(", \"application-specific-properties\":")
	buffer.WriteString(string(appPropsAsBytes))
	buffer.WriteString("}")

	return shim.Success(buffer.Bytes())
}

// The main function is only relevant in unit test mode. Only included here for completeness.
func main() {

	// Create a new Smart Contract
	err := shim.Start(new(SmartContract))
	if err != nil {
		fmt.Printf("Error creating new contract: %s", err)
	}
}
