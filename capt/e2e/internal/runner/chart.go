package runner

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	ghcrHost = "ghcr.io"

	// A push to tinkerbell's main publishes all three of these under one
	// version. Only the images also carry `latest`.
	tinkerbellImageRepo = "tinkerbell/tinkerbell"
	tinkerbellChartRepo = "tinkerbell/charts/tinkerbell"

	// Bounds the walk below if GHCR ever stops listing tags in push order.
	maxVersionLookups = 50
)

// Releases are vX.Y.Z; every other push is that plus the short commit.
var versionTag = regexp.MustCompile(`^v\d+\.\d+\.\d+(-[0-9a-f]{7,40})?$`)

var manifestAccept = strings.Join([]string{
	"application/vnd.oci.image.index.v1+json",
	"application/vnd.oci.image.manifest.v1+json",
	"application/vnd.docker.distribution.manifest.list.v2+json",
	"application/vnd.docker.distribution.manifest.v2+json",
}, ", ")

// chartVersion is the chart version to render into a combo's config: none when
// the build produces the chart, the flag when one was given, and otherwise
// whatever `latest` resolves to. Resolved once, so every combo in a run
// installs the same chart even if main moves while the run is under way.
func (r *Runner) chartVersion() (string, error) {
	if r.SourceRequested() {
		return "", nil
	}
	if r.Opts.ChartVersion != "" {
		return r.Opts.ChartVersion, nil
	}

	r.chartOnce.Do(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()

		r.chartVer, r.chartErr = latestChartVersion(ctx)
		if r.chartErr != nil {
			r.chartErr = fmt.Errorf("resolving the latest Tinkerbell chart version: %w\nPass --chart-version to name one instead.", r.chartErr)
		}
	})
	return r.chartVer, r.chartErr
}

// latestChartVersion is the chart version that `latest` points at.
//
// The chart carries no `latest` tag, so the version is read off the image that
// does: find the tag sharing a digest with `latest`, then confirm the chart was
// published under it. Matching on digest rather than on position is what makes
// the answer right — GHCR happening to list tags oldest-first only means the
// match is normally the first tag tried.
func latestChartVersion(ctx context.Context) (string, error) {
	return newRegistry().latestChartVersion(ctx)
}

func (g *registry) latestChartVersion(ctx context.Context) (string, error) {
	want, err := g.digest(ctx, tinkerbellImageRepo, "latest")
	if err != nil {
		return "", err
	}
	if want == "" {
		return "", fmt.Errorf("%s/%s has no latest tag", ghcrHost, tinkerbellImageRepo)
	}

	tags, err := g.tags(ctx, tinkerbellImageRepo)
	if err != nil {
		return "", err
	}

	tried := 0
	for i := len(tags) - 1; i >= 0 && tried < maxVersionLookups; i-- {
		tag := tags[i]
		if !versionTag.MatchString(tag) {
			continue
		}
		tried++

		got, err := g.digest(ctx, tinkerbellImageRepo, tag)
		if err != nil {
			return "", err
		}
		if got != want {
			continue
		}

		// The three artifacts are published one after another, so a run
		// dispatched in that window would otherwise pull a chart that is not
		// there yet and fail much later, during helm install.
		chart, err := g.digest(ctx, tinkerbellChartRepo, tag)
		if err != nil {
			return "", err
		}
		if chart == "" {
			return "", fmt.Errorf("%s/%s:%s is what latest points at, but %s/%s:%s is not published yet",
				ghcrHost, tinkerbellImageRepo, tag, ghcrHost, tinkerbellChartRepo, tag)
		}
		return tag, nil
	}

	return "", fmt.Errorf("no version tag on %s/%s shares a digest with latest (tried %d of %d tags)",
		ghcrHost, tinkerbellImageRepo, tried, len(tags))
}

// registry reads tags and digests from ghcr.io. Every repository it touches is
// public, so the only credential involved is the anonymous pull token the
// registry hands out for the asking.
type registry struct {
	client *http.Client
	base   string

	mu     sync.Mutex
	tokens map[string]string
}

