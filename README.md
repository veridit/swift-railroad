# swift-railroad-diagrams

Railroad (syntax) diagrams as SVG, in pure Swift. No dependencies; runs on every
Apple platform and on Linux.

This is a Swift port of the Rust [`railroad`](https://github.com/lukaslueg/railroad)
crate (0.3.12) and its small text format,
[`railroad_dsl`](https://github.com/lukaslueg/railroad_dsl), both by Lukas Lueg.
The output is byte-for-byte identical to the Rust crate. The test suite checks
that against SVGs the Rust crate produced.

It started as the renderer behind the regex visualizer in
[iTerm2](https://github.com/gnachman/iTerm2/pull/838).

## Installation

```swift
.package(url: "https://github.com/veridit/swift-railroad-diagrams.git", from: "0.1.0")
```

Then depend on the `Railroad` product (and `RailroadImage` for PNG export).

## Usage

```swift
import Railroad

// From the text format:
let svg = try RailroadDSL.svg(#"["SELECT" <'column', "*"> "FROM" 'table']"#,
                              css: RailroadStylesheet.light.css)

// Or build the tree yourself:
let diagram = RailroadDiagram(
    root: RailroadSequence(children: [
        RailroadSimpleStart(),
        RailroadTerminal(label: "SELECT"),
        RailroadChoice(children: [RailroadNonTerminal(label: "column"),
                                  RailroadTerminal(label: "*")]),
        RailroadSimpleEnd(),
    ]),
    css: RailroadStylesheet.dark.css)
print(diagram.svg)
```

## The text format

| Syntax | Meaning |
|---|---|
| `"if"` | terminal (literal token) |
| `'expr'` | non-terminal (named rule) |
| `` `note` `` | comment |
| `!` | empty |
| `[a b c]` | sequence |
| `{a, b, c}` | stack (a sequence wrapped over rows) |
| `<a, b, c>` | choice |
| `a?` | optional |
| `a*b` | repeat `a`, with `b` between repetitions |
| `a#b` | `a` in a box labeled `b` |

Several top-level expressions are stacked as separate diagrams. Backslash escapes
the quote character inside a literal.

## Nodes

Terminal, NonTerminal, Comment, Empty, Sequence, Stack, Choice, MultiChoice,
Subsequence, Optional, Repeat, LabeledBox, Annotation, Link, Alignment, Scale,
VerticalGrid, HorizontalGrid, Start/End, SimpleStart/SimpleEnd, and the
continuation markers.

## Themes

`light`, `dark`, `rust`, `coal`, `navy`, `ayu`, plus `lightRendersafe` and
`darkRendersafe` for SVG renderers with limited CSS support. The CSS is copied
unchanged from the Rust crate.

## PNG export (macOS)

The separate `RailroadImage` product renders a diagram through WebKit, so the
core `Railroad` library needs nothing but Foundation:

```swift
import RailroadImage

let png = try await RailroadImage.png(diagram, scale: 2)   // Data
let image = try await RailroadImage.image(diagram)         // NSImage
```

## Tests

`swift test` runs the ported upstream unit tests, plus byte-for-byte comparisons
against reference SVGs made by the Rust crate:

- the 27 diagrams of the crate's own visual vocabulary,
- 20 `railroad_dsl` examples,
- 40 diagrams generated from real regular expressions by iTerm2.

## License

MIT, see [LICENSE](LICENSE). Original work © 2018 Lukas Lueg. Swift port © 2026
Veridit AS.
