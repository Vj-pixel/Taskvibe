import Foundation

struct ParsedTaskDetails {
    var cleanTitle: String
    var detectedDate: Date?
    var detectedUrgency: UrgencyLevel?
}

struct NLTaskParser {
    static func parse(_ input: String) -> ParsedTaskDetails {
        var title = input
        var date: Date? = nil
        var urgency: UrgencyLevel? = nil

        // Date extraction via NSDataDetector
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(title.startIndex..., in: title)
            let matches = detector.matches(in: title, options: [], range: range)
            if let first = matches.first, let swiftRange = Range(first.range, in: title) {
                date = first.date
                title = title.replacingCharacters(in: swiftRange, with: " ")
            }
        }

        // Urgency keyword scan (highest priority first)
        let urgentPhrases = ["urgent", "asap", "!!", "right now", "critical"]
        let kindaPhrases  = ["soon", "kinda urgent", "fairly soon", "when possible"]

        for phrase in urgentPhrases {
            if let r = title.range(of: phrase, options: .caseInsensitive) {
                urgency = .urgent
                title = title.replacingCharacters(in: r, with: " ")
                break
            }
        }
        if urgency == nil {
            for phrase in kindaPhrases {
                if let r = title.range(of: phrase, options: .caseInsensitive) {
                    urgency = .kindaUrgent
                    title = title.replacingCharacters(in: r, with: " ")
                    break
                }
            }
        }

        let clean = title
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedTaskDetails(cleanTitle: clean, detectedDate: date, detectedUrgency: urgency)
    }
}
