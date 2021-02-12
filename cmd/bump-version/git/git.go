package git

import (
	g "github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/storage/memory"
)

type Repository struct {
	repo *g.Repository
}

func Clone(remote string) (*Repository, error) {
	repo := &Repository{}
	r, err := g.Clone(memory.NewStorage(), nil, &g.CloneOptions{
		URL: remote,
	})
	if err != nil {
		return nil, err
	}
	repo.repo = r
	return repo, nil
}

func (r *Repository) GetHeadHash() (string, error) {
	ref, err := r.repo.Head()
	if err != nil {
		return "", err
	}
	return ref.Hash().String(), nil
}
