package runner

import (
	"encoding/json"
	"sort"
	"strings"

	"charm.land/lipgloss/v2"
	"charm.land/lipgloss/v2/table"
)

// comboColumns is the width of a list row: the combo name plus one column per
// axis.
const comboColumns = 5

// PrintCombos lists the combos and the axis values each one exercises.
func (r *Runner) PrintCombos() error {
	infos, err := r.ComboInfos()
	if err != nil {
		return err
	}

	names := make([]string, 0, len(infos))
	for name := range infos {
		names = append(names, name)
	}
	sort.Strings(names)

	if r.Opts.JSON {
		rows := make([]ComboInfo, 0, len(names))
		for _, name := range names {
			info := infos[name]
			info.Combo = name
			rows = append(rows, info)
		}
		out, err := json.MarshalIndent(rows, "", "  ")
		if err != nil {
			return err
		}
		r.UI.Info("%s", out)
		return nil
	}

	rows := make([][]string, 0, len(names))
	for _, name := range names {
		info := infos[name]
		rows = append(rows, []string{name, info.Tinkerbell, info.Family, info.Boot, info.Registry})
	}

	if !r.UI.tty {
		r.UI.Info("%s", plainComboTable(rows))
		return nil
	}
	r.UI.Info("%s", comboTable(rows))
	return nil
}

var (
	tableBorderColor = lipgloss.Color("240")
	tableHeaderColor = lipgloss.Color("99")
)

// comboTable is the listing as shown on a terminal: ruled, so the eye can
// follow a row across five columns.
func comboTable(rows [][]string) *table.Table {
	header := lipgloss.NewStyle().Foreground(tableHeaderColor).Bold(true).Padding(0, 1)
	cell := lipgloss.NewStyle().Padding(0, 1)
	dim := cell.Foreground(lipgloss.Color("245"))

	return table.New().
		Border(lipgloss.RoundedBorder()).
		BorderStyle(lipgloss.NewStyle().Foreground(tableBorderColor)).
		BorderRow(false).
		StyleFunc(func(row, col int) lipgloss.Style {
			switch {
			case row == table.HeaderRow:
				return header
			case col == 0:
				return cell
			default:
				return dim
			}
		}).
		Headers("COMBO", "TINKERBELL", "FAMILY", "BOOT", "REGISTRY").
		Rows(rows...)
}

// plainComboTable is the listing as piped: borderless, two-space gutters, no
// trailing blanks, so awk and cut still work on it.
func plainComboTable(rows [][]string) string {
	t := table.New().
		Border(lipgloss.Border{}).
		BorderTop(false).BorderBottom(false).
		BorderLeft(false).BorderRight(false).
		BorderHeader(false).BorderColumn(false).BorderRow(false).
		StyleFunc(func(_, col int) lipgloss.Style {
			if col < comboColumns-1 {
				return lipgloss.NewStyle().PaddingRight(2)
			}
			return lipgloss.NewStyle()
		}).
		Headers("COMBO", "TINKERBELL", "FAMILY", "BOOT", "REGISTRY").
		Rows(rows...)

	// The final column is still padded to its header width; trailing blanks on
	// a listing are noise.
	lines := strings.Split(t.Render(), "\n")
	for i, line := range lines {
		lines[i] = strings.TrimRight(line, " ")
	}
	return strings.Join(lines, "\n")
}
