import Foundation

/// Lexical token produced from command-line segments.
enum Token: Equatable, Sendable {
    case option(name: String)
    case flag(name: String)
    case argument(String)
    case terminator
}

/// Splits `argv` segments into Commander tokens, honoring `--` terminators and
/// short-flag packs (e.g. `-vvv`).
enum CommandLineTokenizer {
    static func tokenize(
        _ argv: [String],
        optionShortNames: Set<Character> = [],
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
                let name = String(segment.dropFirst(2))
                result.append(.option(name: name))
            } else if segment.hasPrefix("-"), segment.count > 1 {
                let body = segment.dropFirst()
                if Double(segment) != nil,
                   !Self.isRecognizedShortToken(
                       body,
                       optionShortNames: optionShortNames,
                       flagShortNames: flagShortNames)
                {
                    result.append(.argument(segment))
                } else {
                    if body.count == 1 {
                        result.append(.option(name: String(body)))
                    } else {
                        for char in body {
                            result.append(.flag(name: String(char)))
                        }
                    }
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
        flagShortNames: Set<Character>) -> Bool
    {
        if body.count == 1, let name = body.first {
            return optionShortNames.contains(name) || flagShortNames.contains(name)
        }
        return body.allSatisfy(flagShortNames.contains)
    }
}
