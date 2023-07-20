// region: docs

/*
==== Invoke assets ====

peer chaincode invoke -C myc1 -n asset_transfer -c '{"Args":["TransferAsset","asset2","jerry"]}'
peer chaincode invoke -C myc1 -n asset_transfer -c '{"Args":["TransferAssetByColor","blue","jerry"]}'
peer chaincode invoke -C myc1 -n asset_transfer -c '{"Args":["DeleteAsset","asset1"]}'

==== Query assets ====
peer chaincode query -C myc1 -n asset_transfer -c '{"Args":["ReadAsset","asset1"]}'
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

// const index = "color~name"

var (
	Logger log.Logger
)

type Chaincode struct {
	contractapi.Contract
}

type Bundle struct {
	DocType            string `json:"doc_type"` //docType is used to distinguish the various types of objects in state database
	BundleID           string `json:"bundle_id"`
	SystemID           string `json:"system_id"`
	ExternalFlag       string `json:"external_flag"`
	ConfidentialFlag   string `json:"confidential_flag"`
	LegacyFlag         string `json:"legacy_flag"`
	NumberOfOperations int    `json:"number_of_operations"`
	TransactionTypeID  string `json:"transaction_type_id"`
	DataBase64         string `json:"data_base64"`
	DataHash           string `json:"data_hash"`
	TxID               string `json:"tx_ID"`
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

// returns true when bundle with given ID exists in the ledger.
func (t *Chaincode) BundleExists(ctx contractapi.TransactionContextInterface, bundleID string) (bool, error) {
	bundleBytes, err := ctx.GetStub().GetState(bundleID)
	if err != nil {
		msg := fmt.Errorf("failed to read bundle %s from world state. %v", bundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return false, msg
	}
	return bundleBytes != nil, nil
}

// CreateBundle initializes a new bundle in the ledger
func (t *Chaincode) CreateBundle(ctx contractapi.TransactionContextInterface, bundleStr string) error {

	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.CreateBundle invoked with -> %s", bundleStr))

	// region: parse json

	var bundleIn Bundle

	err := json.Unmarshal([]byte(bundleStr), &bundleIn)
	if err != nil {
		msg := fmt.Errorf("error parsing bundle: %s (%s)", err, bundleStr)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("bundleStr unmarshaled -> %#v"))

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

	bundleOut := bundleIn
	bundleOut.DocType = "bundle"
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
	// region: index w/ composite key

	//  Create an index to enable color-based range queries, e.g. return all blue assets.
	//  An 'index' is a normal key-value entry in the ledger.
	//  The key is a composite key, with the elements that you want to range query on listed first.
	//  In our case, the composite key is based on indexName~color~name.
	//  This will enable very efficient state range queries based on composite keys matching indexName~color~*
	// colorNameIndexKey, err := ctx.GetStub().CreateCompositeKey(index, []string{asset.Color, asset.ID})
	// if err != nil {
	// 	return err
	// }
	//  Save index entry to world state. Only the key name is needed, no need to store a duplicate copy of the asset.
	//  Note - passing a 'nil' value will effectively delete the key from state, therefore we pass null character as value
	// value := []byte{0x00}
	// return ctx.GetStub().PutState(colorNameIndexKey, value)

	// endregion: index w/ composite key

	return nil

}

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
