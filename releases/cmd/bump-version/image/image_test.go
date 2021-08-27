package image_test

import (
	"errors"
	"fmt"
	"testing"

	"github.com/tinkerbell/sandbox/cmd/bump-version/image"
)

func TestTagFromSha(t *testing.T) {
	s := []struct {
		Err    error
		Commit string
		Tag    string
	}{
		{
			Commit: "a7e947efc194fb0375f88cccc67f2fde5e0c85c1",
			Tag:    "sha-a7e947ef",
		},
		{
			Commit: "0",
			Err:    image.ErrCommitTooShort,
		},
	}

	for _, v := range s {
		t.Run(fmt.Sprintf("%s -> %s", v.Commit, v.Tag), func(t *testing.T) {
			tag, err := image.TagFromSha(v.Commit)
			errors.Is(err, v.Err)
			if v.Err != err {
				t.Error(err)
			}
			if tag != v.Tag {
				t.Errorf("expected %s got %s", v.Tag, tag)
			}
		})
	}
}
