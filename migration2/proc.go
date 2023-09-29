package main

import (
	"fmt"
	"reflect"
	"strings"

	"github.com/SandorMiskey/TEx-kit/log"
)

func procBlockCacheRead(block string) (*Header, bool) {
	BlockCacheMutex.RLock()
	defer BlockCacheMutex.RUnlock()
	if header, exists := BlockCache[block]; exists {
		StatCacheHists++
		Lout(LOG_DEBUG, "cache hit", block)
		return header, true
	}
	return nil, false
}

func procBlockCacheWrite(header *Header) {
	BlockCacheMutex.Lock()
	defer BlockCacheMutex.Unlock()
	StatCacheWrites++
	Lout(LOG_DEBUG, "cache write", header.Number)
	BlockCache[header.Number] = header
}

// func procCompilePSV(psv PSV) string {
// 	v := reflect.ValueOf(psv)
// 	if v.Kind() != reflect.Struct {
// 		Lout(log.LOG_WARNING, "cannot compile item to psv", psv, v.Kind())
// 		v = reflect.ValueOf(PSV{})
// 	}

// 	var values []string
// 	for i := 0; i < v.NumField()-1; i++ {
// 		fieldValue := v.Field(i)
// 		values = append(values, fmt.Sprintf("%v", fieldValue.Interface()))
// 	}
// 	values = append(values, strings.Join(psv.Payload, "|"))

// 	return strings.Join(values, "|")
// }

func procCompilePSV(psv *PSV) string {
	// check if psv is nil or if it's not a struct pointer, then create a new *PSV if psv is invalid
	if psv == nil || reflect.TypeOf(psv).Kind() != reflect.Ptr || reflect.TypeOf(psv).Elem().Kind() != reflect.Struct {
		Lout(log.LOG_WARNING, "cannot compile item to *PSV", psv)
		psv = &PSV{}
	}
	v := reflect.ValueOf(psv)

	var values []string
	for i := 0; i < v.Elem().NumField()-1; i++ {
		fieldValue := v.Elem().Field(i)
		values = append(values, fmt.Sprintf("%v", fieldValue.Interface()))
	}
	values = append(values, strings.Join(psv.Payload, "|"))

	return strings.Join(values, "|")
}
