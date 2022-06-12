package strings

import (
	"math/rand"
	"strconv"
	"strings"
	"time"
)

func AnyOf(testString string, variants ...string) bool {
	for _, s := range variants {
		if testString == s {
			return true
		}
	}
	return false
}

func AnyOfSubstr(testString string, variants ...string) bool {
	for _, s := range variants {
		if strings.Contains(testString, s) {
			return true
		}
	}
	return false
}

func ListToRefList(ss []string) (ret []*string) {
	for i := range ss {
		ret = append(ret, &ss[i])
	}
	return
}

var letters = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

func RandSeq(n int) string {
	rand.Seed(time.Now().UnixNano())
	b := make([]rune, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}

func ElfHash(name string) string {
	var h uint32
	for i := 0; i < len(name); i++ {
		h = (h << 4) + uint32(name[i])
		if g := h & 0xf0000000; g != 0 {
			h ^= g >> 24
		}
		h &= 0x0fffffff
	}
	return strconv.Itoa(int(h))
}

func ElfHashSuffixed(s string, maxLength int) string {
	if len(s) < maxLength {
		return s
	}
	hash := ElfHash(s)
	return strings.Join([]string{s[:(maxLength - len(hash) - 1)], hash}, "-")
}
