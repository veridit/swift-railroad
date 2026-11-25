//
//  RailroadAnnotations.swift
//  swift-railroad-diagrams
//
//  Swift port of railroad crate 0.3.12 wrappers, annotations, and continuation
//  markers, Copyright (c) 2018 Lukas Lueg, MIT License.
//

import Foundation

/// Browsing contexts for a link's optional target attribute.
public enum RailroadLinkTarget: String {
    case blank = "_blank"
    case parent = "_parent"
    case top = "_top"
}

/// A child wrapped in a clickable SVG link.
public struct RailroadLink: RailroadNode {
    public init(inner: any RailroadNode, uri: String, target: RailroadLinkTarget? = nil, attributes: [String: String] = [:]) {
        self.inner = RailroadMeasured(inner)
        self.uri = uri
        self.target = target
        self.attributes = attributes
    }

    public var inner: any RailroadNode { didSet { inner = RailroadMeasured(inner) } }
    public var uri: String
    public var target: RailroadLinkTarget? = nil
    public var attributes: [String: String] = [:]

    public var entryHeight: Int { inner.entryHeight }
    public var height: Int { inner.height }
    public var width: Int { inner.width }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        let tag = out.startElement("a")
        tag.attrs(attributes)
        tag.attr("class", "link")
        tag.attr("xlink:href", uri)
        if let target { tag.attr("target", target.rawValue) }
        tag.finish()
        inner.render(out, x: x, y: y, hDir: hDir)
        out.endElement("a")
    }
}

/// Horizontal placement of a child within reserved space.
public enum RailroadHorizontalAlignment {
    case start
    case centered
    case end
}

/// Vertical placement of a child within reserved space.
public enum RailroadVerticalAlignment {
    case top
    case centered
    case bottom
}

/// Reserve minimum dimensions without resizing the child.
public struct RailroadAlignment: RailroadNode {
    public init(inner: any RailroadNode, minWidth: Int, minHeight: Int, horizontal: RailroadHorizontalAlignment, vertical: RailroadVerticalAlignment, connectRails: Bool, attributes: [String: String] = [:]) {
        self.inner = RailroadMeasured(inner)
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.horizontal = horizontal
        self.vertical = vertical
        self.connectRails = connectRails
        self.attributes = attributes
    }

    public var inner: any RailroadNode { didSet { inner = RailroadMeasured(inner) } }
    public var minWidth: Int
    public var minHeight: Int
    public var horizontal: RailroadHorizontalAlignment
    public var vertical: RailroadVerticalAlignment
    public var connectRails: Bool
    public var attributes: [String: String] = [:]

    private var verticalOffset: Int {
        switch vertical {
        case .top: return 0
        case .centered: return (height - inner.height) / 2
        case .bottom: return height - inner.height
        }
    }
    public var entryHeight: Int { inner.entryHeight + verticalOffset }
    public var height: Int { max(inner.height, minHeight) }
    public var width: Int { max(inner.width, minWidth) }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        let extraWidth = width - inner.width
        let dx: Int
        switch (horizontal, hDir) {
        case (.start, .ltr), (.end, .rtl): dx = 0
        case (.centered, _): dx = extraWidth / 2
        case (.end, .ltr), (.start, .rtl): dx = extraWidth
        }
        out.group(class: "alignment", attributes: attributes) {
            if connectRails {
                for (offset, length) in [(0, dx), (dx + inner.width, extraWidth - dx)] where length > 0 {
                    out.path(RailroadPathData(hDir).moveTo(x + offset, y + entryHeight)
                        .horizontalWithClearance(length, above: entryHeight, below: heightBelowEntry))
                }
            }
            inner.render(out, x: x + dx, y: y + verticalOffset, hDir: hDir)
        }
    }
}

/// Uniform scaling, either adjusted to integral rail coordinates or precise.
public struct RailroadScale: RailroadNode {
    public var inner: any RailroadNode { didSet { inner = RailroadMeasured(inner) } }
    public let requestedScale: Double
    public let precise: Bool
    public var attributes: [String: String] = [:]

    public init(inner: any RailroadNode, scale: Double, precise: Bool = false) {
        precondition(scale.isFinite && scale >= 0, "scale must be finite and nonnegative")
        self.inner = RailroadMeasured(inner)
        self.requestedScale = scale
        self.precise = precise
    }

    static func newPrecise(inner: any RailroadNode, scale: Double) -> Self {
        Self(inner: inner, scale: scale, precise: true)
    }

    private static func integerDimension(_ value: Double) -> Int {
        precondition(value.isFinite && value >= 0 && value < Double(Int.max),
                     "scaled dimension exceeds NodeGeometry's range")
        return Int(value)
    }

