// region: docs

/*
==== Invoke assets ====

peer chaincode invoke -C myc1 -n asset_transfer -c '{"Args":["TransferAsset","asset2","jerry"]}'

==== Query assets ====
peer chaincode query -C myc1 -n asset_transfer -c '{"Args":["GetAssetsByRange","asset1","asset3"]}'
peer chaincode query -C myc1 -n asset_transfer -c '{"Args":["GetAssetHistory","asset1"]}'

Rich Query (Only supported if CouchDB is used as state database):
peer chaincode query -C myc1 -n asset_transfer -c '{"Args":["QueryAssetsByOwner","tom"]}'
peer chaincode query -C myc1 -n asset_transfer -c '{"Args":["QueryAssets","{\"selector\":{\"owner\":\"tom\"}}"]}'

Rich Query with Pagination (Only supported if CouchDB is used as state database):
peer chaincode query -C myc1 -n asset_transfer -c '{"Args":["QueryAssetsWithPagination","{\"selector\":{\"owner\":\"tom\"}}","3",""]}'

...

Example curl command line to define index in the CouchDB channel_chaincode database:
curl -i -X POST -H "Content-Type: application/json" -d "{\"index\":{\"fields\":[{\"size\":\"desc\"},{\"docType\":\"desc\"},{\"owner\":\"desc\"}]},\"ddoc\":\"indexSizeSortDoc\", \"name\":\"indexSizeSortDesc\",\"type\":\"json\"}" http://hostname:port/myc1_assets/_index

Rich Query with index design doc and index name specified (Only supported if CouchDB is used as state database):
peer chaincode query -C myc1 -n asset_transfer -c '{"Args":["QueryAssets","{\"selector\":{\"docType\":\"asset\",\"owner\":\"tom\"}, \"use_index\":[\"_design/indexOwnerDoc\", \"indexOwner\"]}"]}'

Rich Query with index design doc specified only (Only supported if CouchDB is used as state database):
peer chaincode query -C myc1 -n asset_transfer -c '{"Args":["QueryAssets","{\"selector\":{\"docType\":{\"$eq\":\"asset\"},\"owner\":{\"$eq\":\"tom\"},\"size\":{\"$gt\":0}},\"fields\":[\"docType\",\"owner\",\"size\"],\"sort\":[{\"size\":\"desc\"}],\"use_index\":\"_design/indexSizeSortDoc\"}"]}'
*/

// endregion: docs
// region: packages

package main

