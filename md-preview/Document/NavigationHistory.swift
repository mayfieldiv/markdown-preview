//
//  NavigationHistory.swift
//  md-preview
//
//  Back/forward history for one document window. Kept free of AppKit so the
//  SPM helper tests can exercise it without a GUI host.
//

import CoreGraphics
import Foundation

/// One line of places the reader has been, with the reader somewhere on it.
///
/// Following a link from partway back down the line keeps the places ahead
/// of the reader instead of discarding them, as a browser would. They move
/// behind a second copy of the place the link was followed from, so Back
/// from the new place returns there, then jumps to the furthest place the
/// reader had reached and walks the old line back down:
///
///     TOC → A → B → C, Back ×3, → D     back: TOC A B C TOC   here: D
///
/// Every Back or Forward step then moves one place along a line that no
/// longer changes, and nothing the reader visited becomes unreachable.
struct NavigationHistory {
    struct Entry: Equatable {
        let url: URL
        /// Scroll offset in CSS pixels when the reader left; restored on return.
        let scrollPosition: CGFloat
    }

    /// Oldest first; Back goes to the last element.
    private(set) var back: [Entry] = []
    /// Nearest first; Forward goes to the first element.
    private(set) var forward: [Entry] = []

    var nextBack: Entry? { back.last }
    var nextForward: Entry? { forward.first }

    /// The reader follows a link away from `departed`.
    mutating func leave(_ departed: Entry) {
        Self.append(departed, to: &back)
        for entry in forward {
            Self.append(entry, to: &back)
        }
        Self.append(departed, to: &back)
        forward.removeAll()
    }

    /// Steps back from `current`. Returns the place to show, or nil when there
    /// is nothing behind the reader.
    mutating func goBack(from current: Entry) -> Entry? {
        guard let target = back.popLast() else { return nil }
        if let next = forward.first, Self.isSamePlace(next, current) {
            forward[0] = current
        } else {
            forward.insert(current, at: 0)
        }
        return target
    }

    /// Steps forward from `current`. Returns the place to show, or nil when
    /// there is nothing ahead of the reader.
    mutating func goForward(from current: Entry) -> Entry? {
        guard !forward.isEmpty else { return nil }
        let target = forward.removeFirst()
        Self.append(current, to: &back)
        return target
    }

    /// A file was renamed; its entries follow it.
    mutating func replaceURL(_ oldURL: URL, with newURL: URL) {
        let rewrite = { (entry: Entry) in
            entry.url == oldURL ? Entry(url: newURL, scrollPosition: entry.scrollPosition) : entry
        }
        back = back.map(rewrite)
        forward = forward.map(rewrite)
    }

    /// Appends to the end of `entries`, collapsing a repeat of the place
    /// already there: a step that changes nothing on screen reads as broken.
    private static func append(_ entry: Entry, to entries: inout [Entry]) {
        if let last = entries.last, isSamePlace(last, entry) {
            entries[entries.count - 1] = entry
        } else {
            entries.append(entry)
        }
    }

    private static func isSamePlace(_ a: Entry, _ b: Entry) -> Bool {
        a.url == b.url && abs(a.scrollPosition - b.scrollPosition) < 1
    }
}
