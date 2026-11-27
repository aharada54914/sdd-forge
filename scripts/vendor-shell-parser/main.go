//go:build js && wasm

// Parse static source only. The entry point only uses the shell syntax package.
package main

import (
	"slices"
	"strings"
	"syscall/js"

	"mvdan.cc/sh/v3/syntax"
)

func scan(_ js.Value, args []js.Value) any {
	source := args[0].String()
	var dialect syntax.LangVariant
	if err := dialect.Set(args[1].String()); err != nil {
		return err.Error()
	}
	decode := args[2]
	invalidDelimiter := false
	syntax.HeredocDelimiter = func(word *syntax.Word) ([]byte, bool) {
		raw := source[word.Pos().Offset():word.End().Offset()]
		value := decode.Invoke(raw)
		if value.Type() != js.TypeString {
			invalidDelimiter = true
			return nil, true
		}
		return []byte(value.String()), strings.ContainsAny(strings.ReplaceAll(raw, "\\\n", ""), "'\"\\")
	}
	defer func() { syntax.HeredocDelimiter = nil }()
	parser := syntax.NewParser(syntax.Variant(dialect), syntax.KeepComments(true))
	file, err := parser.Parse(strings.NewReader(source), "")
	if invalidDelimiter {
		return "non-UTF-8 here-document delimiter"
	}
	if err != nil {
		return err.Error()
	}
	var offsets []int
	syntax.Walk(file, func(node syntax.Node) bool {
		if comment, ok := node.(*syntax.Comment); ok {
			offsets = append(offsets, int(comment.Hash.Offset()))
		}
		return true
	})
	slices.Sort(offsets)
	result := js.Global().Get("Array").New(len(offsets))
	for i, offset := range offsets {
		result.SetIndex(i, offset)
	}
	return result
}

func main() {
	js.Global().Set("sddParseShellComments", js.FuncOf(scan))
	select {}
}
