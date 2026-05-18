import Foundation

public enum JournalContentBuilder {
    public static func makeParagraphPayloads(from text: String) -> [[String: Any]] {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                [
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": [
                        "rich_text": [
                            [
                                "type": "text",
                                "text": [
                                    "content": line
                                ]
                            ]
                        ]
                    ]
                ]
            }
    }
}
