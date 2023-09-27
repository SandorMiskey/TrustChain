// region: packages

package main

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/syslog"
	"strings"
	"time"

	"github.com/SandorMiskey/TEx-kit/log"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// endregion: packages
// region: types and globals

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
	NumberOfOperations int16       `json:"number_of_operations"`
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
	TxID      string    `json:"tx_id"`
	Timestamp time.Time `json:"timestamp"`
	IsDelete  bool      `json:"isDelete"`
}

// PaginatedQueryResult structure used for returning paginated query results and metadata
type PaginatedQueryResult struct {
	Records             []*Bundle `json:"records"`
	FetchedRecordsCount int32     `json:"fetched_records_count"`
	Bookmark            string    `json:"bookmark"`
}

// endregion: types and globals
// region: functions

// region: helpers

func constructQueryResponseFromIterator(resultsIterator shim.StateQueryIteratorInterface) ([]*Bundle, error) {

	// constructQueryResponseFromIterator constructs a slice of bundles from the resultsIterator
	Logger.Out(log.LOG_DEBUG, "constructQueryResponseFromIterator helper in action")

	var bundles []*Bundle
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			msg := fmt.Errorf("error in constructQueryResponseFromIterator when resultsIterator.Next(): %s", err)
			Logger.Out(log.LOG_ERR, msg)
			return nil, msg
		}
		var bundle Bundle
		err = json.Unmarshal(queryResult.Value, &bundle)
		if err != nil {
			msg := fmt.Errorf("error in constructQueryResponseFromIterator when json.Unmarshal(queryResult.Value, &bundle): %s", err)
			Logger.Out(log.LOG_ERR, msg)
			return nil, msg
		}
		bundles = append(bundles, &bundle)
	}

	return bundles, nil
}

