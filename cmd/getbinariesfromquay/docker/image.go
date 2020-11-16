package docker

import (
	"context"

	"github.com/containers/image/v5/copy"
	"github.com/containers/image/v5/manifest"
	"github.com/containers/image/v5/signature"
	"github.com/containers/image/v5/transports/alltransports"
	"github.com/containers/image/v5/types"
)

type Image struct {
	src types.ImageSource
	ref types.ImageReference
	sys *types.SystemContext
}

func ImageFromName(ctx context.Context, sys *types.SystemContext, name string) (*Image, error) {
	imageRef, err := alltransports.ParseImageName(name)
	if err != nil {
		return nil, err
	}
	src, err := imageRef.NewImageSource(ctx, sys)
	if err != nil {
		return nil, err
	}
	return &Image{
		src: src,
		ref: imageRef,
		sys: sys,
	}, nil
}

func (img *Image) GetManifest(ctx context.Context) ([]byte, string, error) {
	rawManifest, _, err := img.src.GetManifest(ctx, nil)
	if err != nil {
		return nil, "", err
	}
	return rawManifest, manifest.GuessMIMEType(rawManifest), nil
}

func (img *Image) Copy(ctx context.Context, dst string) error {
	destRef, err := alltransports.ParseImageName(dst)
	if err != nil {
		return err
	}
	pc, err := signature.NewPolicyContext(&signature.Policy{
		Default: []signature.PolicyRequirement{
			signature.NewPRInsecureAcceptAnything(),
		},
	})
	if err != nil {
		return err
	}
	_, err = copy.Image(ctx, pc, destRef, img.ref, &copy.Options{SourceCtx: img.sys})
	if err != nil {
		return err
	}
	return nil
}

type SchemaV2List struct {
	MediaType     string `json:"mediaType"`
	SchemaVersion int    `json:"schemaVersion"`
	Manifests     []struct {
		MediaType string `json:"mediaType"`
		Digest    string `json:"digest"`
		Size      int    `json:"size"`
		Platform  struct {
			Architecture string `json:"architecture"`
			Os           string `json:"os"`
			Variant      string `json:"variant"`
		} `json:"platform,omitempty"`
	} `json:"manifests"`
}
