package runner

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// fakeGHCR serves enough of the registry API to resolve a version: a pull
// token, a tag listing per repository, and a digest per tag.
func fakeGHCR(t *testing.T, tags map[string][]string, digests map[string]string) *registry {
	t.Helper()

	mux := http.NewServeMux()
	mux.HandleFunc("/token", func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]string{"token": "anonymous"})
	})
	mux.HandleFunc("/v2/", func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, "/v2/")

		if repo, ok := strings.CutSuffix(path, "/tags/list"); ok {
			_ = json.NewEncoder(w).Encode(map[string]any{"tags": tags[repo]})
			return
		}

		repo, ref, ok := strings.Cut(path, "/manifests/")
		if !ok {
			http.NotFound(w, r)
			return
		}
		digest, ok := digests[repo+":"+ref]
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Docker-Content-Digest", digest)
	})

	server := httptest.NewServer(mux)
	t.Cleanup(server.Close)

	reg := newRegistry()
	reg.base = server.URL
	return reg
}

func TestLatestChartVersion(t *testing.T) {
	const newest = "sha256:aaaa"

	tags := map[string][]string{
		tinkerbellImageRepo: {"v0.25.0", "v0.25.1-733792cc", "latest", "v0.25.1-6e7d2775"},
	}
	digests := map[string]string{
		tinkerbellImageRepo + ":latest":           newest,
		tinkerbellImageRepo + ":v0.25.1-6e7d2775": newest,
		tinkerbellImageRepo + ":v0.25.1-733792cc": "sha256:bbbb",
		tinkerbellImageRepo + ":v0.25.0":          "sha256:cccc",
		tinkerbellChartRepo + ":v0.25.1-6e7d2775": "sha256:dddd",
	}

	got, err := fakeGHCR(t, tags, digests).latestChartVersion(context.Background())
	if err != nil {
		t.Fatalf("resolving: %v", err)
	}
	if got != "v0.25.1-6e7d2775" {
		t.Errorf("version = %q, want v0.25.1-6e7d2775", got)
	}
}

// The tag listing is walked newest-last, so an ordering GHCR does not promise
// must not change the answer, only how long it takes to reach it.
func TestLatestChartVersionIgnoresTagOrder(t *testing.T) {
	const newest = "sha256:aaaa"

	tags := map[string][]string{
		tinkerbellImageRepo: {"v0.25.1-6e7d2775", "v0.25.1-733792cc", "v0.25.0"},
	}
	digests := map[string]string{
		tinkerbellImageRepo + ":latest":           newest,
		tinkerbellImageRepo + ":v0.25.1-6e7d2775": newest,
		tinkerbellImageRepo + ":v0.25.1-733792cc": "sha256:bbbb",
		tinkerbellImageRepo + ":v0.25.0":          "sha256:cccc",
		tinkerbellChartRepo + ":v0.25.1-6e7d2775": "sha256:dddd",
	}

	got, err := fakeGHCR(t, tags, digests).latestChartVersion(context.Background())
	if err != nil {
		t.Fatalf("resolving: %v", err)
	}
	if got != "v0.25.1-6e7d2775" {
		t.Errorf("version = %q, want v0.25.1-6e7d2775", got)
	}
}

// The images get their tags before the chart does, so a run dispatched in that
// window has to be told rather than left to fail during helm install.
func TestLatestChartVersionChartNotPublishedYet(t *testing.T) {
	const newest = "sha256:aaaa"

	tags := map[string][]string{
		tinkerbellImageRepo: {"v0.25.1-6e7d2775"},
	}
	digests := map[string]string{
		tinkerbellImageRepo + ":latest":           newest,
		tinkerbellImageRepo + ":v0.25.1-6e7d2775": newest,
	}

	_, err := fakeGHCR(t, tags, digests).latestChartVersion(context.Background())
	if err == nil {
		t.Fatal("expected an error naming the missing chart")
	}
	if !strings.Contains(err.Error(), "not published yet") {
		t.Errorf("error = %v", err)
	}
}

func TestChartVersionPrefersTheFlag(t *testing.T) {
	r := newTestRunner()
	r.Opts.ChartVersion = "v0.25.0"

	got, err := r.chartVersion()
	if err != nil {
		t.Fatalf("chartVersion: %v", err)
	}
	if got != "v0.25.0" {
		t.Errorf("version = %q, want v0.25.0", got)
	}
}

// A source build produces the chart, so there is nothing to resolve and no
// reason to reach the network for it.
func TestChartVersionSkippedForSourceBuilds(t *testing.T) {
	r := newTestRunner()
	r.Opts.TinkerbellRef = "main"

	got, err := r.chartVersion()
	if err != nil {
		t.Fatalf("chartVersion: %v", err)
	}
	if got != "" {
		t.Errorf("version = %q, want empty", got)
	}
}
