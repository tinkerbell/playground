package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path"

	"github.com/containers/image/manifest"
	"github.com/containers/image/v5/types"
	"github.com/tinkerbell/sandbox/cmd/getbinariesfromquay/docker"
	"github.com/tinkerbell/sandbox/cmd/getbinariesfromquay/tar"
)

type Config struct {
	ProgramName  string
	OutDirectory string
	Image        string
	Binary       string
}

var config = Config{}

func init() {
	flag.StringVar(&config.ProgramName, "program", "hegel", "The name of the program you are extracing binaries for. (eg tink-worker, hegel, tink-server, tink, boots)")
	flag.StringVar(&config.OutDirectory, "out", "./out", "The directory that will be used to store the release binaries")
	flag.StringVar(&config.Image, "image", "docker://quay.io/tinkerbell/hegel", "The image you want to download binaries from. It has to be a multi stage image.")
	flag.StringVar(&config.Binary, "binary-to-copy", "/usr/bin/hegel", "The location of the binary you want to copy from inside the image.")
}

func main() {
	flag.Parse()

	println("Extracing binary: " + config.Binary)
	println("From Image: " + config.Image)

	imageR := config.Image
	binaryToCopy := config.Binary
	baseDir, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	programName := config.ProgramName
	outDir := path.Join(baseDir, config.OutDirectory)
	releaseDir := path.Join(outDir, "release")
	err = os.MkdirAll(releaseDir, 0755)
	if err != nil {
		log.Fatal(err)
	}
	println("Binaries will be located in: " + releaseDir)
	imgsDir := path.Join(outDir, "imgs")
	err = os.MkdirAll(imgsDir, 0755)
	if err != nil {
		log.Fatal(err)
	}

	ctx := context.Background()
	img, err := docker.ImageFromName(ctx, &types.SystemContext{}, imageR)
	if err != nil {
		log.Fatal(err)
	}

	rawManifest, mt, err := img.GetManifest(ctx)
	if err != nil {
		log.Fatal(err)
	}

	if mt != manifest.DockerV2ListMediaType {
		log.Fatal("manifest not supported, it is not a multi arch image")
	}

	archList := docker.SchemaV2List{}
	err = json.Unmarshal(rawManifest, &archList)
	if err != nil {
		log.Fatal(err)
	}

	for _, arch := range archList.Manifests {
		imgDir := fmt.Sprintf("%s-%s-%s", programName, arch.Platform.Os, arch.Platform.Architecture)
		println("Extracting ", imgDir)
		syss := &types.SystemContext{
			ArchitectureChoice: arch.Platform.Architecture,
			OSChoice:           arch.Platform.Os,
		}
		if arch.Platform.Variant != "" {
			syss.VariantChoice = arch.Platform.Variant
			imgDir = imgDir + arch.Platform.Variant
		}
		archImg, err := docker.ImageFromName(ctx, syss, imageR)
		if err != nil {
			log.Fatal(err)
		}
		err = archImg.Copy(ctx, fmt.Sprintf("dir:%s", path.Join(imgsDir, imgDir)))
		if err != nil {
			log.Fatal(err)
		}
		err = untarLayers(path.Join(imgsDir, imgDir), path.Join(releaseDir, imgDir), binaryToCopy)
		if err != nil {
			log.Fatal(err)
		}
	}
}

func untarLayers(src, dest, binaryPath string) error {
	b, err := ioutil.ReadFile(path.Join(src, "manifest.json"))
	if err != nil {
		return err
	}
	man, err := manifest.FromBlob(b, manifest.DockerV2Schema2MediaType)
	if err != nil {
		return err
	}
	for _, l := range man.LayerInfos() {
		layerTar, err := os.Open(path.Join(src, l.Digest.String()[7:]))
		if err != nil {
			return err
		}
		err = tar.Untar(src, layerTar)
		if err != nil {
			return err
		}
	}

	input, err := ioutil.ReadFile(path.Join(src, binaryPath))
	if err != nil {
		return err
	}

	err = ioutil.WriteFile(dest, input, 0755)
	if err != nil {
		return err
	}
	return nil
}
