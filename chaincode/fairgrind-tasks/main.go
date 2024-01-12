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

type Task struct {
	AdminID            string      `json:"admin_id"`
	Confidential       string      `json:"confidential"`
	GrinderID          string      `json:"grinder_id"`
	DocType            string      `json:"doc_type"` //docType is used to distinguish the various types of objects in state database
	NumberOfOperations int16       `json:"number_of_operations"`
	ProductBase64      string      `json:"product_base64"`
	ProductHash        string      `json:"product_hash"`
	ProjectID          string      `json:"project_id"`
	RawID              string      `json:"raw_id"`
	RelatedTxID        []string    `json:"related_tx_id"`
	TaskID             string      `json:"task_id"`
	TaskStatusID       string      `json:"task_status_id"`
	TaskTypeID         string      `json:"task_type_id"`
	TxID               string      `json:"tx_id"`
	TxTimestamp        string      `json:"tx_timestamp"`
	UpdateTxID         interface{} `json:"update_tx_id"`
	UpdateTimestamp    interface{} `json:"update_timestamp"`
}

// HistoryQueryResult structure used for returning result of history query
type HistoryQueryResult struct {
	Record    *Task     `json:"record"`
	TxID      string    `json:"tx_id"`
	Timestamp time.Time `json:"timestamp"`
	IsDelete  bool      `json:"isDelete"`
}

// PaginatedQueryResult structure used for returning paginated query results and metadata
type PaginatedQueryResult struct {
	Records             []*Task `json:"records"`
	FetchedRecordsCount int32   `json:"fetched_records_count"`
	Bookmark            string  `json:"bookmark"`
}

// endregion: types and globals
// region: functions

// region: helpers

func constructQueryResponseFromIterator(resultsIterator shim.StateQueryIteratorInterface) ([]*Task, error) {

	// constructQueryResponseFromIterator constructs a slice of bundles from the resultsIterator
	Logger.Out(log.LOG_DEBUG, "constructQueryResponseFromIterator helper in action")

	var bundles []*Task
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			msg := fmt.Errorf("error in constructQueryResponseFromIterator when resultsIterator.Next(): %s", err)
			Logger.Out(log.LOG_ERR, msg)
			return nil, msg
		}
		var task Task
		err = json.Unmarshal(queryResult.Value, &task)
		if err != nil {
			msg := fmt.Errorf("error in constructQueryResponseFromIterator when json.Unmarshal(queryResult.Value, &bundle): %s", err)
			Logger.Out(log.LOG_ERR, msg)
			return nil, msg
		}
		bundles = append(bundles, &task)
	}

	return bundles, nil
}

