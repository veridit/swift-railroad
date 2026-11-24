import XCTest
import Railroad

final class PublicAPITests: XCTestCase {
    func testEveryNodeAndStylesheet() {
        let terminal = RailroadTerminal(label: "literal", attributes: ["id": "literal"])
        let nonterminal = RailroadNonTerminal(label: "rule")
        let children: [any RailroadNode] = [terminal, nonterminal]
        let nodes: [any RailroadNode] = [
            terminal, nonterminal, RailroadComment(text: "comment"), RailroadEmpty(),
            RailroadStart(), RailroadEnd(), RailroadSimpleStart(), RailroadSimpleEnd(),
            RailroadContinuationStart(), RailroadContinuationEnd(), RailroadContinuation(),
            RailroadSequence(children: children), RailroadStack(children: children),
            RailroadChoice(children: children), RailroadMultiChoice(columns: [children, children]),
            RailroadSubsequence(children: children), RailroadOptional(inner: terminal),
            RailroadRepeat(inner: terminal, repeat: nonterminal),
            RailroadLabeledBox(inner: terminal, label: RailroadComment(text: "label")),
            RailroadAnnotation(inner: terminal), RailroadAnnotation(inner: terminal, direction: .ahead),
            RailroadAnnotation(inner: terminal, direction: .behind),
            RailroadLink(inner: terminal, uri: "#rule", target: .blank),
            RailroadLink(inner: terminal, uri: "#rule", target: .parent),
            RailroadLink(inner: terminal, uri: "#rule", target: .top),
            RailroadAlignment(inner: terminal, minWidth: 200, minHeight: 60,
                              horizontal: .start, vertical: .top, connectRails: true),
            RailroadAlignment(inner: terminal, minWidth: 200, minHeight: 60,
                              horizontal: .centered, vertical: .centered, connectRails: true),
            RailroadAlignment(inner: terminal, minWidth: 200, minHeight: 60,
                              horizontal: .end, vertical: .bottom, connectRails: false),
            RailroadScale(inner: terminal, scale: 1.5),
            RailroadScale(inner: terminal, scale: 1.5, precise: true),
            RailroadVerticalGrid(children: children), RailroadHorizontalGrid(children: children),
            RailroadHorizontalGrid(), RailroadSubsequence(), RailroadMultiChoice()
        ]
        for stylesheet in RailroadStylesheet.allCases {
            var diagram = RailroadDiagram(root: RailroadVerticalGrid(children: nodes), css: stylesheet.css,
                                          extraAttributes: ["id": "diagram"], title: "Public API")
            XCTAssertFalse(diagram.svg.isEmpty)
            XCTAssertGreaterThan(diagram.width, 0)
            XCTAssertGreaterThan(diagram.height, 0)
            XCTAssertEqual(diagram.title, "Public API")
            XCTAssertEqual(diagram.extraAttributes["id"], "diagram")
            XCTAssertFalse(stylesheet.toDark.isLight)
            XCTAssertTrue(stylesheet.toLight.isLight)
            diagram.css = nil
            diagram.title = nil
            diagram.extraAttributes = [:]
            XCTAssertFalse(diagram.svg.isEmpty)
        }
        XCTAssertEqual(terminal.heightBelowEntry, terminal.height - terminal.entryHeight)
        XCTAssertFalse(RailroadDiagram(root: terminal).svg.isEmpty)
    }

    func testDSLAndParseError() throws {
        let source = "[\"literal\" 'rule']"
        XCTAssertTrue(RailroadDSL.isValid(source))
        XCTAssertFalse(RailroadDSL.isValid("["))
        XCTAssertFalse(try RailroadDSL.svg(source, css: RailroadStylesheet.light.css).isEmpty)
        XCTAssertFalse(try RailroadDSL.diagram(source, css: nil).svg.isEmpty)
        XCTAssertEqual(try RailroadDSL.parse(source).count, 1)
        XCTAssertThrowsError(try RailroadDSL.parse("[")) { error in
            guard let error = error as? RailroadDSL.ParseError else {
                return XCTFail("Expected a public ParseError")
            }
            XCTAssertEqual(error.offset, 1)
            XCTAssertFalse(error.message.isEmpty)
            XCTAssertEqual(error, RailroadDSL.ParseError(offset: error.offset, message: error.message))
        }
    }

    func testCustomNodeRenderingAPI() {
        let renderer = RailroadRenderer()
        let node = CustomNode()
        for direction: RailroadHDir in [.ltr, .rtl] {
            node.render(renderer, x: 0, y: 0, hDir: direction)
        }
        XCTAssertFalse(renderer.output.isEmpty)
        XCTAssertTrue(renderer.output.contains("custom &amp; text"))
        XCTAssertFalse(RailroadDiagram(root: node).svg.isEmpty)
    }
}

private struct CustomNode: RailroadNode {
    var entryHeight: Int { 10 }
    var height: Int { 20 }
    var width: Int { 80 }

    func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        let tag: RailroadRenderer.StartTag = out.startElement("g")
        tag.attr("class", "custom")
        tag.attr("data-width", width)
        tag.finish()
        out.writeText("custom & text")
        out.writeRaw("\n")
        out.startElement("metadata").finishEmpty()
        let arcs: [RailroadArc] = [.eastToNorth, .eastToSouth, .northToEast, .northToWest,
                                  .southToEast, .southToWest, .westToNorth, .westToSouth]
        var path = RailroadPathData(hDir).moveTo(x, y).moveRel(1, 1).lineRel(2, 2)
            .cubicRel(1, 2, 3, 4, 5, 6).horizontal(60)
            .horizontalWithClearance(10, above: entryHeight, below: heightBelowEntry).vertical(60)
        for arc in arcs { path = path.arc(5, arc) }
        out.path(path.close(), class: "custom-path")
        out.rect(x: x, y: y, width: width, height: height)
        out.circle(cx: x, cy: y, radius: 2.5, opacity: "0.5")
        out.text(x: x, y: y, "text", class: "custom-text")
        out.group(class: "custom-group", attributes: ["id": "group"]) {
            out.textBox(x: x, y: y, width: width, height: height, entryHeight: entryHeight,
                        label: "box", rounded: true)
        }
        out.transformed(RailroadEmpty(), transform: "translate(0 0)", hDir: hDir)
        out.endElement("g")
    }
}
