package runner

import (
	"bytes"
	"strings"
	"sync"

	"github.com/charmbracelet/x/ansi"
)

// logPane is a ring buffer of the most recent output lines from a running
// command, rendered beneath its phase line and erased when the phase resolves.
type logPane struct {
	mu    sync.Mutex
	lines []string
	buf   []byte
	max   int
}

func newLogPane(max int) *logPane {
	return &logPane{max: max, lines: make([]string, 0, max)}
}

// Write accepts a command's output stream. Both \n and \r terminate a line, so
// progress output that redraws itself (docker pull) replaces the current line
// instead of filling the buffer.
func (p *logPane) Write(b []byte) (int, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.buf = append(p.buf, b...)
	for {
		i := bytes.IndexAny(p.buf, "\n\r")
		if i < 0 {
			break
		}
		p.push(string(p.buf[:i]))
		p.buf = p.buf[i+1:]
	}

	// A very long line with no terminator must not grow without bound.
	if len(p.buf) > 4096 {
		p.push(string(p.buf))
		p.buf = p.buf[:0]
	}

	return len(b), nil
}

func (p *logPane) push(line string) {
	// Source output carries its own colour; strip it so it cannot bleed into
	// the surrounding layout or survive truncation.
	line = strings.TrimRight(ansi.Strip(line), " \t")
	if line == "" {
		return
	}
	if len(p.lines) == p.max {
		copy(p.lines, p.lines[1:])
		p.lines = p.lines[:p.max-1]
	}
	p.lines = append(p.lines, line)
}

func (p *logPane) snapshot() []string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return append([]string(nil), p.lines...)
}