import (
	"encoding/json"
	"fmt"
	"log/syslog"
	"time"

	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	// "github.com/SandorMiskey/TEx-kit/log"
	// "github.com/golang/protobuf/ptypes"
	// "github.com/hyperledger/fabric-chaincode-go/shim"
	// "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// endregion: packages
// region: types, globals anc consts

var (
	Logger log.Logger
)

type Chaincode struct {
	contractapi.Contract
}

type Bundle struct {
	DocType            string      `json:"doc_type"` //docType is used to distinguish the various types of objects in state database
	BundleID           string      `json:"bundle_id"`
	SystemID           string      `json:"system_id"`
	ExternalFlag       string      `json:"external_flag"`
	ConfidentialFlag   string      `json:"confidential_flag"`
	LegacyFlag         string      `json:"legacy_flag"`
	NumberOfOperations int         `json:"number_of_operations"`
	TransactionTypeID  string      `json:"transaction_type_id"`
	DataBase64         string      `json:"data_base64"`
	DataHash           string      `json:"data_hash"`
	TxID               string      `json:"tx_id"`
	TxTimestamp        string      `json:"tx_timestamp"`
	UpdateTxID         interface{} `json:"update_tx_id"`
	UpdateTimestamp    interface{} `json:"update_timestamp"`
}

// HistoryQueryResult structure used for returning result of history query
type HistoryQueryResult struct {
	Record    *Bundle   `json:"record"`
	TxId      string    `json:"tx_id"`
	Timestamp time.Time `json:"timestamp"`
	IsDelete  bool      `json:"isDelete"`
}

// PaginatedQueryResult structure used for returning paginated query results and metadata
type PaginatedQueryResult struct {
	Records             []*Bundle `json:"records"`
	FetchedRecordsCount int32     `json:"fetched_records_count"`
	Bookmark            string    `json:"bookmark"`
}

// endregion: types anc consts
// region: functions

func (t *Chaincode) BundleExists(ctx contractapi.TransactionContextInterface, bundleID string) (bool, error) {

	// returns true when bundle with given ID exists in the ledger.
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleExists queried with -> %s", bundleID))

	bundleBytes, err := ctx.GetStub().GetState(bundleID)
	if err != nil {
		msg := fmt.Errorf("failed to read bundle %s from world state. %v", bundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return false, msg
	}
	return bundleBytes != nil, nil
}

func (t *Chaincode) CreateBundle(ctx contractapi.TransactionContextInterface, bundleStr string) error {

	// CreateBundle initializes a new bundle in the ledger
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.CreateBundle invoked with -> %s", bundleStr))

	// region: parse json

	var bundleIn Bundle

	err := json.Unmarshal([]byte(bundleStr), &bundleIn)
	if err != nil {
		msg := fmt.Errorf("error parsing bundle: %s (%s)", err, bundleStr)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.CreateBundle bundleStr unmarshaled -> %#v"))

	// endregion: parse json
	// region: check if exists

	exists, err := t.BundleExists(ctx, bundleIn.BundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle: %v", err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	if exists {
		msg := fmt.Errorf("bundle already exists: %s", bundleIn.BundleID)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("ledger chacked, bundle does not exist yet -> %s", bundleIn.BundleID))

	// endregion: check if exists
	// region: bundle out

	now := time.Now()

	bundleOut := bundleIn
	bundleOut.DocType = "bundle"
	bundleOut.TxID = ctx.GetStub().GetTxID()
	bundleOut.TxTimestamp = now.Format(time.RFC3339)
	bundleOut.UpdateTxID = nil
	bundleOut.UpdateTimestamp = nil
	bundleBytes, err := json.Marshal(bundleOut)
	if err != nil {
		msg := fmt.Errorf("failed to marshal bundle: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("bundle marshaled -> %#v", bundleOut))

	err = ctx.GetStub().PutState(bundleOut.BundleID, bundleBytes)
	if err != nil {
		msg := fmt.Errorf("failed to put bundle: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	Logger.Out(log.LOG_DEBUG, "world state updated with no errors")

	// endregion: bundle out

	return nil

}

func (t *Chaincode) DeleteBundle(ctx contractapi.TransactionContextInterface, bundleID string) error {

	// DeleteBundle removes an asset key-value pair from the ledger
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.DeleteBundle invoked with -> %s", bundleID))

	_, err := t.ReadBundle(ctx, bundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle %s: %v", bundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	err = ctx.GetStub().DelState(bundleID)
	if err != nil {
		msg := fmt.Errorf("failed to delete bundle %s: %v", bundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	return nil
}

func (t *Chaincode) ReadBundle(ctx contractapi.TransactionContextInterface, bundleID string) (*Bundle, error) {

	// ReadBundle retrieves a bundle from the ledger
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.ReadBundle queried with -> %s", bundleID))

	bundleBytes, err := ctx.GetStub().GetState(bundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle %s: %v", bundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if bundleBytes == nil {
		msg := fmt.Errorf("bundle %s does not exist", bundleID)
		Logger.Out(log.LOG_INFO, msg)
		return nil, msg
	}

	var bundle Bundle
	err = json.Unmarshal(bundleBytes, &bundle)
	if err != nil {
		msg := fmt.Errorf("failed to json unmarshal bundle %s: %v ", bundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	return &bundle, nil
}

func (t *Chaincode) UpdateBundleById(ctx contractapi.TransactionContextInterface, bundleStr string) error {

	// UpdateBundle reset bundle except tx_id's and timestamps
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.UpdateBundleById invoked with -> %s", bundleStr))

	// region: parse json

	var bundleIn Bundle

	err := json.Unmarshal([]byte(bundleStr), &bundleIn)
	if err != nil {
		msg := fmt.Errorf("error parsing bundle: %s (%s)", err, bundleStr)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.CreateBundle bundleStr unmarshaled -> %#v"))

	// endregion: parse json
	// region: check if exists

	exists, err := t.BundleExists(ctx, bundleIn.BundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle: %v", err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	if !exists {
		msg := fmt.Errorf("bundle does not exists: %s", bundleIn.BundleID)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("ledger chacked, bundle does exist -> %s", bundleIn.BundleID))

	// endregion: check if exists
	// region: get original

	bundleOrig, err := t.ReadBundle(ctx, bundleIn.BundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle %s: %v", bundleIn.BundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}

	// endregion: get original
	// region: updated bundle

	now := time.Now()

	bundleOut := bundleIn
	bundleOut.DocType = "bundle"
	bundleOut.TxID = bundleOrig.TxID
	bundleOut.TxTimestamp = bundleOrig.TxID
	bundleOut.UpdateTxID = ctx.GetStub().GetTxID()
	bundleOut.UpdateTimestamp = now.Format(time.RFC3339)
	bundleBytes, err := json.Marshal(bundleOut)
	if err != nil {
		msg := fmt.Errorf("failed to marshal bundle: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("bundle marshaled -> %#v", bundleOut))

	// endregion: updated bundle
	// region: bundle out

	err = ctx.GetStub().PutState(bundleOut.BundleID, bundleBytes)
	if err != nil {
		msg := fmt.Errorf("failed to put bundle: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	Logger.Out(log.LOG_DEBUG, "world state updated with no errors")

	return nil

	// endregion: bundle out

}

// endregion: functions

func main() {

	// region: init logger

	logLevel := syslog.LOG_DEBUG
	prefix := "==> te-food-bundles ==> "

	Logger = *log.NewLogger()
	defer Logger.Close()
	_, _ = Logger.NewCh(log.ChConfig{Severity: &logLevel, Prefix: &prefix})

	// endregion: init logger

	chaincode, err := contractapi.NewChaincode(&Chaincode{})
	if err != nil {
		Logger.Out(log.LOG_EMERG, fmt.Sprintf("error creating chaincode: %v", err))
	}
	if err := chaincode.Start(); err != nil {
		Logger.Out(log.LOG_EMERG, fmt.Sprintf("error starting chaincode: %v", err))
	}
}