func getQueryResultForQueryString(ctx contractapi.TransactionContextInterface, queryString string) ([]*Bundle, error) {

	// getQueryResultForQueryString executes the passed in query string. The
	// result set is built and returned as a byte array containing the JSON results.
	Logger.Out(log.LOG_DEBUG, "getQueryResultForQueryString helper in action")

	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		msg := fmt.Errorf("error in getQueryResultForQueryString when ctx.GetStub().GetQueryResult(queryString: %s): %s", queryString, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	defer resultsIterator.Close()

	return constructQueryResponseFromIterator(resultsIterator)
}

func getQueryResultForQueryStringWithPagination(ctx contractapi.TransactionContextInterface, queryString string, pageSize int32, bookmark string) (*PaginatedQueryResult, error) {

	// getQueryResultForQueryStringWithPagination executes the passed in query string with
	// pagination info. The result set is built and returned as a byte array containing the JSON results.
	Logger.Out(log.LOG_DEBUG, "getQueryResultForQueryStringWithPagination helper in action")

	resultsIterator, responseMetadata, err := ctx.GetStub().GetQueryResultWithPagination(queryString, pageSize, bookmark)
	if err != nil {
		msg := fmt.Errorf("error in getQueryResultForQueryStringWithPagination while ctx.GetStub().GetQueryResultWithPagination(queryString: %s, pageSize %v, bookmark: %s): %s", queryString, pageSize, bookmark, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	defer resultsIterator.Close()

	bundles, err := constructQueryResponseFromIterator(resultsIterator)
	if err != nil {
		msg := fmt.Errorf("error in getQueryResultForQueryStringWithPagination while constructQueryResponseFromIterator(): %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	return &PaginatedQueryResult{
		Records:             bundles,
		FetchedRecordsCount: responseMetadata.FetchedRecordsCount,
		Bookmark:            responseMetadata.Bookmark,
	}, nil
}

// endregion: helpers
// region: queries

func (t *Chaincode) BundleExists(ctx contractapi.TransactionContextInterface, bundleID string) (bool, error) {

	// returns true when bundle with given ID exists in the ledger
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleExists queried with -> %s", bundleID))

	bundleBytes, err := ctx.GetStub().GetState(bundleID)
	if err != nil {
		msg := fmt.Errorf("failed to read bundle %s from world state. %v", bundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return false, msg
	}
	return bundleBytes != nil, nil
}

func (t *Chaincode) BundleHistory(ctx contractapi.TransactionContextInterface, bundleID string) ([]HistoryQueryResult, error) {

	// BundleHistory returns the chain of custody for a bundle since issuance
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleHistory queried with -> %v", bundleID))

	// iterator
	resultsIterator, err := ctx.GetStub().GetHistoryForKey(bundleID)
	if err != nil {
		msg := fmt.Errorf("error in t.BundleHistory when ctx.GetStub().GetHistoryForKey(%v): %s", bundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	defer resultsIterator.Close()
	Logger.Out(log.LOG_DEBUG, "t.BundleHistory got iterator")

	// iterate on history
	var records []HistoryQueryResult
	for resultsIterator.HasNext() {

		// read record
		response, err := resultsIterator.Next()
		if err != nil {
			msg := fmt.Errorf("error in t.BundleHistory when resultsIterator.Next(): %s", err)
			Logger.Out(log.LOG_ERR, msg)
			return nil, msg
		}
		Logger.Out(log.LOG_DEBUG, "t.BundleHistory new record read")

		// validate record
		var bundle Bundle
		if len(response.Value) > 0 {
			err = json.Unmarshal(response.Value, &bundle)
			if err != nil {
				msg := fmt.Errorf("unable to unmarshal bundle (%s) in t.BundleHistory: %s", response.Value, err)
				Logger.Out(log.LOG_ERR, msg)
				return nil, msg
			}
		} else {
			bundle = Bundle{
				BundleID: bundleID,
			}
		}
		Logger.Out(log.LOG_DEBUG, "t.BundleHistory valid record")

		// check timestamp
		err = response.Timestamp.CheckValid()
		if err != nil {
			msg := fmt.Errorf("unable to parse timestamp (%s) in t.BundleHistory: %s", response.Timestamp, err)
			Logger.Out(log.LOG_ERR, msg)
			return nil, msg
		}
		Logger.Out(log.LOG_DEBUG, "t.BundleHistory valid timestamp")

		// set record
		record := HistoryQueryResult{
			TxID:      response.TxId,
			Timestamp: response.Timestamp.AsTime(),
			Record:    &bundle,
			IsDelete:  response.IsDelete,
		}
		records = append(records, record)
		Logger.Out(log.LOG_DEBUG, "t.BundleHistory new record")

	}

	return records, nil
}

func (t *Chaincode) BundleGet(ctx contractapi.TransactionContextInterface, bundleID string) (*Bundle, error) {

	// BundleGet retrieves a bundle from the ledger
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleGet queried with -> %s", bundleID))

	bundleBytes, err := ctx.GetStub().GetState(bundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle %s: %v", bundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if bundleBytes == nil {
		msg := fmt.Errorf("t.BundleGet says bundle %s does not exist", bundleID)
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

func (t *Chaincode) BundleGetRange(ctx contractapi.TransactionContextInterface, startKey, endKey string) ([]*Bundle, error) {

	// BundleGet retrieves a bundle from the ledger
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleGetRange queried with %s -> %s", startKey, endKey))

	resultsIterator, err := ctx.GetStub().GetStateByRange(startKey, endKey)
	if err != nil {
		msg := fmt.Errorf("error in t.BundleGetRange while ctx.GetStub().GetStateByRange(%s, %s): %v", startKey, endKey, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	defer resultsIterator.Close()

	return constructQueryResponseFromIterator(resultsIterator)
}

func (t *Chaincode) BundleGetRangeWithPagination(ctx contractapi.TransactionContextInterface, startKey string, endKey string, pageSize int, bookmark string) (*PaginatedQueryResult, error) {

	// BundleGetRangeWithPagination performs a range query based on the start and end key,
	// page size and a bookmark. The number of fetched records will be equal to or lesser
	// than the page size. Paginated range queries are only valid for read only transactions.

	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleGetRangeWithPagination queried with startKey -> %s, endKey -> %s, pageSize -> %v, bookmark -> %s", startKey, endKey, pageSize, bookmark))

	resultsIterator, responseMetadata, err := ctx.GetStub().GetStateByRangeWithPagination(startKey, endKey, int32(pageSize), bookmark)
	if err != nil {
		msg := fmt.Errorf("error in t.BundleGetRangeWithPagination while ctx.GetStub().GetStateByRangeWithPagination(%s, %s, %v, %s): %s", startKey, endKey, pageSize, bookmark, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	defer resultsIterator.Close()

	bundles, err := constructQueryResponseFromIterator(resultsIterator)
	if err != nil {
		msg := fmt.Errorf("error in t.BundleGetRangeWithPagination while constructQueryResponseFromIterator(): %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	return &PaginatedQueryResult{
		Records:             bundles,
		FetchedRecordsCount: responseMetadata.FetchedRecordsCount,
		Bookmark:            responseMetadata.Bookmark,
	}, nil
}

func (t *Chaincode) BundleQuery(ctx contractapi.TransactionContextInterface, queryString string) ([]*Bundle, error) {

	// BundleQuery uses a query string to perform a query for bundles. Query
	// string matching state database syntax is passed in and executed as is.
	// Supports ad hoc queries that can be defined at runtime by the client.

	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleQuery queried with %s", queryString))
	return getQueryResultForQueryString(ctx, queryString)
}

func (t *Chaincode) BundleQueryWithPagination(ctx contractapi.TransactionContextInterface, queryString string, pageSize int, bookmark string) (*PaginatedQueryResult, error) {

	// BundleQueryWithPagination uses a query string, page size and a bookmark to perform a query
	// for bundles. Query string matching state database syntax is passed in and executed as is.
	// The number of fetched records would be equal to or lesser than the specified page size.
	// Supports ad hoc queries that can be defined at runtime by the client. Only available on
	// state databases that support rich query (e.g. CouchDB). Paginated queries are only valid
	// for read only transactions.

	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleQueryWithPagination queried with queryString -> %s, pageSize -> %v, bookmark -> %s", queryString, pageSize, bookmark))
	return getQueryResultForQueryStringWithPagination(ctx, queryString, int32(pageSize), bookmark)
}

func (t *Chaincode) BundleValidate(ctx contractapi.TransactionContextInterface, bundleStr string) (bool, error) {

	// BundleValidate validates bundle.DataHash against computed from bundle.DataBase64
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleValidate invoked with -> %s", bundleStr))

	// region: parse json

	var bundleIn Bundle

	err := json.Unmarshal([]byte(bundleStr), &bundleIn)
	if err != nil {
		msg := fmt.Errorf("t.BundleValidate: error parsing bundle: %s (%s)", err, bundleStr)
		Logger.Out(log.LOG_ERR, msg)
		return false, msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleValidate: bundleStr unmarshal -> %#v", bundleIn))

	// endregion: parse json
	// region: decode the base64 encoded string

	bundleIn.DataBase64 = strings.Replace(bundleIn.DataBase64, " ", "+", -1)

	decodedBytes, err := base64.StdEncoding.DecodeString(bundleIn.DataBase64)
	if err != nil {
		msg := fmt.Errorf("t.BundleValidate: unable to decode bundleIn.DataBase64: %s (%s)", err, bundleIn.DataBase64)
		Logger.Out(log.LOG_ERR, msg)
		return false, msg
	}

	// endregion: decode
	// region: compute the SHA256 hash

	hashBytes := sha256.Sum256(decodedBytes)
	hashString := hex.EncodeToString(hashBytes[:])

	// compare
	if bundleIn.DataHash != hashString {
		Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleValidate: bundleIn.DataHash != hashString: %s != %s)", bundleIn.DataHash, hashString))
		return false, nil
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleValidate: bundleIn.DataHash == hashString: %s != %s)", bundleIn.DataHash, hashString))
	return true, nil

	// endregion: compute

}

// endregion: queries
// region: invokes

func (t *Chaincode) CreateBundle(ctx contractapi.TransactionContextInterface, bundleStr string) (*Bundle, error) {

	// CreateBundle initializes a new bundle in the ledger
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.CreateBundle invoked with -> %s", bundleStr))

	// region: validate

	isValid, err := t.BundleValidate(ctx, bundleStr)
	if err != nil {
		msg := fmt.Errorf("t.CreateBundle: unable to validate bundleIn: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if !isValid {
		msg := fmt.Errorf("t.CreateBundle: bundleIn.DataBase64 vs. bundleIn.DataHash validation failed")
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	// endregion: validate
	// region: parse json

	var bundleIn Bundle

	err = json.Unmarshal([]byte(bundleStr), &bundleIn)
	if err != nil {
		msg := fmt.Errorf("t.CreateBundle: error parsing bundle: %s (%s)", err, bundleStr)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.CreateBundle: bundleStr unmarshal -> %#v", bundleIn))

	// endregion: parse json
	// region: check if exists

	exists, err := t.BundleExists(ctx, bundleIn.BundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle: %v", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if exists {
		msg := fmt.Errorf("bundle already exists: %v", bundleIn.BundleID)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("ledger checked, bundle does not exist yet -> %v", bundleIn.BundleID))

	// endregion: check if exists
	// region: bundle out

	now := time.Now()
	stub := ctx.GetStub()

	bundleOut := bundleIn
	bundleOut.DocType = "bundle"
	bundleOut.TxID = stub.GetTxID()
	// bundleOut.TxTimestamp = now.Format(time.RFC3339)
	bundleOut.TxTimestamp = now.Format("2006-01-02T15:04:00Z")
	bundleOut.UpdateTxID = nil
	bundleOut.UpdateTimestamp = nil

	if bundleIn.LegacyFlag == "1" || bundleIn.ConfidentialFlag == "1" {
		bundleOut.DataBase64 = ""
	}

	bundleBytes, err := json.Marshal(bundleOut)
	if err != nil {
		msg := fmt.Errorf("failed to marshal bundle: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("bundle marshaled -> %#v", bundleOut))

	err = stub.PutState(bundleOut.BundleID, bundleBytes)
	if err != nil {
		msg := fmt.Errorf("failed to put bundle: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, "world state updated with no errors")

	err = stub.SetEvent("CreateBundle", bundleBytes)
	if err != nil {
		return nil, err
	}

	return &bundleOut, nil

	// endregion: bundle out

}

func (t *Chaincode) DeleteBundle(ctx contractapi.TransactionContextInterface, bundleID string) error {

	// DeleteBundle removes an asset key-value pair from the ledger
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.DeleteBundle invoked with -> %s", bundleID))

	_, err := t.BundleGet(ctx, bundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle %s in t.DeleteBundle: %v", bundleID, err)
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

func (t *Chaincode) UpdateBundle(ctx contractapi.TransactionContextInterface, bundleStr string) (*Bundle, error) {

	// UpdateBundle reset bundle except tx_id's and timestamps
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.UpdateBundleById invoked with -> %s", bundleStr))

	// region: validate

	isValid, err := t.BundleValidate(ctx, bundleStr)
	if err != nil {
		msg := fmt.Errorf("t.CreateBundle: unable to validate bundleIn: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if !isValid {
		msg := fmt.Errorf("t.CreateBundle: bundleIn.DataBase64 vs. bundleIn.DataHash validation failed")
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	// endregion: validate
	// region: parse json

	var bundleIn Bundle

	err = json.Unmarshal([]byte(bundleStr), &bundleIn)
	if err != nil {
		msg := fmt.Errorf("error parsing bundle: %s (%s)", err, bundleStr)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.CreateBundle bundleStr unmarshal -> %#v", bundleIn))

	// endregion: parse json
	// region: check if exists

	exists, err := t.BundleExists(ctx, bundleIn.BundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle: %v", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if !exists {
		msg := fmt.Errorf("bundle does not exists: %v", bundleIn.BundleID)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("ledger checked, bundle does exist -> %v", bundleIn.BundleID))

	// endregion: check if exists
	// region: get original

	bundleOrig, err := t.BundleGet(ctx, bundleIn.BundleID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle %v: %v", bundleIn.BundleID, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	// endregion: get original
	// region: updated bundle

	now := time.Now()

	bundleOut := bundleIn
	bundleOut.DocType = "bundle"
	bundleOut.TxID = bundleOrig.TxID
	bundleOut.TxTimestamp = bundleOrig.TxTimestamp
	bundleOut.UpdateTxID = ctx.GetStub().GetTxID()
	bundleOut.UpdateTimestamp = now.Format(time.RFC3339)

	if bundleIn.LegacyFlag == "1" || bundleIn.ConfidentialFlag == "1" {
		bundleOut.DataBase64 = ""
	}

	bundleBytes, err := json.Marshal(bundleOut)
	if err != nil {
		msg := fmt.Errorf("failed to marshal bundle: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("bundle marshaled -> %#v", bundleOut))

	// endregion: updated bundle
	// region: bundle out

	err = ctx.GetStub().PutState(bundleOut.BundleID, bundleBytes)
	if err != nil {
		msg := fmt.Errorf("failed to put bundle: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, "world state updated with no errors")

	return &bundleOut, nil

	// endregion: bundle out

}

func (t *Chaincode) SetLogger(ctx contractapi.TransactionContextInterface, prefix, logLevel string) {

	// reset logger params
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.SetLogger queried with prefix -> %s, loglevel -> %s", prefix, logLevel))

	priority := syslog.LOG_INFO
	logLevel = strings.ToLower(logLevel)
	switch logLevel {
	case "emergency", "emerg":
		priority = syslog.LOG_EMERG
	case "alert":
		priority = syslog.LOG_ALERT
	case "critical", "crit":
		priority = syslog.LOG_CRIT
	case "error", "err":
		priority = syslog.LOG_ERR
	case "warning", "warn":
		priority = syslog.LOG_WARNING
	case "notice":
		priority = syslog.LOG_NOTICE
	case "debug":
		priority = syslog.LOG_DEBUG
	case "info":
		priority = syslog.LOG_INFO
	default:
		Logger.Out(log.LOG_ERR, fmt.Sprintf("t.SetLogger could not match %s to syslog priority, falling back to syslog.LOG_INFO", logLevel))
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.SetLogger new prefix -> %s priority -> %v", prefix, priority))

	// Logger.Close()
	Logger = *log.NewLogger()
	_, _ = Logger.NewCh(log.ChConfig{Severity: &priority, Prefix: &prefix})

}

// endregion: invokes

// endregion: functions

func main() {

	// region: init logger

	logLevel := syslog.LOG_INFO
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
