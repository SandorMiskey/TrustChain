package psv

import "fmt"

type PSV struct {
	status   string   `json:"status"`
	key      string   `json:"key"`
	txid     string   `json:"txid"`
	response string   `json:"response"`
	payload  []string `json:"payload"`
}

func Read() {
	fmt.Println("dummy")
}
