package main

import (
	"context"
	"encoding/json"
	"math"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/SandorMiskey/TEx-kit/cfg"
	"github.com/buger/jsonparser"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	// "github.com/hyperledger/fabric-protos-go-apiv2/common"
	// "google.golang.org/protobuf/proto"
)

func modeListener(c *cfg.Config) {

	// region: output

	path := c.Entries[OPT_IO_OUTPUT].Value.(string)
	output := ioOutputOpen(path)
	defer output.Close()

	// endregion: output
	// region: fabric client

	fabric := fabricClient(c)
	network := fabricNetwork(c, fabric)
	defer fabric.Close()

	// endregion: fabric
	// region: checkpoint, ctx

	// TODO: load/save checkpointer

	checkpointer := new(client.InMemoryCheckpointer)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// endregion: checkpoint, ctx
	// region: prepare for sigint

	var wg sync.WaitGroup

	cleanupCh := make(chan struct{})
	interruptCh := make(chan os.Signal, 1)

	signal.Notify(interruptCh, os.Interrupt, syscall.SIGTERM)

	// endregion: prepare for sigint
	// region: block events

	blockCnt := 0
	blockErr := 0

	wg.Add(1)
	go func() {
		defer wg.Done()
		Lout(LOG_INFO, "block event listener started")

		blockEvents, err := network.BlockEvents(
			ctx,
			// client.WithStartBlock(3605), // ignored if the checkpointer has checkpoint state
			// client.WithCheckpoint(checkpointer),
		)
		if err != nil {
			helperPanic(err.Error())
		}

		for {
			select {
			case <-cleanupCh:
				Lout(LOG_NOTICE, "block event listener is closing")
				return
			case event := <-blockEvents:
				blockCnt++

				header, err := json.Marshal(event.GetHeader())
				if err != nil {
					blockErr++
					Lout(LOG_ERR, "unable to parse block header", err)
					continue
				}

				var data_hash string
				var previous_hash string
				jsonparser.EachKey(header, func(idx int, value []byte, vt jsonparser.ValueType, errEachKey error) {
					switch idx {
					case 0:
						err = errEachKey
						if err == nil {
							data_hash = string(value)
						}
					case 1:
						err = errEachKey
						if err == nil {
							previous_hash = string(value)
						}
					}
				}, []string{"data_hash"}, []string{"previous_hash"})
				if err != nil {
					blockErr++
					Lout(LOG_ERR, "unable to parse block header details", err)
					continue
				}

				procBlockCacheWrite(&Header{
					DataHash:     data_hash,
					Length:       len(event.GetData().GetData()),
					Number:       strconv.FormatUint(event.GetHeader().GetNumber(), 10),
					PreviousHash: previous_hash,
					Timestamp:    time.Now().Format(time.RFC3339),
				})
				checkpointer.CheckpointBlock(event.GetHeader().GetNumber())
				Lout(LOG_DEBUG, "block event", blockCnt, string(header))
			}
		}
	}()

	// endregion: block events
	// region: chaincode events

	chCache := make(map[string]*PSV)
	chCacheMutex := sync.RWMutex{}
	chCnt := 0
	chErr := 0

	wg.Add(1)
	go func() {
		defer wg.Done()
		Lout(LOG_INFO, "chaincode event listener started")

		chEvents, err := network.ChaincodeEvents(
			ctx,
			c.Entries[OPT_FAB_CC].Value.(string),
			// client.WithStartBlock(3605), // ignored if the checkpointer has checkpoint state
			// client.WithCheckpoint(checkpointer),
		)
		if err != nil {
			helperPanic(err.Error())
		}

		for {
			select {
			case <-cleanupCh:
				Lout(LOG_NOTICE, "chaincode event listener is closing")

				return
			case event := <-chEvents:
				chCnt++

				var tx_id string
				var bundle_id string
				jsonparser.EachKey(event.Payload, func(idx int, value []byte, vt jsonparser.ValueType, errEachKey error) {
					switch idx {
					case 0:
						err = errEachKey
						if err == nil {
							tx_id = string(value)
						}
					case 1:
						err = errEachKey
						if err == nil {
							bundle_id = string(value)
						}
					}
				}, []string{"tx_id"}, []string{"bundle_id"})
				if err != nil {
					chErr++
					Lout(LOG_ERR, "unable to parse chaincode event payload details", err)
					continue
				}

				chCacheMutex.Lock()
				chCache[tx_id] = &PSV{
					Txid:     tx_id,
					Status:   STATUS_CONFIRM_PENDIG,
					Key:      bundle_id,
					Payload:  []string{string(event.Payload)},
					Response: strconv.FormatUint(event.BlockNumber, 10),
				}
				chCacheMutex.Unlock()
				checkpointer.CheckpointChaincodeEvent(event)
				Lout(LOG_DEBUG, "chaincode event", chCnt, chCache[tx_id])
			}
		}
	}()

	// endregion: chaincode events
	// region: match block and chaincode events

	wg.Add(1)
	go func() {
		defer wg.Done()
		Lout(LOG_INFO, "event matching started")

		for {
			select {
			case <-cleanupCh:
				Lout(LOG_NOTICE, "event matching is closing")
				return
			default:
				chCacheMutex.Lock()
				for tx_id := range chCache {
					if chCache[tx_id].Status != STATUS_CONFIRM_PENDIG {
						continue
					}
					if !TxRegexp.MatchString(tx_id) {
						chCache[tx_id].Status = STATUS_CONFIRM_ERROR_TXID
						Lout(LOG_ERR, "invalid txid", chCache[tx_id])
						ioOutputAppend(output, chCache[tx_id], procCompilePSV)
						delete(chCache, tx_id)
						continue
					}
					if block, exists := procBlockCacheRead(chCache[tx_id].Response); exists {
						header, err := json.Marshal(block)
						if err != nil {
							chCache[tx_id].Response = err.Error()
							chCache[tx_id].Status = STATUS_CONFIRM_ERROR_HEADER
							Lout(LOG_ERR, "unable to parse blockheader while matching events", err)
							ioOutputAppend(output, chCache[tx_id], procCompilePSV)
							delete(chCache, tx_id)
							continue
						}
						chCache[tx_id].Response = string(header)
						chCache[tx_id].Status = STATUS_CONFIRM_OK
						ioOutputAppend(output, chCache[tx_id], procCompilePSV)
						delete(chCache, tx_id)
						Lout(LOG_DEBUG, "matched events", chCache[tx_id])
					}
				}
				chCacheMutex.Unlock()
			}
		}
	}()

	// endregion: match
	// region: purge

	wg.Add(1)
	go func() {
		defer wg.Done()
		Lout(LOG_INFO, "block cache purger started")

		for {
			select {
			case <-cleanupCh:
				Lout(LOG_NOTICE, "block cache purger is closing")
				return
			default:
				chCacheMutex.Lock()
				if len(BlockCache) > c.Entries[OPT_IO_BUFFER].Value.(int) {
					min := math.MaxInt

					var purged string
					for key, header := range BlockCache {
						num, err := strconv.Atoi(header.Number)
						if err != nil {
							Lout(LOG_ERR, "block number is NaN")
							delete(BlockCache, key)
							continue
						}
						if num < min {
							min = num
							purged = key
						}
					}
					delete(BlockCache, purged)
				}
				chCacheMutex.Unlock()
			}
		}
	}()

	// endregion: purge
	// region: status

	interval := c.Entries[OPT_PROC_INTERVAL].Value.(time.Duration)
	if interval != 0 {
		go func() {
			for {
				time.Sleep(interval)
				Lout(LOG_NOTICE, "=== listener status ===")

				Lout(LOG_NOTICE, "cached block headers:             ", blockCnt)
				Lout(LOG_NOTICE, "purged block headers:             ", blockCnt-len(BlockCache))
				Lout(LOG_NOTICE, "length of block cache:            ", len(BlockCache))
				Lout(LOG_NOTICE, "block event caching errors:       ", blockErr)

				Lout(LOG_NOTICE, "all buffered chaincode events:    ", chCnt)
				Lout(LOG_NOTICE, "purged chaincode events:          ", chCnt-len(chCache))
				Lout(LOG_NOTICE, "length of chaincode event buffer: ", len(chCache))
				Lout(LOG_NOTICE, "chaincode event buffering errors: ", chErr)
			}
		}()
	}

	// endregion: status
	// region: signals

	<-interruptCh
	Lout(LOG_NOTICE, "received interupt signal, initiating cleanup")
	close(cleanupCh)
	wg.Wait()
	for tx_id := range chCache {
		ioOutputAppend(output, chCache[tx_id], procCompilePSV)
	}
	if c.Entries[OPT_IO_TIMESTAMP].Value.(bool) {
		output.Close()
		err := ioTimestamp(path)
		if err != nil {
			Lout(LOG_ERR, err)
		}
	}
	Lout(LOG_NOTICE, "cleanup complete")

	// endregion: signals

}
