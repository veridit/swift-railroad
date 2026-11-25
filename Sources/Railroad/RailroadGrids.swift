// Swift port of nodes/grids.rs and nodes/containers.rs, railroad 0.3.12.
// Copyright (c) 2018 Lukas Lueg, MIT License.

import Foundation

/// Independent children laid out left to right without connecting paths.
public struct RailroadHorizontalGrid: RailroadNode {
    public init(children: [any RailroadNode] = [], attributes: [String: String] = [:]) {
        self.children = children.measured
        self.attributes = attributes
    }

    static let spacing = Railroad.arcRadius
    public var children: [any RailroadNode] = [] { didSet { children = children.measured } }
    public var attributes: [String: String] = [:]

    public var entryHeight: Int { 0 }
    public var height: Int { children.maxHeight }
    public var width: Int { children.totalWidth + max(0, children.count - 1) * Self.spacing }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        out.group(class: "horizontalgrid", attributes: attributes) {
            var runningX = x
            for child in children {
                child.render(out, x: runningX, y: y, hDir: hDir)
                runningX += child.width + Self.spacing
            }
        }
    }
}

/// Ordered selection of one or more children, allowing prefixes and suffixes to be skipped.
public struct RailroadSubsequence: RailroadNode {
    public init(children: [any RailroadNode] = [], attributes: [String: String] = [:]) {
        self.children = children.measured
        self.attributes = attributes
    }

    static let spacing = 10
    public var children: [any RailroadNode] = [] { didSet { children = children.measured } }
    public var attributes: [String: String] = [:]

    private func routingWidth(_ child: any RailroadNode) -> Int {
        max(child.width, Railroad.arcRadius * 2)
    }

    private func bypassDepth(_ child: any RailroadNode) -> Int {
        max(Railroad.arcRadius * 2, child.heightBelowEntry + Self.spacing)
    }

    public var entryHeight: Int {
        if children.count <= 1 { return children.first?.entryHeight ?? 0 }
        return RailroadPathData.padding + max(Railroad.arcRadius * 2, children.maxEntryHeight + Self.spacing)
    }
    public var height: Int {
        if children.count <= 1 { return children.first?.height ?? 0 }
        return entryHeight + max(children[0].heightBelowEntry,
                                 children.dropFirst().map(bypassDepth).max()! + RailroadPathData.padding)
    }
    public var width: Int {
        if children.count <= 1 { return children.first?.width ?? 0 }
        return children.map(routingWidth).reduce(0, +) + (children.count * 4 - 2) * Railroad.arcRadius
    }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        out.group(class: "subsequence", attributes: attributes) {
            if children.count <= 1 {
                children.first?.render(out, x: x, y: y, hDir: hDir)
                return
            }
            let r = Railroad.arcRadius
            let baseline = y + entryHeight
            let upperY = y + RailroadPathData.padding
            out.path(RailroadPathData(hDir).moveTo(x, baseline)
                .arc(r, .westToNorth).vertical(upperY - baseline + r * 2).arc(r, .southToEast))
            var branchX = x
            for (index, child) in children.enumerated() {
                let routing = routingWidth(child)
                let childX = branchX + r * 2
                let endX = childX + routing + (index == 0 ? 0 : r * 2)
                if index + 1 < children.count {
                    let startX = index == 0 ? childX : branchX
                    out.path(RailroadPathData(hDir).moveTo(startX, upperY).horizontal(endX - startX))
                }
                out.path(RailroadPathData(hDir).moveTo(branchX, baseline).horizontal(r * 2))
                child.render(out, x: childX, y: baseline - child.entryHeight, hDir: hDir)
                out.path(RailroadPathData(hDir).moveTo(childX + child.width, baseline)
                    .horizontal(endX - childX - child.width))
                if index > 0 {
                    out.path(RailroadPathData(hDir).moveTo(branchX, upperY)
                        .arc(r, .westToSouth).vertical(baseline - upperY - r * 2).arc(r, .northToEast))
                    let depth = bypassDepth(child)
                    out.path(RailroadPathData(hDir).moveTo(branchX, baseline)
                        .arc(r, .westToSouth).vertical(depth - r * 2).arc(r, .northToEast)
                        .horizontal(routing).arc(r, .westToNorth).vertical(r * 2 - depth).arc(r, .southToEast))
                }
                branchX = endX
            }
        }
    }
}

/// Alternatives in columns, with separate entry and exit routing for each alternative.
public struct RailroadMultiChoice: RailroadNode {
    public init(columns: [[any RailroadNode]] = [], attributes: [String: String] = [:]) {
        self.columns = columns.map(\.measured)
        self.attributes = attributes
    }

    static let spacing = 10
    static let columnSpacing = Railroad.arcRadius
    public var columns: [[any RailroadNode]] = [] { didSet { columns = columns.map(\.measured) } }
    public var attributes: [String: String] = [:]

