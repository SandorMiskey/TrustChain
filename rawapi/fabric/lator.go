// region: packages

package fabric

import (
	"encoding/base64"
	"fmt"
	"io"
	"os/exec"

	"github.com/valyala/fasthttp"
)

// endregion: packages

type exe func([]byte, string) ([]byte, error)

type Lator struct {
	Bind  string `json:"bind"`
	Port  int    `json:"port"`
	Which string `json:"which"`
	Exe   exe    `json:"-"`
}

func (l *Lator) Init() (*Lator, error) {

	// region: rest api

	if len(l.Bind) != 0 && len(l.Which) != 0 {
		bin := l.Which
		adr := fmt.Sprintf("--hostname=%s", l.Bind)
		prt := fmt.Sprintf("--port=%d", l.Port)
		cmd := exec.Command(bin, "start", adr, prt)
		err := cmd.Start()
		if err != nil {
			return nil, err
		}
		l.Exe = l.exeRest
		return l, nil
	}

	// endregion: rest api
	// region: cmd

	if len(l.Which) != 0 {
		which, err := exec.LookPath(l.Which)
		if err != nil {
			return nil, err
		}
		l.Exe = l.exeCmd
		l.Which = which
		return l, nil
	}

	// endregion: cmd
	// region: dump

	l.Exe = l.exeDump
	return l, nil

	// endregion: dump

}

func (l *Lator) exeRest(pb []byte, typ string) ([]byte, error) {
	// curl -X POST --data-binary @protofile "127.0.0.1:9999/protolator/decode/common.Block"

	url := fmt.Sprintf("http://%s:%d/protolator/decode/%s", l.Bind, l.Port, typ)

	req := fasthttp.AcquireRequest()
	defer fasthttp.ReleaseRequest(req)

	req.Header.SetMethod("POST")
	req.SetRequestURI(url)
	req.SetBody(pb)

	resp := fasthttp.AcquireResponse()
	defer fasthttp.ReleaseResponse(resp)

	client := &fasthttp.Client{}
	if err := client.Do(req, resp); err != nil {
		return nil, err
	}

	if resp.StatusCode() != fasthttp.StatusOK {
		return nil, fmt.Errorf("%s", resp.Body())
	}

	return resp.Body(), nil
}

func (l *Lator) exeCmd(pb []byte, typ string) ([]byte, error) {

	cmd := exec.Command(l.Which, "proto_decode", "--input=/dev/stdin", "--type="+typ)

	// region: io

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}

	// endregion: io
	// region: launch

	if err := cmd.Start(); err != nil {
		return nil, err
	}

	// endregion: launch
	// region: write

	// stdin.Write(resultByte)
	go func() {
		defer stdin.Close()
		stdin.Write(pb)
	}()

	// endregion: write
	// region: read

	result, err := io.ReadAll(stdout)
	if err != nil {
		return result, err
	}

	errors, err := io.ReadAll(stderr)
	if err != nil || len(errors) != 0 {
		return result, fmt.Errorf("%q: %w", errors, err)
	}

	// endregion: read
	// region: wait

	if err := cmd.Wait(); err != nil {
		return result, err
	}

	// endregion: wait

	return result, nil
}

func (l *Lator) exeDump(pb []byte, typ string) ([]byte, error) {
	encodedLength := base64.StdEncoding.EncodedLen(len(pb))
	encodedData := make([]byte, encodedLength)
	base64.StdEncoding.Encode(encodedData, pb)
	encodedData = append([]byte{'"'}, append(encodedData, '"')...)
	return encodedData, nil
}
