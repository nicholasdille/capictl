package main

import (
	"fmt"
	"os"

	"sigs.k8s.io/kind/pkg/cluster"
	"sigs.k8s.io/kind/pkg/errors"
)

func main() {
	err := test()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}

func test() error {
	provider := cluster.NewProvider()

	if err := provider.Create("foo"); err != nil {
		return errors.Wrap(err, "failed to create cluster")
	}

	return nil
}
