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

	"github.com/hyperledger/fabric/core/chaincode/shim"
	sc "github.com/hyperledger/fabric/protos/peer"
)

// TODO:	- Data structs for TRANSACTION and LIST OF TRANSACTIONS (LOG OF EXECUTED OPS)
//				- Split sections of smart contract /system, business

// Define the Smart Contract structure
type SmartContract struct {
}

// Structure tags are used by encoding/json library
type Record struct {
	Data  					string `json:"data"`							// this where all application context gets stored
}

/*
 * The Init method is called when the Smart Contract is instantiated by the blockchain network
 * Best practice is to have any Ledger initialization in separate function -- see initLedger()
 */
func (s *SmartContract) Init(APIstub shim.ChaincodeStubInterface) sc.Response {
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
	if function == "initContract" {
		return s.initContract(APIstub)
	} else if function == "getContractDefinition" {
		return s.getContractDefinition(APIstub, args)
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


func (s *SmartContract) initContract(APIstub shim.ChaincodeStubInterface) sc.Response {
	// TODO any init can be done here
	return shim.Success(nil)
}

func (s *SmartContract) query(APIstub shim.ChaincodeStubInterface, args []string) sc.Response {

	if len(args) < 1 {
		return shim.Error("Incorrect number of arguments for invoking: query. Expecting at least 1")
	}

	returnHistory := false
	if len(args) == 2 {
		returnHistory, _ = strconv.ParseBool(args[1])
	}

	// read record
	propertyAsBytes, err := APIstub.GetState(args[0])
	if err != nil {
		return shim.Error(err.Error())
	}

	var buffer bytes.Buffer
	buffer.WriteString("{\"key\":")
	buffer.WriteString("\"")
	buffer.WriteString(args[0])
	buffer.WriteString("\"")
	buffer.WriteString(", \"record\":")
	buffer.WriteString(string(propertyAsBytes))

	if returnHistory {

		resultsIterator, err := APIstub.GetHistoryForKey(args[0])
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

	resultsIterator, err := APIstub.GetStateByRange("", "")
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
		buffer.WriteString(queryResponse.Key)
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

	var newRecord = Record{
		Data: args[1],
	}

	propertyAsBytes, _ := json.Marshal(newRecord)
	APIstub.PutState(args[0], propertyAsBytes)		//store according to key

	return shim.Success(nil)
}

func (s *SmartContract) getContractDefinition(APIstub shim.ChaincodeStubInterface, args []string) sc.Response {
	if len(args) != 1 {
		return shim.Error("Incorrect number of arguments for invoking: getContractDefinition. Expecting 1")
	}
	// TODO
	return shim.Success(nil)
}

// The main function is only relevant in unit test mode. Only included here for completeness.
func main() {

	// Create a new Smart Contract
	err := shim.Start(new(SmartContract))
	if err != nil {
		fmt.Printf("Error creating new contract: %s", err)
	}
}