    private struct ColumnLayout {
        let children: [any RailroadNode]
        let xOffset: Int
        var yOffset: Int
        let width: Int
        let height: Int
        let entryHeight: Int
        let maxChildWidth: Int
        let childYOffsets: [Int]
    }

    private var layout: [ColumnLayout] {
        let active = columns.filter { !$0.isEmpty }
        let r = Railroad.arcRadius
        let topPadding = active.count > 1 ? r * 2 : 0
        var xOffset = 0
        var result: [ColumnLayout] = []
        for children in active {
            let choice = RailroadChoice(children: children)
            let width = active.count > 1 ? r * 3 + children.maxWidth : choice.width
            var offsets = [0]
            if children.count > 1 {
                var runningY = children[0].entryHeight + max(r, Self.spacing + children[0].heightBelowEntry)
                for child in children.dropFirst() {
                    offsets.append(runningY + max(0, r - child.entryHeight))
                    runningY += max(r, child.entryHeight) + child.heightBelowEntry + Self.spacing
                }
            }
            result.append(ColumnLayout(children: children, xOffset: xOffset, yOffset: topPadding,
                                       width: width, height: choice.height, entryHeight: children[0].entryHeight,
                                       maxChildWidth: children.maxWidth, childYOffsets: offsets))
            xOffset += width + Self.columnSpacing
        }
        if result.count > 1 {
            let clearance = max(0, r - result[0].entryHeight)
            for i in result.indices { result[i].yOffset += clearance }
            let entryY = result[0].yOffset + result[0].entryHeight
            for i in result.indices.dropFirst() {
                let gap = result[i].yOffset + result[i].entryHeight - entryY
                if gap != 0 && gap < r * 2 { result[i].yOffset += r * 2 - gap }
            }
        }
        return result
    }

    private func dimensions(_ layout: [ColumnLayout]) -> (entry: Int, height: Int, width: Int) {
        guard let first = layout.first else { return (0, 0, 0) }
        if layout.count == 1 { return (first.entryHeight, first.height, first.width) }
        let r = Railroad.arcRadius
        let bottom = layout.map { $0.yOffset + $0.height }.max()!
        let maxEntry = layout.map { column in
            zip(column.childYOffsets, column.children).map { column.yOffset + $0.0 + $0.1.entryHeight }.max()!
        }.max()!
        let last = layout.last!
        return (first.yOffset + first.entryHeight, max(bottom + r * 2, maxEntry + r * 3),
                last.xOffset + last.width + r)
    }

    public var entryHeight: Int { dimensions(layout).entry }
    public var height: Int { dimensions(layout).height }
    public var width: Int { dimensions(layout).width }

    private func sectionedVertical(_ out: RailroadRenderer, hDir: RailroadHDir, x: Int,
                                   startY: Int, ends: [Int], finalY: Int) {
        var runningY = startY
        for end in ends {
            out.path(RailroadPathData(hDir).moveTo(x, runningY).vertical(end - runningY))
            runningY = end
        }
        if finalY > runningY {
            out.path(RailroadPathData(hDir).moveTo(x, runningY).vertical(finalY - runningY))
        }
    }

