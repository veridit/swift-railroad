//
//  RailroadImage.swift
//  swift-railroad-diagrams
//
//  Raster output (PNG) for railroad diagrams, through WebKit's SVG renderer.
//  Lives in its own target so the core library stays Foundation-only and
//  portable to Linux.
//

#if canImport(WebKit) && canImport(AppKit)
import AppKit
import Railroad
import WebKit

public enum RailroadImage {
    public enum Error: Swift.Error {
        case snapshotFailed(Swift.Error?)
        case encodingFailed
    }

    /// Renders an SVG string (for example `RailroadDiagram.svg`) to an image.
    ///
    /// - Parameters:
    ///   - svg: SVG markup with a `viewBox`.
    ///   - size: Size in points; the SVG is scaled to fit it.
    ///   - scale: Backing scale factor. 2 gives a Retina-resolution bitmap.
    @MainActor
    public static func image(svg: String, size: CGSize, scale: CGFloat = 2) async throws -> NSImage {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        let webView = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        let loader = Loader()
        webView.navigationDelegate = loader
        let html = "<html><head><style>html,body{margin:0;padding:0}svg{display:block;width:100vw;height:100vh}</style></head><body>\(svg)</body></html>"
        try await loader.load(html, in: webView)

        let snapshot = WKSnapshotConfiguration()
        snapshot.rect = CGRect(origin: .zero, size: size)
        snapshot.snapshotWidth = NSNumber(value: Double(size.width))
        let image: NSImage = try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: snapshot) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: Error.snapshotFailed(error))
                }
            }
        }
        return rescaled(image, size: size, scale: scale)
    }

    /// Renders a diagram to an image at its natural size.
    @MainActor
    public static func image(_ diagram: RailroadDiagram, scale: CGFloat = 2) async throws -> NSImage {
        try await image(svg: diagram.svg, size: CGSize(width: diagram.width, height: diagram.height), scale: scale)
    }

    /// Renders a diagram to PNG data at its natural size.
    @MainActor
    public static func png(_ diagram: RailroadDiagram, scale: CGFloat = 2) async throws -> Data {
        let image = try await image(diagram, scale: scale)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw Error.encodingFailed
        }
        return data
    }

    private static func rescaled(_ image: NSImage, size: CGSize, scale: CGFloat) -> NSImage {
        let pixels = NSSize(width: size.width * scale, height: size.height * scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            return image
        }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: size)
        result.addRepresentation(rep)
        return result
    }

    @MainActor
    private final class Loader: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Void, Swift.Error>?

        func load(_ html: String, in webView: WKWebView) async throws {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            continuation?.resume()
            continuation = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Swift.Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Swift.Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
#endif
