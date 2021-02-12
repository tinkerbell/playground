package image

import "fmt"

var ErrCommitTooShort = fmt.Errorf("commit to short, it needs at least 8 characters")

type Image struct {
	name string
}

// TagFromSha returns an image tag from a commit sha following the
// convention we have in Tinkerbell
// Commit: a7e947efc194fb0375f88cccc67f2fde5e0c85c1
//    -> Tag: sha-a7e947ef
func TagFromSha(commit string) (string, error) {
	if len(commit) < 8 {
		return "", ErrCommitTooShort
	}
	return "sha-" + commit[0:8], nil
}

func NewImage(name string) *Image {
	return &Image{name: name}
}