    public func render(_ out: RailroadRenderer, x: Int, y: Int, hDir: RailroadHDir) {
        let layout = layout
        let geo = dimensions(layout)
        out.group(class: "multichoice", attributes: attributes) {
            if layout.isEmpty {
                out.path(RailroadPathData(hDir).moveTo(x, y + geo.entry).horizontal(geo.width))
                return
            }
            let r = Railroad.arcRadius
            let activeCount = layout.count
            let exitX = x + geo.width
            let exitY = y + geo.entry
            let routeY = y + geo.height - r
            let finalJoinX = exitX - r * 2
            let finalSpineX = exitX - r
            var underpassJoins: [Int] = []
            var finalMergeStarts: [Int] = []
            if activeCount > 1 {
                let topY = y + r
                out.path(RailroadPathData(hDir).moveTo(x, exitY).arc(r, .westToNorth)
                    .vertical(topY - exitY + r * 2).arc(r, .southToEast))
                var runningX = x + r * 2
                for column in layout.dropFirst().dropLast() {
                    let nextX = x + column.xOffset
                    out.path(RailroadPathData(hDir).moveTo(runningX, topY).horizontal(nextX - runningX))
                    runningX = nextX
                }
                out.path(RailroadPathData(hDir).moveTo(runningX, topY)
                    .horizontal(x + layout.last!.xOffset - runningX))
            }
            for (columnIndex, column) in layout.enumerated() {
                let children = column.children
                let columnX = x + column.xOffset
                let columnY = y + column.yOffset
                let columnEntryY = columnY + column.entryHeight
                let leftPadding = activeCount > 1 ? r * 2 : (children.count > 1 ? r * 2 : 0)
                let branchX = columnX + min(r, leftPadding)
                let childX = columnX + leftPadding
                let isFinal = columnIndex == activeCount - 1
                let routeX = columnX + column.width
                var columnMergeStarts: [Int] = []
                if columnIndex == 0 {
                    out.path(RailroadPathData(hDir).moveTo(x, exitY).horizontal(childX - x))
                } else {
                    let topY = y + r
                    out.path(RailroadPathData(hDir).moveTo(branchX - r, topY).arc(r, .westToSouth)
                        .vertical(columnEntryY - topY - r * 2).arc(r, .northToEast))
                }
                if children.count > 1 {
                    let branchYs = children.indices.dropFirst().map {
                        columnY + column.childYOffsets[$0] + children[$0].entryHeight - r
                    }
                    let last = children.count - 1
                    let bottomY = columnY + column.childYOffsets[last] + children[last].entryHeight - r
                    if columnIndex == 0 {
                        out.path(RailroadPathData(hDir).moveTo(columnX, columnEntryY).arc(r, .westToSouth))
                    }
                    sectionedVertical(out, hDir: hDir, x: branchX,
                                      startY: columnEntryY + (columnIndex == 0 ? r : -r),
                                      ends: branchYs, finalY: bottomY)
                }
                for (row, child) in children.enumerated() {
                    let childY = columnY + column.childYOffsets[row]
                    let childEntryY = childY + child.entryHeight
                    if row > 0 {
                        out.path(RailroadPathData(hDir).moveTo(branchX, childEntryY - r)
                            .arc(r, .northToEast).horizontal(childX - branchX - r))
                    }
                    child.render(out, x: childX, y: childY, hDir: hDir)
                    let rightX = childX + child.width
                    let paddedRightX = childX + column.maxChildWidth
                    if activeCount == 1 {
                        if row == 0 {
                            out.path(RailroadPathData(hDir).moveTo(rightX, childEntryY)
                                .horizontalWithClearance(exitX - rightX, above: childEntryY - y,
                                                         below: y + geo.height - childEntryY))
                        } else {
                            out.path(RailroadPathData(hDir).moveTo(rightX, childEntryY)
                                .horizontalWithClearance(paddedRightX - rightX, above: childEntryY - y,
                                                         below: y + geo.height - childEntryY).arc(r, .westToNorth))
                            finalMergeStarts.append(childEntryY - r)
                        }
                    } else if isFinal {
                        if childEntryY == exitY {
                            out.path(RailroadPathData(hDir).moveTo(rightX, childEntryY)
                                .horizontal(paddedRightX - rightX).horizontal(exitX - paddedRightX))
                        } else {
                            out.path(RailroadPathData(hDir).moveTo(rightX, childEntryY)
                                .horizontal(paddedRightX - rightX).arc(r, .westToNorth))
                            finalMergeStarts.append(childEntryY - r)
                        }
                    } else {
                        out.path(RailroadPathData(hDir).moveTo(rightX, childEntryY)
                            .horizontal(paddedRightX - rightX).arc(r, .westToSouth))
                        columnMergeStarts.append(childEntryY + r)
                    }
                }
                if activeCount > 1 && !isFinal {
                    let starts = Set(columnMergeStarts).sorted()
                    if let first = starts.first {
                        var runningY = first
                        for nextY in starts.dropFirst() {
                            out.path(RailroadPathData(hDir).moveTo(routeX, runningY).vertical(nextY - runningY))
                            runningY = nextY
                        }
                        out.path(RailroadPathData(hDir).moveTo(routeX, runningY)
                            .vertical(routeY - r - runningY).arc(r, .northToEast))
                        underpassJoins.append(routeX + r)
                    }
                }
            }
            let joins = Set(underpassJoins).sorted()
            if let first = joins.first {
                var runningX = first
                for nextX in joins.dropFirst() {
                    out.path(RailroadPathData(hDir).moveTo(runningX, routeY).horizontal(nextX - runningX))
                    runningX = nextX
                }
                out.path(RailroadPathData(hDir).moveTo(runningX, routeY)
                    .horizontal(finalJoinX - runningX).arc(r, .westToNorth))
                finalMergeStarts.append(routeY - r)
            }
            let starts = Set(finalMergeStarts).sorted().filter { $0 >= exitY + r }
            if let lowest = starts.last {
                var runningY = lowest
                for nextY in starts.dropLast().reversed() {
                    out.path(RailroadPathData(hDir).moveTo(finalSpineX, runningY).vertical(nextY - runningY))
                    runningY = nextY
                }
                out.path(RailroadPathData(hDir).moveTo(finalSpineX, runningY)
                    .vertical(exitY + r - runningY).arc(r, .southToEast))
            }
        }
    }
}
