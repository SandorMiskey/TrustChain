package fabric

import (
	"encoding/base64"
	"fmt"
	"io"
	"math/rand"
	"net"
	"os/exec"
	"strconv"
	"time"

	"github.com/valyala/fasthttp"
)

func (l *Lator) Init() error {

	// region: rest api

	if len(l.Bind) != 0 && len(l.Which) != 0 {
		if l.Port == 0 {
			rand.Seed(time.Now().UnixNano())
			min := 1024
			max := 65534
			for {
				l.Port = rand.Intn(max-min+1) + min
				conn, err := net.Dial("tcp", "localhost:"+strconv.Itoa(l.Port))
				if err != nil {
					// port is likely not in use
					break
				}
				conn.Close()
			}
		}

		bin := l.Which
		adr := fmt.Sprintf("--hostname=%s", l.Bind)
		prt := fmt.Sprintf("--port=%d", l.Port)
		cmd := exec.Command(bin, "start", adr, prt)
		err := cmd.Start()
		if err != nil {
			return err
		}

		l.client = &fasthttp.Client{}
		l.cmd = cmd
		l.Exe = l.exeRest
		return nil
	}

	// endregion: rest api
	// region: cmd

	if len(l.Which) != 0 {
		which, err := exec.LookPath(l.Which)
		if err != nil {
			return err
		}
		l.Exe = l.exeCmd
		l.Which = which
		return nil
	}

	// endregion: cmd
	// region: dump

	l.Exe = l.exeDump
	return nil

	// endregion: dump

}

func (l *Lator) Close() {
	if l.cmd != nil {
		defer l.cmd.Process.Kill()
	}
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

	if err := l.client.Do(req, resp); err != nil {
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
	// encodedData = append([]byte{'"'}, append(encodedData, '"')...)
	return encodedData, nil
}
