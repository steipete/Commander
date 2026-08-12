import Foundation

/// Lexical token produced from command-line segments.
enum Token: Equatable, Sendable {
    case option(name: String, attachedValue: String?)
    case short(String)
    case argument(String)
    case terminator

    var rawValue: String {
        switch self {
        case let .option(name, attachedValue):
            if let attachedValue {
                return "--\(name)=\(attachedValue)"
            }
            return "--\(name)"
        case let .short(body):
            return "-\(body)"
        case let .argument(value):
            return value
        case .terminator:
            return "--"
        }
    }
}

/// Splits `argv` segments into Commander tokens while retaining attached values,
/// `--` terminators, and short-token bodies for signature-aware parsing.
enum CommandLineTokenizer {
    static func tokenize(
        _ argv: [String],
        optionShortNames: Set<Character> = [],
        joinedOptionShortNames: Set<Character> = [],
        flagShortNames: Set<Character> = []) -> [Token]
    {
        var result: [Token] = []
        var iterator = argv.makeIterator()
        while let segment = iterator.next() {
            if segment == "--" {
                result.append(.terminator)
                result.append(contentsOf: iterator.map { .argument($0) })
                break
            } else if segment.hasPrefix("--") {
                let body = segment.dropFirst(2)
                if let separator = body.firstIndex(of: "=") {
                    let name = String(body[..<separator])
                    let value = String(body[body.index(after: separator)...])
                    result.append(.option(name: name, attachedValue: value))
                } else {
                    result.append(.option(name: String(body), attachedValue: nil))
                }
            } else if segment.hasPrefix("-"), segment.count > 1 {
                let body = segment.dropFirst()
                if Double(segment) != nil,
                   !Self.isRecognizedShortToken(
                       body,
                       optionShortNames: optionShortNames,
                       joinedOptionShortNames: joinedOptionShortNames,
                       flagShortNames: flagShortNames)
                {
                    result.append(.argument(segment))
                } else {
                    result.append(.short(String(body)))
                }
            } else {
                result.append(.argument(segment))
            }
        }
        return result
    }

    private static func isRecognizedShortToken(
        _ body: Substring,
        optionShortNames: Set<Character>,
        joinedOptionShortNames: Set<Character>,
        flagShortNames: Set<Character>) -> Bool
    {
        if body.count == 1, let name = body.first {
            return optionShortNames.contains(name) || flagShortNames.contains(name)
        }
        if let name = body.first, joinedOptionShortNames.contains(name) {
            return true
        }
        return body.allSatisfy(flagShortNames.contains)
    }
}
