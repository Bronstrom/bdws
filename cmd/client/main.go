// This file contains the main routine for clients.
package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/showalter/bdws/internal/data"
)

// The entry point of the program
func main() {

	// The command line arguments. args[0] is the name of the program.
	args := os.Args

	// If the right number of arguments weren't passed, ask for them and exit.
	if len(args) != 3 {
		fmt.Println("Please pass the address of the supervisor and a file to run.")
		fmt.Println("Example: http://stu.cs.jmu.edu:4001 fun_code.py")
		os.Exit(1)
	}

	// Get extension and file name
	fileName, extension := getFileName(args[2])

	// Code is unessesary to send if executable exists
	var code []byte
	if extension == "executable" {
		code = nil
	} else {
		// File is not an binary executable, so copy code
		// Open the file whose name was passed as an argument.
		var err error
		code, err = ioutil.ReadFile(args[2])
		if err != nil {
			fmt.Println("Error opening file. Aborting")
			os.Exit(3)
		}
	}

	// Make a job with the given code.
	jobBytes := data.JobDataToJson(1, time.Now(), 2, 1, 10, fileName, extension, code)

	// Send a post request to the supervisor.
	resp, err := http.Post(args[1]+"/newjob",
		"text/plain", bytes.NewReader(jobBytes))
	if err != nil {
		fmt.Println("Error posting job. Aborting")
		os.Exit(3)
	}

	// Put the bytes from the request into a file
	buf := new(bytes.Buffer)
	buf.ReadFrom(resp.Body)
	file := buf.String()

	fmt.Println(file)

}

/* ----- Helper functions ----- */

// Check for an error.
func check(e error) {
	if e != nil {
		panic(e)
	}
}

// Find the absolute path of a file
func findAbsolute(fileName string) string {
	var out string
	var err error

	// Check if file is in current directory
	pwd, _ := os.Getwd()

	if _, err := os.Stat(pwd + "/" + fileName); err == nil {
		return pwd + "/" + fileName
	}

	// Check if file is a binary
	out, err = exec.LookPath(fileName)

	// If file is not a binary, try to find abs path
	if err != nil || !filepath.IsAbs(out) {
		out, err = filepath.Abs(fileName)
		check(err)
	}

	// If no error return absolute path
	return out
}

// Get the filename and extension type of a file
func getFileName(arg string) (string, string) {
	abs := findAbsolute(arg)
	fmt.Println(abs)

	// Get file name
	fullPath := strings.Split(abs, "/")
	fileName := fullPath[len(fullPath)-1]

	// Find file type
	var extension string

	if strings.Contains(fileName, ".") { // file has extension
		extension = strings.Split(fileName, ".")[1]

	} else if !strings.Contains(abs, os.Getenv("HOME")) { // file is not in home dir
		extension = "executable"

	} else { // file is in home dir
		extension = "none"
	}
	return fileName, extension
}
