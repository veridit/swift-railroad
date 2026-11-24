#if canImport(WebKit) && canImport(AppKit)
import AppKit
import Railroad
import RailroadImage
import XCTest

final class RailroadImageTests: XCTestCase {
    @MainActor
    func testPNGHasDiagramSizeAtScaleAndInk() async throws {
        let diagram = try RailroadDSL.diagram(#"["SELECT" <'column', "*">]"#, css: RailroadStylesheet.light.css)
        let data = try await RailroadImage.png(diagram, scale: 2)

        XCTAssertEqual(Array(data.prefix(8)), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "PNG signature")
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(rep.pixelsWide, diagram.width * 2)
        XCTAssertEqual(rep.pixelsHigh, diagram.height * 2)

        // The light theme has a beige background and black strokes: a blank
        // snapshot would have no dark pixels at all.
        var dark = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.brightnessComponent < 0.3 {
                    dark += 1
                }
            }
        }
        XCTAssertGreaterThan(dark, 50, "expected drawn lines and text")
    }
}
#endif
