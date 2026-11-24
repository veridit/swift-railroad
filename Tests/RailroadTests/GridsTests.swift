// Assertions ported from railroad 0.3.12 tests/api_grids.rs and api_containers.rs.
import XCTest
@testable import Railroad

final class GridsTests: XCTestCase {
    func test_vertical_and_horizontal_grids_render_their_children() {
        let vertical = RailroadVerticalGrid(children: [
            RailroadTerminal(label: "row one"), RailroadTerminal(label: "row two")
        ], attributes: ["data-layout": "vertical"])
        let verticalSVG = RailroadDiagram(root: vertical).svg
        XCTAssertTrue(verticalSVG.contains("class=\"verticalgrid\""))
        XCTAssertTrue(verticalSVG.contains("data-layout=\"vertical\""))
        XCTAssertTrue(verticalSVG.contains("row one"))
        XCTAssertTrue(verticalSVG.contains("row two"))

        let horizontal = RailroadHorizontalGrid(children: [
            RailroadComment(text: "left"), RailroadComment(text: "right")
        ], attributes: ["data-layout": "horizontal"])
        let horizontalSVG = RailroadDiagram(root: horizontal).svg
        XCTAssertTrue(horizontalSVG.contains("class=\"horizontalgrid\""))
        XCTAssertTrue(horizontalSVG.contains("data-layout=\"horizontal\""))
        XCTAssertTrue(horizontalSVG.contains("left"))
        XCTAssertTrue(horizontalSVG.contains("right"))
    }

    func test_multichoice_renders_container_markup_and_children() {
        let node = RailroadMultiChoice(columns: [
            [RailroadTerminal(label: "red"), RailroadTerminal(label: "blue")],
            [RailroadTerminal(label: "green")]
        ], attributes: ["data-layout": "multichoice"])
        let svg = RailroadDiagram(root: node).svg
        XCTAssertTrue(svg.contains("class=\"multichoice\""))
        XCTAssertTrue(svg.contains("data-layout=\"multichoice\""))
        XCTAssertTrue(svg.contains("red"))
        XCTAssertTrue(svg.contains("blue"))
        XCTAssertTrue(svg.contains("green"))
        XCTAssertGreaterThanOrEqual(svg.components(separatedBy: "<path").count - 1, 5)
    }

    func test_multichoice_supports_push_column_and_into_inner() {
        var node = RailroadMultiChoice()
        // Swift's mutable value properties provide Rust's push_column/into_inner API.
        node.columns.append([RailroadTerminal(label: "one")])
        node.columns.append([RailroadTerminal(label: "two"), RailroadTerminal(label: "three")])
        let columns = node.columns
        XCTAssertEqual(columns.count, 2)
        XCTAssertEqual(columns[0].count, 1)
        XCTAssertEqual(columns[1].count, 2)
    }

    func test_multichoice_empty_and_single_column_match_choice_geometry() {
        let emptyChoice = RailroadChoice(children: [])
        let empty = RailroadMultiChoice()
        XCTAssertEqual(empty.entryHeight, emptyChoice.entryHeight)
        XCTAssertEqual(empty.height, emptyChoice.height)
        XCTAssertEqual(empty.width, emptyChoice.width)
        let children: [any RailroadNode] = [
            RailroadTerminal(label: "one"), RailroadEmpty(), RailroadTerminal(label: "three")
        ]
        let choice = RailroadChoice(children: children)
        let node = RailroadMultiChoice(columns: [children])
        XCTAssertEqual(node.entryHeight, choice.entryHeight)
        XCTAssertEqual(node.height, choice.height)
        XCTAssertEqual(node.width, choice.width)
    }

    func test_subsequence_empty_and_single_child_geometry() {
        let empty = RailroadSubsequence()
        XCTAssertEqual(empty.width, 0)
        XCTAssertEqual(empty.height, 0)
        XCTAssertEqual(empty.entryHeight, 0)
        let child = RailroadTerminal(label: "A")
        let single = RailroadSubsequence(children: [child])
        XCTAssertEqual(single.width, child.width)
        XCTAssertEqual(single.height, child.height)
        XCTAssertEqual(single.entryHeight, child.entryHeight)
    }

    func test_horizontal_grid_empty_and_top_aligned_children() {
        let empty = RailroadHorizontalGrid()
        XCTAssertEqual(empty.width, 0)
        XCTAssertEqual(empty.height, 0)
        XCTAssertEqual(empty.entryHeight, 0)
        let first = GeometryNode(entryHeight: 3, height: 17, width: 7)
        let second = GeometryNode(entryHeight: 9, height: 12, width: 11)
        let node = RailroadHorizontalGrid(children: [first, second])
        XCTAssertEqual(node.width, 30)
        XCTAssertEqual(node.height, 17)
        XCTAssertEqual(node.entryHeight, 0)
        XCTAssertEqual(render(node, x: 5, y: 8, hDir: .rtl),
                       "<g class=\"horizontalgrid\">\n<rect x=\"5\" y=\"8\" height=\"17\" width=\"7\"/>\n<rect x=\"24\" y=\"8\" height=\"12\" width=\"11\"/>\n</g>\n")
    }

    func test_empty_and_single_child_streams() {
        XCTAssertEqual(render(RailroadSubsequence(), x: 7, y: 9, hDir: .ltr),
                       "<g class=\"subsequence\">\n</g>\n")
        XCTAssertEqual(render(RailroadMultiChoice(), x: 7, y: 9, hDir: .rtl),
                       "<g class=\"multichoice\">\n<path d=\" M 7 9 h 0\"/>\n</g>\n")
        let child = GeometryNode(entryHeight: 3, height: 17, width: 7)
        XCTAssertEqual(render(RailroadSubsequence(children: [child]), x: 5, y: 8, hDir: .rtl),
                       "<g class=\"subsequence\">\n<rect x=\"5\" y=\"8\" height=\"17\" width=\"7\"/>\n</g>\n")
    }

    func test_multichoice_ignores_empty_columns() {
        let a = RailroadTerminal(label: "a")
        let b = RailroadTerminal(label: "b")
        let compact = RailroadMultiChoice(columns: [[a], [b]])
        let padded = RailroadMultiChoice(columns: [[], [a], [], [b], []])
        XCTAssertEqual(compact.width, padded.width)
        XCTAssertEqual(compact.height, padded.height)
        XCTAssertEqual(compact.entryHeight, padded.entryHeight)
        for direction in [RailroadHDir.ltr, .rtl] {
            XCTAssertEqual(render(compact, x: 7, y: 9, hDir: direction),
                           render(padded, x: 7, y: 9, hDir: direction))
        }
    }

    private func render(_ node: any RailroadNode, x: Int, y: Int, hDir: RailroadHDir) -> String {
        let out = RailroadRenderer()
        node.render(out, x: x, y: y, hDir: hDir)
        return out.output
    }

    private struct GeometryNode: RailroadNode {
        let entryHeight: Int
        let height: Int
        let width: Int
        func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
            out.rect(x: x, y: y, width: width, height: height)
        }
    }
}
