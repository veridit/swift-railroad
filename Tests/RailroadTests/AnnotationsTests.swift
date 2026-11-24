import XCTest
@testable import Railroad

final class AnnotationsTests: XCTestCase {
    private func render(_ node: any RailroadNode, x: Int = 0, y: Int = 0,
                        direction: RailroadHDir = .ltr) -> String {
        let renderer = RailroadRenderer()
        node.render(renderer, x: x, y: y, hDir: direction)
        return renderer.output
    }

    private func t(_ label: String) -> RailroadTerminal { RailroadTerminal(label: label) }

    // api_wrappers.rs: link_wraps_inner_node_and_emits_target_attributes
    func testLinkWrapsInnerNodeAndEmitsTargetAttributes() {
        var link = RailroadLink(inner: t("docs"), uri: "https://example.com/?a=1&b=2")
        link.target = .parent
        link.attributes["data-kind"] = "external"
        let svg = RailroadDiagram(root: link).svg
        for expected in ["<a ", "xlink:href=\"https://example.com/?a=1&amp;b=2\"",
                         "target=\"_parent\"", "class=\"link\"", "data-kind=\"external\"", "docs"] {
            XCTAssertTrue(svg.contains(expected), expected)
        }
    }

    // api_wrappers.rs: alignment_positions_child
    func testAlignmentPositionsChild() {
        let node = RailroadAlignment(inner: t("x"), minWidth: 48, minHeight: 42,
                                     horizontal: .start, vertical: .bottom, connectRails: false)
        XCTAssertEqual(node.width, 48)
        XCTAssertEqual(node.height, 42)
        XCTAssertEqual(node.entryHeight, 31)
        XCTAssertTrue(render(node).contains("x=\"0\" y=\"20\""))
        XCTAssertTrue(render(node, direction: .rtl).contains("x=\"20\" y=\"20\""))
    }

    // api_wrappers.rs: alignment_does_not_shrink_child
    func testAlignmentDoesNotShrinkChild() {
        let child = t("x")
        for minimum in [-1, 0, 1] {
            let node = RailroadAlignment(inner: child, minWidth: minimum, minHeight: minimum,
                                         horizontal: .end, vertical: .bottom, connectRails: false)
            XCTAssertEqual(node.width, child.width)
            XCTAssertEqual(node.height, child.height)
            XCTAssertEqual(node.entryHeight, child.entryHeight)
        }
    }

    // api_wrappers.rs: alignment_can_connect_padding
    func testAlignmentCanConnectPadding() {
        for connect in [false, true] {
            let node = RailroadAlignment(inner: RailroadEmpty(), minWidth: 100, minHeight: 0,
                                         horizontal: .start, vertical: .top, connectRails: connect)
            XCTAssertEqual(render(node).contains("<path d=\" M 0 0 l 100 0\"/>"), connect)
        }
    }

    // api_wrappers.rs: annotation_renders_the_supplied_box_and_label
    func testAnnotationRendersTheSuppliedBoxAndLabel() {
        let node = RailroadAnnotation(inner: RailroadLabeledBox(inner: t("body"),
                                                               label: RailroadComment(text: "Custom label")))
        let svg = render(node)
        for expected in ["class=\"annotation-marker\"", "class=\"annotation-connector\"",
                         "class=\"labeledbox\"", "body", "Custom label", "class=\"annotation-symbol\""] {
            XCTAssertTrue(svg.contains(expected), expected)
        }
        XCTAssertFalse(svg.contains("annotation-direction"))
    }

    // api_wrappers.rs: annotation_arrows_follow_the_local_reading_direction
    func testAnnotationArrowsFollowTheLocalReadingDirection() {
        let cases: [(Bool, RailroadHDir, String)] = [
            (true, .ltr, " c 2 "), (true, .rtl, " c -2 "),
            (false, .ltr, " c -2 "), (false, .rtl, " c 2 "),
        ]
        for (ahead, direction, curve) in cases {
            let body = RailroadLabeledBox(inner: t("body"), label: RailroadEmpty())
            let node = ahead ? RailroadAnnotation.newAhead(inner: body) : RailroadAnnotation.newBehind(inner: body)
            let svg = render(node, direction: direction)
            XCTAssertTrue(svg.contains("class=\"annotation-direction\""))
            XCTAssertFalse(svg.contains("class=\"annotation-symbol\""))
            XCTAssertTrue(svg.contains(curve))
        }
    }

