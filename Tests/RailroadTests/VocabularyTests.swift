//
//  VocabularyTests.swift
//  swift-railroad
//
//  The 27 diagrams of the railroad crate's README "visual vocabulary"
//  (examples/readme.rs), rebuilt in Swift and compared byte for byte with the
//  SVGs the Rust crate 0.3.12 generated (Fixtures/vocabulary).
//

import XCTest
@testable import Railroad

final class VocabularyTests: XCTestCase {
    private var fixtures: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/vocabulary")
    }

    /// Port of `Vocabulary::bare_entry`: light stylesheet, explicit width and
    /// height attributes, and a `<title>`.
    private func render(_ node: any RailroadNode, title: String) -> String {
        var diagram = RailroadDiagram(root: node, css: RailroadStylesheet.light.css)
        diagram.extraAttributes["width"] = String(diagram.width)
        diagram.extraAttributes["height"] = String(diagram.height)
        diagram.title = title
        return diagram.svg + "\n"
    }

    /// Port of `Vocabulary::entry`, which adds start and end markers.
    private func withEndpoints(_ node: any RailroadNode) -> any RailroadNode {
        RailroadSequence(children: [RailroadSimpleStart(), node, RailroadSimpleEnd()])
    }

    /// The `<title>` text in the reference SVG, unescaped. The title is prose
    /// copied from the crate's README, not something the port has to compute.
    private func title(in svg: String) -> String {
        let start = svg.range(of: "<title>\n")!.upperBound
        let end = svg.range(of: "</title>", range: start..<svg.endIndex)!.lowerBound
        return String(svg[start..<end])
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func check(_ slug: String, _ node: any RailroadNode, bare: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try String(contentsOf: fixtures.appendingPathComponent("\(slug).svg"), encoding: .utf8)
        let actual = render(bare ? node : withEndpoints(node), title: title(in: expected))
        if actual != expected {
            let a = actual.split(separator: "\n", omittingEmptySubsequences: false)
            let e = expected.split(separator: "\n", omittingEmptySubsequences: false)
            let i = (0..<min(a.count, e.count)).first { a[$0] != e[$0] } ?? min(a.count, e.count)
            XCTFail("\(slug): first difference at line \(i + 1)\n  expected: \(i < e.count ? String(e[i]) : "<end>")\n  actual:   \(i < a.count ? String(a[i]) : "<end>")",
                    file: file, line: line)
        }
    }

    private func t(_ s: String) -> RailroadTerminal { RailroadTerminal(label: s) }
    private func nt(_ s: String) -> RailroadNonTerminal { RailroadNonTerminal(label: s) }
    private func c(_ s: String) -> RailroadComment { RailroadComment(text: s) }

    func testTerminal() throws {
        try check("terminal", t("if"))
    }

    func testNonTerminal() throws {
        try check("nonterminal", nt("expr"))
    }

    func testSequence() throws {
        try check("sequence", RailroadSequence(children: [t("("), nt("expr"), t(")")]))
    }

    func testChoice() throws {
        try check("choice", RailroadChoice(children: [t("true"), t("false")]))
    }

    func testOptional() throws {
        try check("optional", RailroadOptional(inner: t("else")))
    }

    func testOneOrMore() throws {
        try check("one-or-more", RailroadRepeat(inner: nt("item"), repeat: RailroadEmpty()))
    }

    func testZeroOrMore() throws {
        try check("zero-or-more", RailroadOptional(inner: RailroadRepeat(inner: nt("item"), repeat: RailroadEmpty())))
    }

    func testSeparatedList() throws {
        try check("separated-list", RailroadRepeat(inner: nt("item"), repeat: t(",")))
    }

    func testStack() throws {
        try check("stack", RailroadStack(children: [t("("), nt("expr"), t(")")]))
    }

    func testVerticalGrid() throws {
        try check("vertical-grid", RailroadVerticalGrid(children: [
                    RailroadSequence(children: [RailroadSimpleStart(), t("yes"), RailroadSimpleEnd()]),
                    RailroadSequence(children: [RailroadSimpleStart(), t("no"), RailroadSimpleEnd()]),
                  ]), bare: true)
    }

    func testComment() throws {
        try check("comment", c("an expression follows"))
    }

    func testLabeledBox() throws {
        try check("labeled-box", RailroadLabeledBox(inner: nt("expr"), label: c("expression")))
    }

    func testStartEnd() throws {
        try check("start-end", RailroadSequence(children: [RailroadStart(), nt("expr"), RailroadEnd()]), bare: true)
    }

    func testSimpleStartEnd() throws {
        try check("simple-start-end", RailroadSequence(children: [RailroadSimpleStart(), nt("expr"), RailroadSimpleEnd()]), bare: true)
    }

    func testEmpty() throws {
        try check("empty", RailroadChoice(children: [
                    RailroadLabeledBox(inner: RailroadEmpty(), label: c("Default")),
                    t("ASC"), t("DESC"),
                  ]))
    }

    // PORT-PENDING: subsequence, multi-choice, horizontal-grid, aligned-rule-labels,
    // alignment, scale, link, annotation, negative-lookahead, negative-lookbehind,
    // continuation, continuation-start-end. Workers add them as the nodes land.
}
