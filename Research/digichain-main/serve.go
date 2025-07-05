package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	// Get the current working directory
	wd, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}

	// Serve files from the src folder
	http.Handle("/", http.FileServer(http.Dir(wd+string(os.PathSeparator)+"src")))

	// Start the server
	log.Println("DigiChain is being served at http://localhost:8080/")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