    // api_scale.rs: adjusted_scale_bounds_rounding_and_preserves_child_geometry
    func testAdjustedScaleBoundsRoundingAndPreservesChildGeometry() {
        let child = t("token")
        for requested in [0.63, 1.0, 1.8] {
            let node = RailroadScale(inner: child, scale: requested)
            let factor = node.effectiveScale
            XCTAssertEqual(node.requestedScale, requested)
            XCTAssertLessThanOrEqual(abs(Double(node.width) - requested * Double(child.width)), 0.5)
            XCTAssertEqual(factor, Double(node.width) / Double(child.width))
            for padding in [Double(node.entryHeight) - factor * Double(child.entryHeight),
                            Double(node.heightBelowEntry) - factor * Double(child.heightBelowEntry)] {
                XCTAssertTrue((0..<1).contains(padding))
            }
            XCTAssertEqual(node.inner.width, child.width)
            XCTAssertEqual(node.inner.height, child.height)
            XCTAssertEqual(node.inner.entryHeight, child.entryHeight)
        }
    }

    // api_scale.rs: precise_scale_preserves_the_factor_and_rounds_geometry_outward
    func testPreciseScalePreservesTheFactorAndRoundsGeometryOutward() {
        let child = t("token")
        for factor in [0.63, 1.0, 1.8] {
            let node = RailroadScale.newPrecise(inner: child, scale: factor)
            XCTAssertEqual(node.requestedScale, factor)
            XCTAssertEqual(node.effectiveScale, factor)
            for (scaled, natural) in [(node.width, child.width), (node.height, child.height),
                                      (node.entryHeight, child.entryHeight)] {
                XCTAssertTrue((0..<1).contains(Double(scaled) - factor * Double(natural)))
            }
        }
    }

    // api_scale.rs: scaling_handles_empty_children_and_tiny_target_widths
    func testScalingHandlesEmptyChildrenAndTinyTargetWidths() {
        for precise in [false, true] {
            let node = RailroadScale(inner: RailroadEmpty(), scale: 0.5, precise: precise)
            XCTAssertEqual(node.width, 0)
            XCTAssertEqual(node.height, 0)
            XCTAssertEqual(node.entryHeight, 0)
            XCTAssertEqual(node.effectiveScale, node.requestedScale)
        }
        let child = t("token")
        XCTAssertEqual(RailroadScale(inner: child, scale: 0.25 / Double(child.width)).width, 1)
    }

    // api_scale.rs: zero_scale_collapses_the_child (streaming branch only)
    func testZeroScaleCollapsesTheChild() {
        for precise in [false, true] {
            let node = RailroadScale(inner: t("token"), scale: 0, precise: precise)
            XCTAssertEqual(node.width, 0)
            XCTAssertEqual(node.height, 0)
            XCTAssertEqual(node.entryHeight, 0)
            XCTAssertEqual(node.effectiveScale, 0)
            XCTAssertEqual(render(node), "")
        }
    }

    // api_scale.rs: scaled_nodes_compose_and_render_through_both_backends
    // The Swift port exposes only the streaming backend.
    func testScaledNodesComposeAndRender() {
        let diagram = RailroadDiagram(root: RailroadScale(inner: RailroadRepeat(
            inner: t("item"), repeat: RailroadScale.newPrecise(inner: RailroadComment(text: "separator"), scale: 0.75)),
            scale: 0.63), css: RailroadStylesheet.light.css)
        for direction in [RailroadHDir.ltr, .rtl] {
            let svg = render(diagram, direction: direction)
            for expected in ["class=\"scale\"", "class=\"repeat\"", "transform=", "item", "separator"] {
                XCTAssertTrue(svg.contains(expected), expected)
            }
        }
    }

    // api_primitives.rs: built_in_primitives_render_distinct_markup, continuation
    // portion. The Debug primitive is intentionally outside this port's scope.
    func testContinuationPrimitivesRenderDistinctMarkup() {
        let node = RailroadSequence(children: [RailroadStart(), RailroadSimpleStart(),
            RailroadSimpleEnd(), RailroadEnd(), RailroadEmpty(),
            RailroadContinuationStart(), RailroadContinuation(), RailroadContinuationEnd()])
        let svg = RailroadDiagram(root: node).svg
        XCTAssertTrue(svg.hasPrefix("<svg"))
        XCTAssertGreaterThanOrEqual(svg.components(separatedBy: "<path").count - 1, 4)
        for cls in ["continuation-start", "continuation", "continuation-end"] {
            XCTAssertTrue(svg.contains("class=\"\(cls)\""))
        }
        XCTAssertEqual(svg.components(separatedBy: "<circle").count - 1, 9)
        XCTAssertEqual(RailroadEmpty().entryHeight, 0)
        XCTAssertEqual(RailroadEmpty().height, 0)
        XCTAssertEqual(RailroadEmpty().width, 0)
    }

    // Additional exact-output regression coverage for geometry and formatting.
    func testPreciseScaleTransformFormatting() {
        for (factor, text) in [(1.5, "1.5"), (0.75, "0.75"), (1.0, "1"),
                               (0.0000001, "0.0000001"), (1e20, "100000000000000000000")] {
            let node = RailroadScale.newPrecise(inner: RailroadEmpty(), scale: factor)
            XCTAssertTrue(render(node, x: 7, y: 9).contains(
                "transform=\"translate(7 9) matrix(\(text) 0 0 \(text) 0 0)\""))
        }
    }