    private func scaledWidth(_ natural: Int) -> Int {
        let target = requestedScale * Double(natural)
        if precise { return Self.integerDimension(target.rounded(.up)) }
        if natural == 0 { return 0 }
        return Self.integerDimension(max(1, target.rounded(.toNearestOrAwayFromZero)))
    }

    var effectiveScale: Double {
        if requestedScale == 0 || precise || inner.width == 0 { return requestedScale }
        return Double(scaledWidth(inner.width)) / Double(inner.width)
    }

    /// The Rust implementation multiplies in u128 before dividing. A full-width
    /// UInt product preserves the same exact integer ratios on 64-bit Swift.
    private static func adjustedDimension(_ value: Int, width: Int, naturalWidth: Int) -> (Int, Double) {
        let numerator = UInt(value).multipliedFullWidth(by: UInt(width))
        let denominator = UInt(naturalWidth)
        precondition(numerator.high < denominator, "scaled dimension exceeds NodeGeometry's range")
        let (quotient, remainder) = denominator.dividingFullWidth(numerator)
        precondition(quotient <= UInt(Int.max) - (remainder == 0 ? 0 : 1),
                     "scaled dimension exceeds NodeGeometry's range")
        let dimension = Int(quotient) + (remainder == 0 ? 0 : 1)
        let padding = remainder == 0 ? 0 : Double(denominator - remainder) / Double(denominator)
        return (dimension, padding)
    }

    private var layout: (width: Int, height: Int, entry: Int, factor: Double, offset: Double) {
        if requestedScale == 0 { return (0, 0, 0, requestedScale, 0) }
        let naturalWidth = inner.width
        let naturalHeight = inner.height
        let naturalEntry = inner.entryHeight
        precondition(naturalWidth >= 0 && naturalEntry >= 0 && naturalHeight >= naturalEntry,
                     "Scale requires nonnegative child dimensions and an entry within its height")
        let width = scaledWidth(naturalWidth)
        let factor = precise || naturalWidth == 0 ? requestedScale : Double(width) / Double(naturalWidth)
        if precise {
            return (width, Self.integerDimension((factor * Double(naturalHeight)).rounded(.up)),
                    Self.integerDimension((factor * Double(naturalEntry)).rounded(.up)), factor, 0)
        }
        let entry: Int
        let below: Int
        let offset: Double
        if naturalWidth == 0 {
            let scaledEntry = factor * Double(naturalEntry)
            entry = Self.integerDimension(scaledEntry.rounded(.up))
            offset = Double(entry) - scaledEntry
            below = Self.integerDimension((factor * Double(naturalHeight - naturalEntry)).rounded(.up))
        } else {
            (entry, offset) = Self.adjustedDimension(naturalEntry, width: width, naturalWidth: naturalWidth)
            (below, _) = Self.adjustedDimension(naturalHeight - naturalEntry, width: width, naturalWidth: naturalWidth)
        }
        let (height, overflow) = entry.addingReportingOverflow(below)
        precondition(!overflow, "scaled height exceeds NodeGeometry's range")
        return (width, height, entry, factor, offset)
    }

    public var width: Int { requestedScale == 0 ? 0 : scaledWidth(inner.width) }
    public var height: Int { layout.height }
    public var entryHeight: Int { layout.entry }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        guard requestedScale != 0 else { return }
        let layout = layout
        let factor = railroadRustFloat(layout.factor)
        let transform = "translate(\(x) \(y)) matrix(\(factor) 0 0 \(factor) 0 \(railroadRustFloat(layout.offset)))"
        out.group(class: "scale", attributes: attributes) {
            out.transformed(inner, transform: transform, hDir: hDir)
        }
    }
}

/// Rust's Display uses decimal notation even where Swift chooses an exponent.
/// Keep Swift's shortest round-tripping digits, expanding any exponent exactly.
fileprivate func railroadRustFloat(_ value: Double) -> String {
    if value == 0 { return value.sign == .minus ? "-0" : "0" }
    let text = RailroadRenderer.format(value)
    guard let e = text.firstIndex(of: "e"), let exponent = Int(text[text.index(after: e)...]) else { return text }
    var mantissa = String(text[..<e])
    let sign = mantissa.hasPrefix("-") ? "-" : ""
    if !sign.isEmpty { mantissa.removeFirst() }
    let parts = mantissa.split(separator: ".", omittingEmptySubsequences: false)
    let digits = parts.joined()
    let decimalPosition = parts[0].count + exponent
    if decimalPosition <= 0 {
        return sign + "0." + String(repeating: "0", count: -decimalPosition) + digits
    }
    if decimalPosition >= digits.count {
        return sign + digits + String(repeating: "0", count: decimalPosition - digits.count)
    }
    let split = digits.index(digits.startIndex, offsetBy: decimalPosition)
    return sign + digits[..<split] + "." + digits[split...]
}

