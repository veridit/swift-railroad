//
//  Stylesheet.swift
//  swift-railroad
//
//  Port of `Stylesheet` in lib.rs of the railroad crate 0.3.12
//  (https://github.com/lukaslueg/railroad), Copyright (c) 2018 Lukas Lueg,
//  MIT License. The CSS files in Resources are copied unchanged from it.
//

import Foundation

/// The bundled CSS themes.
enum RailroadStylesheet: String, CaseIterable {
    case light
    case dark
    /// Light theme without CSS features that simple SVG renderers lack.
    case lightRendersafe = "light_safe"
    /// Dark theme without CSS features that simple SVG renderers lack.
    case darkRendersafe = "dark_safe"
    case rust
    case coal
    case navy
    case ayu

    var isLight: Bool {
        switch self {
        case .light, .lightRendersafe, .rust: return true
        default: return false
        }
    }

    var toDark: RailroadStylesheet {
        switch self {
        case .light, .rust: return .dark
        case .lightRendersafe, .darkRendersafe: return .darkRendersafe
        default: return self
        }
    }

    var toLight: RailroadStylesheet {
        switch self {
        case .dark, .coal, .navy, .ayu: return .light
        case .lightRendersafe, .darkRendersafe: return .lightRendersafe
        default: return self
        }
    }

    /// The CSS text.
    var css: String {
        guard let url = Bundle.module.url(forResource: "stylesheet_\(rawValue)", withExtension: "css"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            preconditionFailure("Missing bundled stylesheet_\(rawValue).css")
        }
        return text
    }
}
