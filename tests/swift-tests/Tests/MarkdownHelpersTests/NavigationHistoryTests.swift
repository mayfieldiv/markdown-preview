import Foundation
import XCTest
@testable import MarkdownHelpers

final class NavigationHistoryTests: XCTestCase {
    private typealias Entry = NavigationHistory.Entry

    /// Places in one document, told apart by scroll position.
    private let doc = URL(fileURLWithPath: "/tmp/doc.md")
    private func place(_ name: String) -> Entry {
        let positions = ["TOC": 0, "A": 100, "B": 200, "C": 300, "D": 400, "E": 500]
        return Entry(url: doc, scrollPosition: CGFloat(positions[name]!))
    }
    private func name(_ entry: Entry) -> String {
        ["TOC", "A", "B", "C", "D", "E"][Int(entry.scrollPosition) / 100]
    }

    private struct Reader {
        var history = NavigationHistory()
        var here: Entry

        mutating func follow(to place: Entry) {
            history.leave(here)
            here = place
        }

        mutating func back() {
            if let target = history.goBack(from: here) { here = target }
        }

        mutating func forward() {
            if let target = history.goForward(from: here) { here = target }
        }
    }

    private func assertState(_ reader: Reader, back: [String], here: String, forward: [String],
                             _ step: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(reader.history.back.map(name), back, "back after \(step)", file: file, line: line)
        XCTAssertEqual(name(reader.here), here, "here after \(step)", file: file, line: line)
        XCTAssertEqual(reader.history.forward.map(name), forward, "forward after \(step)", file: file, line: line)
    }

    func testFollowingALinkAfterGoingBackKeepsThePlacesAheadOnOneLine() {
        var reader = Reader(here: place("TOC"))
        reader.follow(to: place("A"))
        reader.follow(to: place("B"))
        reader.follow(to: place("C"))
        assertState(reader, back: ["TOC", "A", "B"], here: "C", forward: [], "TOC → A → B → C")

        reader.back()
        reader.back()
        reader.back()
        assertState(reader, back: [], here: "TOC", forward: ["A", "B", "C"], "back ×3")

        reader.follow(to: place("D"))
        assertState(reader, back: ["TOC", "A", "B", "C", "TOC"], here: "D", forward: [], "→ D")
        reader.follow(to: place("E"))
        assertState(reader, back: ["TOC", "A", "B", "C", "TOC", "D"], here: "E", forward: [], "→ E")

        let expected: [(back: [String], here: String, forward: [String])] = [
            (["TOC", "A", "B", "C", "TOC"], "D", ["E"]),
            (["TOC", "A", "B", "C"], "TOC", ["D", "E"]),
            (["TOC", "A", "B"], "C", ["TOC", "D", "E"]),
            (["TOC", "A"], "B", ["C", "TOC", "D", "E"]),
            (["TOC"], "A", ["B", "C", "TOC", "D", "E"]),
            ([], "TOC", ["A", "B", "C", "TOC", "D", "E"]),
            ([], "TOC", ["A", "B", "C", "TOC", "D", "E"]),
        ]
        for (index, state) in expected.enumerated() {
            reader.back()
            assertState(reader, back: state.back, here: state.here, forward: state.forward,
                        "back #\(index + 1) from E")
        }

        for _ in 0..<6 { reader.forward() }
        assertState(reader, back: ["TOC", "A", "B", "C", "TOC", "D"], here: "E", forward: [],
                    "forward ×6 back to E")
    }

    func testFollowingALinkWithNothingAheadIsAPlainBrowserStep() {
        var reader = Reader(here: place("TOC"))
        reader.follow(to: place("A"))
        reader.back()
        reader.forward()
        reader.follow(to: place("B"))
        assertState(reader, back: ["TOC", "A"], here: "B", forward: [], "TOC → A, back, forward, → B")
    }

    // Scrolling is not navigation, so the reader can scroll back up to the
    // table of contents by hand and follow the same link again.
    func testFollowingTheSameLinkAgainFromTheSameSpotAddsNoStep() {
        var reader = Reader(here: place("TOC"))
        reader.follow(to: place("A"))
        reader.here = place("TOC")
        reader.follow(to: place("A"))
        assertState(reader, back: ["TOC"], here: "A", forward: [], "→ A, scroll up, → A")
    }

    func testRenamingAFileRewritesItsEntriesInBothDirections() {
        let other = URL(fileURLWithPath: "/tmp/other.md")
        let renamed = URL(fileURLWithPath: "/tmp/renamed.md")
        var history = NavigationHistory()
        history.leave(Entry(url: doc, scrollPosition: 0))
        history.leave(Entry(url: other, scrollPosition: 0))
        _ = history.goBack(from: Entry(url: doc, scrollPosition: 50))

        history.replaceURL(doc, with: renamed)

        XCTAssertEqual(history.back.map(\.url), [renamed])
        XCTAssertEqual(history.forward.map(\.url), [renamed])
    }
}