/// A diamond annotation marker above a child.
public struct RailroadAnnotation: RailroadNode {
    public init(inner: any RailroadNode, direction: Direction = .none, attributes: [String: String] = [:]) {
        self.inner = RailroadMeasured(inner)
        self.direction = direction
        self.attributes = attributes
    }

    /// Direction of the annotation marker along the rail.
    public enum Direction { case none, ahead, behind }
    public var inner: any RailroadNode { didSet { inner = RailroadMeasured(inner) } }
    public var direction: Direction = .none
    public var attributes: [String: String] = [:]

    static func newAhead(inner: any RailroadNode) -> Self { Self(inner: inner, direction: .ahead) }
    static func newBehind(inner: any RailroadNode) -> Self { Self(inner: inner, direction: .behind) }

    public var entryHeight: Int { 16 }
    public var height: Int { 48 + inner.height }
    public var width: Int { max(inner.width, 64) }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        let cx = x + width / 2
        let railY = y + entryHeight
        out.group(class: "annotation", attributes: attributes) {
            out.path(RailroadPathData(hDir).moveTo(x, railY).horizontal(width / 2 - 24)
                .moveTo(cx + 24, railY).horizontal(width - width / 2 - 24), class: "annotation-rail")
            out.path(RailroadPathData(hDir).moveTo(cx, y).lineRel(24, 16)
                .lineRel(-24, 16).lineRel(-24, -16).close(), class: "annotation-marker")
            out.path(RailroadPathData(hDir).moveTo(cx, y + 32).lineRel(0, 16), class: "annotation-connector")
            if direction == .none {
                out.text(x: cx, y: railY + 5, "!", class: "annotation-symbol")
            } else {
                let dir = direction == .ahead ? hDir : hDir.inverted
                let sign = dir == .ltr ? 1 : -1
                out.path(RailroadPathData(dir).moveTo(cx - sign * 8, railY)
                    .cubicRel(sign * 2, -4, sign * 5, -4, sign * 7, 0)
                    .cubicRel(sign * 2, 4, sign * 4, 0, sign * 6, 0)
                    .lineRel(sign * 3, 0).moveRel(-sign * 4, -4)
                    .lineRel(sign * 4, 4).lineRel(-sign * 4, 4), class: "annotation-direction")
            }
            inner.render(out, x: x + (width - inner.width) / 2, y: y + 48, hDir: hDir)
        }
    }
}

/// Fading dots leading into a rail.
public struct RailroadContinuationStart: RailroadNode {
    public init() {}

    public var entryHeight: Int { 5 }
    public var height: Int { 10 }
    public var width: Int { 30 }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        out.group(class: "continuation-start") {
            railroadEmitContinuation(out, x: x, y: y, hDir: hDir, isStart: true)
        }
    }
}

/// A rail leading into fading dots.
public struct RailroadContinuationEnd: RailroadNode {
    public init() {}

    public var entryHeight: Int { 5 }
    public var height: Int { 10 }
    public var width: Int { 30 }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        out.group(class: "continuation-end") {
            railroadEmitContinuation(out, x: x, y: y, hDir: hDir, isStart: false)
        }
    }
}

/// Dots between two short continuation rails.
public struct RailroadContinuation: RailroadNode {
    public init() {}

    public var entryHeight: Int { 5 }
    public var height: Int { 10 }
    public var width: Int { 38 }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        out.group(class: "continuation") {
            for offset in [11, 19, 27] {
                out.circle(cx: x + offset, cy: y + 5, radius: 2.5, opacity: "0.5")
            }
            out.path(RailroadPathData(hDir).moveTo(x, y + 5).horizontal(6)
                .moveTo(x + 32, y + 5).horizontal(6))
        }
    }
}

fileprivate func railroadEmitContinuation(_ out: RailroadRenderer, x: Int, y: Int,
                                           hDir: RailroadHDir, isStart: Bool) {
    for (offset, opacity) in [(3, "0.25"), (11, "0.6"), (19, "1")] {
        out.circle(cx: x + (isStart ? offset : 30 - offset), cy: y + 5, radius: 2.5, opacity: opacity)
    }
    out.path(RailroadPathData(hDir).moveTo(x + (isStart ? 24 : 0), y + 5).horizontal(6))
}
