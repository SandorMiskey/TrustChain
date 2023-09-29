package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
)

// region: generic

func helperPanic(s ...string) {
	msg := strings.Join(s, " -> ")
	if Logger != nil {
		Lout(LOG_EMERG, msg)
	}
	fmt.Fprintln(os.Stderr, msg)
	os.Exit(1)
}

func helperUsage(fs *flag.FlagSet) func() {
	return func() {
		fmt.Println("usage:")
		if len(os.Args[1]) == 0 {
			fmt.Println("  " + os.Args[0] + " [mode] <options>")
			fmt.Println("")
			fmt.Println("modes:")

			// fmt.Printf(MODE_FORMAT, MODE_COMBINED_SC, MODE_COMBINED_FULL, MODE_COMBINED_DESC)
			// fmt.Printf(MODE_FORMAT, MODE_CONFIRM_SC, MODE_CONFIRM_FULL, MODE_CONFIRM_DESC)
			// fmt.Printf(MODE_FORMAT, MODE_CONFIRMBATCH_SC, MODE_CONFIRMBATCH_FULL, MODE_CONFIRMBATCH_DESC)
			// fmt.Printf(MODE_FORMAT, MODE_CONFIRMRAWAPI_SC, MODE_CONFIRMRAWAPI_FULL, MODE_CONFIRMRAWAPI_DESC)
			fmt.Printf(MODE_FORMAT, MODE_HELP_SC, MODE_HELP_FULL, MODE_HELP_DESC)
			fmt.Printf(MODE_FORMAT, MODE_LISTENER_SC, MODE_LISTENER_FULL, MODE_LISTENER_DESC)
			// fmt.Printf(MODE_FORMAT, MODE_RESUBMIT_SC, MODE_RESUBMIT_FULL, MODE_RESUBMIT_DESC)
			// fmt.Printf(MODE_FORMAT, MODE_SUBMIT_SC, MODE_SUBMIT_FULL, MODE_SUBMIT_DESC)
			// fmt.Printf(MODE_FORMAT, MODE_SUBMITBATCH_SC, MODE_SUBMITBATCH_FULL, MODE_SUBMITBATCH_DESC)
			fmt.Println("")
			fmt.Println("use `" + os.Args[0] + " [mode] --help` for mode specific details")
		} else {
			fmt.Println("  " + os.Args[0] + " " + os.Args[1] + " <options>")
			fmt.Println("")
			if fs != nil {
				fmt.Println("options:")
				fs.PrintDefaults()
				fmt.Println("")
				fmt.Println("Before evaluation, the file corresponding to $TC_PATH_RC is read (if it is set and the file exists) and otherwise unset variables are taken into account")
				fmt.Println("when setting some default values and parsing cli. Parameters can also be passed via env. variables, like `CHANNEL=foo` instead of '-channel=foo', order")
				fmt.Println("of precedence:")
				fmt.Println("  1. command line options")
				fmt.Println("  2. environment variables")
				fmt.Println("  3. default values")
				fmt.Println("")
			}
		}
		fmt.Println("")
	}
}

// endregion: generic