    func testAdjustedScaleUsesExactIntegerRatios() {
        let node = RailroadScale(inner: FixedNode(width: 25, height: 50, entryHeight: 25), scale: 0.28)
        XCTAssertEqual(node.width, 7)
        XCTAssertEqual(node.entryHeight, 7)
        XCTAssertEqual(node.height, 14)
        XCTAssertTrue(render(node).contains("matrix(0.28 0 0 0.28 0 0)"))
        let zeroWidth = RailroadScale(inner: FixedNode(width: 0, height: 10, entryHeight: 3), scale: 0.5)
        XCTAssertEqual(zeroWidth.width, 0)
        XCTAssertEqual(zeroWidth.entryHeight, 2)
        XCTAssertEqual(zeroWidth.height, 6)
        XCTAssertTrue(render(zeroWidth).contains("matrix(0.5 0 0 0.5 0 0.5)"))
    }

    func testAlignmentCentersOddPaddingAndConnectsClearRails() {
        let node = RailroadAlignment(inner: t("x"), minWidth: 151, minHeight: 43,
                                     horizontal: .centered, vertical: .centered, connectRails: true)
        XCTAssertEqual(node.entryHeight, 21)
        for direction in [RailroadHDir.ltr, .rtl] {
            let svg = render(node, direction: direction)
            XCTAssertTrue(svg.contains("x=\"61\" y=\"10\""))
            XCTAssertTrue(svg.contains(" M 0 21 h 61"))
            XCTAssertTrue(svg.contains(" M 89 21 h 62"))
        }
    }

    func testLinkTargetsAndBuiltInAttributePrecedence() {
        var link = RailroadLink(inner: RailroadEmpty(), uri: "a&\"<>")
        link.attributes = ["class": "custom", "xlink:href": "ignored", "target": "custom"]
        for target in [RailroadLinkTarget.blank, .parent, .top] {
            link.target = target
            let svg = render(link)
            XCTAssertTrue(svg.contains("class=\"link\""))
            XCTAssertTrue(svg.contains("xlink:href=\"a&amp;&quot;&lt;&gt;\""))
            XCTAssertTrue(svg.contains("target=\"\(target.rawValue)\""))
        }
        link.target = nil
        XCTAssertTrue(render(link).contains("target=\"custom\""))
        link.attributes.removeValue(forKey: "target")
        XCTAssertFalse(render(link).contains("target="))
    }

    func testContinuationExactOutputIsDirectionIndependent() {
        let start = "<g class=\"continuation-start\">\n" +
            "<circle cx=\"10\" cy=\"14\" r=\"2.5\" fill-opacity=\"0.25\"/>\n" +
            "<circle cx=\"18\" cy=\"14\" r=\"2.5\" fill-opacity=\"0.6\"/>\n" +
            "<circle cx=\"26\" cy=\"14\" r=\"2.5\" fill-opacity=\"1\"/>\n" +
            "<path d=\" M 31 14 h 6\"/>\n</g>\n"
        let end = "<g class=\"continuation-end\">\n" +
            "<circle cx=\"34\" cy=\"14\" r=\"2.5\" fill-opacity=\"0.25\"/>\n" +
            "<circle cx=\"26\" cy=\"14\" r=\"2.5\" fill-opacity=\"0.6\"/>\n" +
            "<circle cx=\"18\" cy=\"14\" r=\"2.5\" fill-opacity=\"1\"/>\n" +
            "<path d=\" M 7 14 h 6\"/>\n</g>\n"
        let interior = "<g class=\"continuation\">\n" +
            "<circle cx=\"18\" cy=\"14\" r=\"2.5\" fill-opacity=\"0.5\"/>\n" +
            "<circle cx=\"26\" cy=\"14\" r=\"2.5\" fill-opacity=\"0.5\"/>\n" +
            "<circle cx=\"34\" cy=\"14\" r=\"2.5\" fill-opacity=\"0.5\"/>\n" +
            "<path d=\" M 7 14 h 6 M 39 14 h 6\"/>\n</g>\n"
        for direction in [RailroadHDir.ltr, .rtl] {
            XCTAssertEqual(render(RailroadContinuationStart(), x: 7, y: 9, direction: direction), start)
            XCTAssertEqual(render(RailroadContinuationEnd(), x: 7, y: 9, direction: direction), end)
            XCTAssertEqual(render(RailroadContinuation(), x: 7, y: 9, direction: direction), interior)
        }
    }

    private struct FixedNode: RailroadNode {
        let width: Int
        let height: Int
        let entryHeight: Int
        func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
            out.path(RailroadPathData(hDir).moveTo(x, y + entryHeight).horizontal(width))
        }
    }
}