func newRegistry() *registry {
	return &registry{
		client: &http.Client{Timeout: 15 * time.Second},
		base:   "https://" + ghcrHost,
		tokens: map[string]string{},
	}
}

// digest is the manifest digest ref resolves to, or "" when there is no such tag.
func (g *registry) digest(ctx context.Context, repo, ref string) (string, error) {
	resp, err := g.do(ctx, http.MethodHead, repo, g.base+"/v2/"+repo+"/manifests/"+url.PathEscape(ref), manifestAccept)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	switch resp.StatusCode {
	case http.StatusOK:
		d := resp.Header.Get("Docker-Content-Digest")
		if d == "" {
			return "", fmt.Errorf("%s/%s:%s: no digest in the response", ghcrHost, repo, ref)
		}
		return d, nil
	case http.StatusNotFound:
		return "", nil
	default:
		return "", fmt.Errorf("%s/%s:%s: %s", ghcrHost, repo, ref, resp.Status)
	}
}

func (g *registry) tags(ctx context.Context, repo string) ([]string, error) {
	var all []string
	next := g.base + "/v2/" + repo + "/tags/list?n=1000"

	for next != "" {
		resp, err := g.do(ctx, http.MethodGet, repo, next, "application/json")
		if err != nil {
			return nil, err
		}

		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			return nil, fmt.Errorf("listing tags for %s/%s: %s", ghcrHost, repo, resp.Status)
		}

		var page struct {
			Tags []string `json:"tags"`
		}
		err = json.NewDecoder(resp.Body).Decode(&page)
		link := resp.Header.Get("Link")
		resp.Body.Close()
		if err != nil {
			return nil, fmt.Errorf("listing tags for %s/%s: %w", ghcrHost, repo, err)
		}

		all = append(all, page.Tags...)
		next = g.nextPage(link)
	}

	if len(all) == 0 {
		return nil, fmt.Errorf("%s/%s has no tags", ghcrHost, repo)
	}
	return all, nil
}

// nextPage is the URL in a `Link: <...>; rel="next"` header, or "" at the end
// of the listing.
func (g *registry) nextPage(header string) string {
	for _, part := range strings.Split(header, ",") {
		target, params, ok := strings.Cut(strings.TrimSpace(part), ">")
		if !ok || !strings.Contains(params, `rel="next"`) {
			continue
		}
		target = strings.TrimPrefix(target, "<")
		if strings.HasPrefix(target, "/") {
			return g.base + target
		}
		return target
	}
	return ""
}

func (g *registry) do(ctx context.Context, method, repo, rawURL, accept string) (*http.Response, error) {
	token, err := g.token(ctx, repo)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, method, rawURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Accept", accept)

	resp, err := g.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%s %s: %w", method, rawURL, err)
	}
	return resp, nil
}

// token is the anonymous pull token for repo, which GHCR issues to anyone.
func (g *registry) token(ctx context.Context, repo string) (string, error) {
	g.mu.Lock()
	defer g.mu.Unlock()

	if token, ok := g.tokens[repo]; ok {
		return token, nil
	}

	query := url.Values{
		"service": {ghcrHost},
		"scope":   {"repository:" + repo + ":pull"},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, g.base+"/token?"+query.Encode(), nil)
	if err != nil {
		return "", err
	}

	resp, err := g.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("requesting a pull token for %s/%s: %w", ghcrHost, repo, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("requesting a pull token for %s/%s: %s", ghcrHost, repo, resp.Status)
	}

	var body struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return "", fmt.Errorf("requesting a pull token for %s/%s: %w", ghcrHost, repo, err)
	}
	if body.Token == "" {
		return "", fmt.Errorf("%s/%s: empty pull token", ghcrHost, repo)
	}

	g.tokens[repo] = body.Token
	return body.Token, nil
}
