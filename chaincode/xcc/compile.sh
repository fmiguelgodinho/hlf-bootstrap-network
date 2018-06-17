#!/bin/bash
#
# Exit on first error, print all commands.
set -ev

export CHAINCODE_FILENAME_NOEXT=xcc

rm -f ${CHAINCODE_FILENAME_NOEXT}

go get -u --tags nopkcs11 github.com/hyperledger/fabric/core/chaincode/shim
go build --tags nopkcs11 ${CHAINCODE_FILENAME_NOEXT}.go