func getQueryResultForQueryString(ctx contractapi.TransactionContextInterface, queryString string) ([]*Task, error) {

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

func (t *Chaincode) Exists(ctx contractapi.TransactionContextInterface, taskID string) (bool, error) {

	// returns true when bundle with given ID exists in the ledger

	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.BundleExists queried with -> %s", taskID))

	taskBytes, err := ctx.GetStub().GetState(taskID)
	if err != nil {
		msg := fmt.Errorf("failed to read task %s from world state. %v", taskID, err)
		Logger.Out(log.LOG_ERR, msg)
		return false, msg
	}
	return taskBytes != nil, nil
}

func (t *Chaincode) History(ctx contractapi.TransactionContextInterface, taskID string) ([]HistoryQueryResult, error) {

	// returns the chain of custody for a task since issuance

	Logger.Out(log.LOG_DEBUG, "t.History queried", taskID)

	// iterator
	resultsIterator, err := ctx.GetStub().GetHistoryForKey(taskID)
	if err != nil {
		msg := fmt.Errorf("error in t.History when ctx.GetStub().GetHistoryForKey(%v) queried: %s", taskID, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	defer resultsIterator.Close()
	Logger.Out(log.LOG_DEBUG, "t.History got iterator")

	// iterate on history
	var records []HistoryQueryResult
	for resultsIterator.HasNext() {

		// read record
		response, err := resultsIterator.Next()
		if err != nil {
			msg := fmt.Errorf("error in t.History when resultsIterator.Next() invoked: %s", err)
			Logger.Out(log.LOG_ERR, msg)
			return nil, msg
		}
		Logger.Out(log.LOG_DEBUG, "t.History new record read")

		// validate record
		var task Task
		if len(response.Value) > 0 {
			err = json.Unmarshal(response.Value, &task)
			if err != nil {
				msg := fmt.Errorf("unable to unmarshal task (%s) in t.History: %s", response.Value, err)
				Logger.Out(log.LOG_ERR, msg)
				return nil, msg
			}
		} else {
			task = Task{
				TaskID: taskID,
			}
		}
		Logger.Out(log.LOG_DEBUG, "t.History valid record")

		// check timestamp
		err = response.Timestamp.CheckValid()
		if err != nil {
			msg := fmt.Errorf("unable to parse timestamp (%s) in t.History: %s", response.Timestamp, err)
			Logger.Out(log.LOG_ERR, msg)
			return nil, msg
		}
		Logger.Out(log.LOG_DEBUG, "t.History valid timestamp")

		// set record
		record := HistoryQueryResult{
			TxID:      response.TxId,
			Timestamp: response.Timestamp.AsTime(),
			Record:    &task,
			IsDelete:  response.IsDelete,
		}
		records = append(records, record)
		Logger.Out(log.LOG_DEBUG, "t.History new record")

	}

	return records, nil
}

func (t *Chaincode) Get(ctx contractapi.TransactionContextInterface, taskID string) (*Task, error) {

	// retrieves a task from the ledger

	Logger.Out(log.LOG_DEBUG, "t.Get queried with", taskID)

	taskBytes, err := ctx.GetStub().GetState(taskID)
	if err != nil {
		msg := fmt.Errorf("failed to get bundle %s: %v", taskID, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if taskBytes == nil {
		msg := fmt.Errorf("t.Get says bundle %s does not exist", taskID)
		Logger.Out(log.LOG_INFO, msg)
		return nil, msg
	}

	var task Task
	err = json.Unmarshal(taskBytes, &task)
	if err != nil {
		msg := fmt.Errorf("failed to json unmarshal bundle %s: %v ", taskID, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	return &task, nil
}

func (t *Chaincode) GetRange(ctx contractapi.TransactionContextInterface, startKey, endKey string) ([]*Task, error) {

	// retrieves range of tasks from the ledger

	Logger.Out(log.LOG_DEBUG, "t.GetRange queried", startKey, endKey)

	resultsIterator, err := ctx.GetStub().GetStateByRange(startKey, endKey)
	if err != nil {
		msg := fmt.Errorf("error in t.GetRange while ctx.GetStub().GetStateByRange(%s, %s): %v", startKey, endKey, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	defer resultsIterator.Close()

	return constructQueryResponseFromIterator(resultsIterator)
}

func (t *Chaincode) GetRangeWithPagination(ctx contractapi.TransactionContextInterface, startKey string, endKey string, pageSize int, bookmark string) (*PaginatedQueryResult, error) {

	// GetRangeWithPagination performs a range query based on the start and end key,
	// page size and a bookmark. The number of fetched records will be equal to or lesser
	// than the page size. Paginated range queries are only valid for read only transactions.

	Logger.Out(log.LOG_DEBUG, "t.GetRangeWithPagination queried with startKey", startKey, endKey, pageSize, bookmark)

	resultsIterator, responseMetadata, err := ctx.GetStub().GetStateByRangeWithPagination(startKey, endKey, int32(pageSize), bookmark)
	if err != nil {
		msg := fmt.Errorf("error in t.GetRangeWithPagination while ctx.GetStub().GetStateByRangeWithPagination(%s, %s, %v, %s): %s", startKey, endKey, pageSize, bookmark, err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	defer resultsIterator.Close()

	tasks, err := constructQueryResponseFromIterator(resultsIterator)
	if err != nil {
		msg := fmt.Errorf("error in t.GetRangeWithPagination while constructQueryResponseFromIterator(): %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	return &PaginatedQueryResult{
		Records:             tasks,
		FetchedRecordsCount: responseMetadata.FetchedRecordsCount,
		Bookmark:            responseMetadata.Bookmark,
	}, nil
}

func (t *Chaincode) Query(ctx contractapi.TransactionContextInterface, queryString string) ([]*Task, error) {

	// Query uses a query string to perform a query for tasks. Query
	// string matching state database syntax is passed in and executed as is.
	// Supports ad hoc queries that can be defined at runtime by the client.

	Logger.Out(log.LOG_DEBUG, "t.Query queried", queryString)
	return getQueryResultForQueryString(ctx, queryString)
}

func (t *Chaincode) QueryWithPagination(ctx contractapi.TransactionContextInterface, queryString string, pageSize int, bookmark string) (*PaginatedQueryResult, error) {

	// QueryWithPagination uses a query string, page size and a bookmark to perform a query
	// for tasks. Query string matching state database syntax is passed in and executed as is.
	// The number of fetched records would be equal to or lesser than the specified page size.
	// Supports ad hoc queries that can be defined at runtime by the client. Only available on
	// state databases that support rich query (e.g. CouchDB). Paginated queries are only valid
	// for read only transactions.

	Logger.Out(log.LOG_DEBUG, "t.QueryWithPagination queried", queryString, pageSize, bookmark)
	return getQueryResultForQueryStringWithPagination(ctx, queryString, int32(pageSize), bookmark)
}

func (t *Chaincode) Validate(ctx contractapi.TransactionContextInterface, taskStr string) (bool, error) {

	// BundleValidate validates bundle.DataHash against computed from bundle.DataBase64
	Logger.Out(log.LOG_DEBUG, "t.BundleValidate invoked with", taskStr)

	// region: parse json

	var taskIn Task

	err := json.Unmarshal([]byte(taskStr), &taskIn)
	if err != nil {
		msg := fmt.Errorf("t.Validate: error parsing bundle: %s (%s)", err, taskStr)
		Logger.Out(log.LOG_ERR, msg)
		return false, msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("t.Validate: taskStr unmarshal -> %#v", taskIn))

	// endregion: parse json
	// region: decode the base64 encoded string

	taskIn.ProductBase64 = strings.Replace(taskIn.ProductBase64, " ", "+", -1)

	decodedBytes, err := base64.StdEncoding.DecodeString(taskIn.ProductBase64)
	if err != nil {
		msg := fmt.Errorf("t.Validate: unable to decode taskIn.ProductBase64: %s (%s)", err, taskIn.ProductBase64)
		Logger.Out(log.LOG_ERR, msg)
		return false, msg
	}

	// endregion: decode
	// region: compute the SHA256 hash

	hashBytes := sha256.Sum256(decodedBytes)
	hashString := hex.EncodeToString(hashBytes[:])

	// compare
	if taskIn.ProductHash != hashString {
		Logger.Out(log.LOG_DEBUG, "t.Validate: taskIn.ProductHash != hashString", taskIn.ProductHash, hashString)
		return false, nil
	}
	Logger.Out(log.LOG_DEBUG, "t.Validate: taskIn.ProductHash == hashString", taskIn.ProductHash, hashString)
	return true, nil

	// endregion: compute

}

// endregion: queries
// region: invokes

func (t *Chaincode) Register(ctx contractapi.TransactionContextInterface, taskStr string) (*Task, error) {

	// initializes a new task in the ledger

	Logger.Out(log.LOG_DEBUG, "t.Register invoked with", taskStr)

	// region: validate

	isValid, err := t.Validate(ctx, taskStr)
	if err != nil {
		msg := fmt.Errorf("t.Register: unable to validate taskIn: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if !isValid {
		msg := fmt.Errorf("t.Register: taskIn.ProductBase64 vs. taskIn.ProductHash validation failed")
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	// endregion: validate
	// region: parse json

	var taskIn Task

	err = json.Unmarshal([]byte(taskStr), &taskIn)
	if err != nil {
		msg := fmt.Errorf("t.Register: error parsing bundle: %s (%s)", err, taskStr)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, "t.Register: bundleStr unmarshal", taskIn)

	// endregion: parse json
	// region: check if exists

	exists, err := t.Exists(ctx, taskIn.TaskID)
	if err != nil {
		msg := fmt.Errorf("failed to get task: %v", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if exists {
		msg := fmt.Errorf("task already exists: %v", taskIn.TaskID)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, "ledger checked, bundle does not exist yet", taskIn.TaskID)

	// endregion: check if exists
	// region: bundle out

	now := time.Now()
	stub := ctx.GetStub()

	taskOut := taskIn
	taskOut.DocType = "task"
	taskOut.TxID = stub.GetTxID()
	// bundleOut.TxTimestamp = now.Format(time.RFC3339)
	taskOut.TxTimestamp = now.Format("2006-01-02T15:04:00Z")
	taskOut.UpdateTxID = nil
	taskOut.UpdateTimestamp = nil

	if taskIn.Confidential == "1" {
		taskOut.ProductBase64 = ""
	}

	taskBytes, err := json.Marshal(taskOut)
	if err != nil {
		msg := fmt.Errorf("failed to marshal task: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, "task marshaled", taskOut)

	err = stub.PutState(taskOut.TaskID, taskBytes)
	if err != nil {
		msg := fmt.Errorf("failed to put task: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, "world state updated with no errors")

	err = stub.SetEvent("Register", taskBytes)
	if err != nil {
		return nil, err
	}

	return &taskOut, nil

	// endregion: bundle out

}

func (t *Chaincode) Delete(ctx contractapi.TransactionContextInterface, taskID string) error {

	// removes an asset key-value pair from the ledger
	Logger.Out(log.LOG_DEBUG, "t.Delete invoked with", taskID)

	_, err := t.Get(ctx, taskID)
	if err != nil {
		msg := fmt.Errorf("failed to get task %s in t.Delete: %v", taskID, err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	err = ctx.GetStub().DelState(taskID)
	if err != nil {
		msg := fmt.Errorf("failed to delete task %s: %v", taskID, err)
		Logger.Out(log.LOG_ERR, msg)
		return msg
	}
	return nil
}

func (t *Chaincode) Update(ctx contractapi.TransactionContextInterface, taskStr string) (*Task, error) {

	// reset task except tx_id and timestamps

	Logger.Out(log.LOG_DEBUG, "t.UpdateBundleById invoked with", taskStr)

	// region: validate

	isValid, err := t.Validate(ctx, taskStr)
	if err != nil {
		msg := fmt.Errorf("t.Update: unable to validate task: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if !isValid {
		msg := fmt.Errorf("t.Update: validation failed")
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}

	// endregion: validate
	// region: parse json

	var taskIn Task

	err = json.Unmarshal([]byte(taskStr), &taskIn)
	if err != nil {
		msg := fmt.Errorf("error parsing task: %s (%s)", err, taskStr)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, "t.Update taskStr unmarshal", taskIn)

	// endregion: parse json
	// region: check if exists, get original

	taskOrig, err := t.Get(ctx, taskIn.TaskID)
	if err != nil {
		msg := fmt.Errorf("failed to get task: %v", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	if taskOrig == nil {
		msg := fmt.Errorf("failed to get task: %v", taskIn.TaskID)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, fmt.Sprintf("ledger checked, bundle does exist -> %v", taskIn.TaskID))

	// endregion: check if exists
	// region: updated bundle

	now := time.Now()

	taskOut := taskIn
	taskOut.DocType = "task"
	taskOut.TxID = taskOrig.TxID
	taskOut.TxTimestamp = taskOrig.TxTimestamp
	taskOut.UpdateTxID = ctx.GetStub().GetTxID()
	// taskOut.UpdateTimestamp = now.Format(time.RFC3339)
	taskOut.UpdateTimestamp = now.Format("2006-01-02T15:04:00Z")

	if taskIn.Confidential == "1" {
		taskOut.ProductBase64 = ""
	}

	taskBytes, err := json.Marshal(taskOut)
	if err != nil {
		msg := fmt.Errorf("failed to marshal task: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, "bundle marshaled", taskOut)

	// endregion: updated bundle
	// region: bundle out

	err = ctx.GetStub().PutState(taskOut.TaskID, taskBytes)
	if err != nil {
		msg := fmt.Errorf("failed to put task: %s", err)
		Logger.Out(log.LOG_ERR, msg)
		return nil, msg
	}
	Logger.Out(log.LOG_DEBUG, "world state updated with no errors")

	return &taskOut, nil

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
		Logger.Out(log.LOG_EMERG, "error creating chaincode", err)
	}
	if err := chaincode.Start(); err != nil {
		Logger.Out(log.LOG_EMERG, "error starting chaincode", err)
	}
}
