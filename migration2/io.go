package main

import (
	"errors"
	"os"
	"path/filepath"
	"time"
)

func ioOutputAppend(f *os.File, psv *PSV, fn Compiler) {
	line := fn(psv)
	_, err := f.WriteString(line + "\n")
	if err != nil {
		helperPanic("error appending line to file", err.Error(), f.Name(), line)
	}
}

func ioOutputOpen(f string) *os.File {

	var osFile *os.File

	// region: stdout

	if len(f) == 0 {
		Lout(LOG_INFO, "writing stdout")
		f = "/dev/stdout"
	}

	// endregion: stdout
	// region: does not file exists

	if _, err := os.Stat(f); os.IsNotExist(err) {
		Lout(LOG_INFO, "creating new file", f)
		osFile, err = os.Create(f)
		if err != nil {
			helperPanic("cannot create output file", f, err.Error())
		}
		return osFile
	}

	// endregion: file exists
	// region: open file

	osFile, err := os.OpenFile(f, os.O_APPEND|os.O_WRONLY, os.ModeAppend)
	Lout(LOG_DEBUG, "output file opened for appending", f)
	if err != nil {
		helperPanic("cannot open file, for appending", f, err.Error())
	}
	return osFile

	// endregion: open file

}

func ioTimestamp(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return errors.New("unable to timestamp not regular file")
	}

	timestamp := time.Now().Format("060102_1504_")
	basename := filepath.Base(path)
	prefixed := timestamp + basename

	err = os.Rename(path, filepath.Join(filepath.Dir(path), prefixed))
	if err != nil {
		return errors.New("error renaming the file: " + err.Error())
	}
	return nil
}
