package envfile

import (
	"fmt"
	"sort"
	"strings"

	"github.com/joho/godotenv"
)

type EnvFile map[string]string

func ReadEnvFile(f string) (EnvFile, error) {
	myEnv, err := godotenv.Read(f)
	if err != nil {
		return nil, err
	}
	return myEnv, nil
}

// Copied and modified from https://github.com/joho/godotenv

const doubleQuoteSpecialChars = "\\\n\r\"!$`"

func Marshal(envMap map[string]string) (string, error) {
	lines := make([]string, 0, len(envMap))
	for k, v := range envMap {
		lines = append(lines, fmt.Sprintf(`export %s="%s"`, k, doubleQuoteEscape(v)))
	}
	sort.Strings(lines)
	return strings.Join(lines, "\n"), nil
}

func doubleQuoteEscape(line string) string {
	for _, c := range doubleQuoteSpecialChars {
		toReplace := "\\" + string(c)
		if c == '\n' {
			toReplace = `\n`
		}
		if c == '\r' {
			toReplace = `\r`
		}
		line = strings.Replace(line, string(c), toReplace, -1)
	}
	return line
}

// End of the part copied from https://github.com/joho/godotenv
