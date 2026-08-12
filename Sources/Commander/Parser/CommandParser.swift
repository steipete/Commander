import Foundation

/// Parsed representation of `argv` after running ``CommandParser``.
public struct ParsedValues: Sendable, Equatable {
    public var positional: [String]
    public var options: [String: [String]]
    public var flags: Set<String>

    public init(positional: [String], options: [String: [String]], flags: Set<String>) {
        self.positional = positional
        self.options = options
        self.flags = flags
    }
}

/// Consumes tokenized arguments using a ``CommandSignature``.
public struct CommandParser: Sendable {
    let signature: CommandSignature

    public init(signature: CommandSignature) {
        self.signature = signature
    }

    // swiftlint:disable function_body_length
    /// Tokenizes the supplied arguments and groups them into positional
    /// values, options, and flags.
    ///
    /// - Parameter arguments: Raw tokens (the `argv` tail after the command
    ///   path has been resolved).
    /// - Returns: A ``ParsedValues`` payload suitable for dependency injection
    ///   or validation.
    /// - Throws: ``CommanderError`` when the arguments do not satisfy the
    ///   signature (unknown option, missing value, etc.).
    public func parse(arguments: [String]) throws -> ParsedValues {
        try self.validateArgumentDefinitions()
        let optionLookup = Self.buildOptionLookup(self.signature.options)
        let flagLookup = Self.buildFlagLookup(self.signature.flags)
        let optionShortNames = Set(self.signature.options.flatMap(\.names).compactMap(\.shortComponent))
        let joinedOptionShortNames = Set(self.signature.options.flatMap(\.joinedShortNames))
        let flagShortNames = Set(self.signature.flags.flatMap(\.names).compactMap(\.shortComponent))
        let tokens = CommandLineTokenizer.tokenize(
            arguments,
            optionShortNames: optionShortNames,
            joinedOptionShortNames: joinedOptionShortNames,
            flagShortNames: flagShortNames)
        let shortTokenContext = ShortTokenContext(
            optionLookup: optionLookup,
            flagLookup: flagLookup,
            tokens: tokens)
        var positional: [String] = []
        var options: [String: [String]] = [:]
        var flags = Set<String>()

        let remainingOption = self.signature.options.first(where: { $0.parsing == .remaining })

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            index += 1
            switch token {
            case let .option(name, attachedValue):
                if let definition = optionLookup[name] {
                    let consumed = try Self.consumeOption(
                        definition,
                        displayName: "--\(name)",
                        attachedValue: attachedValue,
                        tokens: tokens,
                        index: &index)
                    options[definition.label, default: []].append(contentsOf: consumed)
                } else if attachedValue == nil, let flagLabel = flagLookup[name] {
                    flags.insert(flagLabel)
                } else {
                    throw CommanderError.unknownOption(token.rawValue)
                }
            case let .short(body):
                try Self.consumeShortToken(
                    body,
                    context: shortTokenContext,
                    index: &index,
                    options: &options,
                    flags: &flags)
            case let .argument(value):
                positional.append(value)
            case .terminator:
                if let remainingOption {
                    let tail = tokens[index...].map(\.rawValue)
                    index = tokens.endIndex
                    if !tail.isEmpty {
                        options[remainingOption.label, default: []].append(contentsOf: tail)
                    }
                } else {
                    positional.append(contentsOf: tokens[index...].map(\.rawValue))
                    index = tokens.endIndex
                }
            }
        }

        try self.validate(positional: positional)

        return ParsedValues(positional: positional, options: options, flags: flags)
    }

    // swiftlint:enable function_body_length

    private struct ShortTokenContext {
        let optionLookup: [String: OptionDefinition]
        let flagLookup: [String: String]
        let tokens: [Token]
    }

    private func validateArgumentDefinitions() throws {
        guard let variadicIndex = self.signature.arguments.firstIndex(where: { $0.parsing == .remaining }) else {
            return
        }
        guard variadicIndex == self.signature.arguments.index(before: self.signature.arguments.endIndex) else {
            throw CommanderError.invalidArgumentOrder(self.signature.arguments[variadicIndex].label)
        }
    }

    private func validate(positional: [String]) throws {
        let acceptsRemainingArguments = self.signature.arguments.last?.parsing == .remaining
        if !acceptsRemainingArguments, positional.count > self.signature.arguments.count {
            throw CommanderError.unexpectedArgument(positional[self.signature.arguments.count])
        }
        for (index, definition) in self.signature.arguments.enumerated()
            where !definition.isOptional && index >= positional.count
        {
            throw CommanderError.missingArgument(definition.label)
        }
    }

    private static func consumeShortToken(
        _ body: String,
        context: ShortTokenContext,
        index: inout Int,
        options: inout [String: [String]],
        flags: inout Set<String>) throws
    {
        guard let firstName = body.first else {
            throw CommanderError.unknownOption("-")
        }

        if body.count == 1 {
            let name = String(firstName)
            if let definition = context.optionLookup[name] {
                let consumed = try Self.consumeOption(
                    definition,
                    displayName: "-\(name)",
                    attachedValue: nil,
                    tokens: context.tokens,
                    index: &index)
                options[definition.label, default: []].append(contentsOf: consumed)
            } else if let flagLabel = context.flagLookup[name] {
                flags.insert(flagLabel)
            } else {
                throw CommanderError.unknownOption("-\(name)")
            }
            return
        }

        if let definition = context.optionLookup[String(firstName)], definition.joinedShortNames.contains(firstName) {
            var attachedValue = String(body.dropFirst())
            if attachedValue.first == "=" {
                attachedValue.removeFirst()
            }
            let consumed = try Self.consumeOption(
                definition,
                displayName: "-\(firstName)",
                attachedValue: attachedValue,
                tokens: context.tokens,
                index: &index)
            options[definition.label, default: []].append(contentsOf: consumed)
            return
        }

        for name in body {
            guard let flagLabel = context.flagLookup[String(name)] else {
                throw CommanderError.unknownOption("-\(name)")
            }
            flags.insert(flagLabel)
        }
    }

    private static func consumeOption(
        _ definition: OptionDefinition,
        displayName: String,
        attachedValue: String?,
        tokens: [Token],
        index: inout Int) throws -> [String]
    {
        var consumed = attachedValue.map { [$0] } ?? []
        switch definition.parsing {
        case .singleValue:
            if attachedValue != nil {
                return consumed
            }
            guard index < tokens.count, case let .argument(value) = tokens[index] else {
                throw CommanderError.missingValue(option: displayName)
            }
            consumed.append(value)
            index += 1
        case .upToNextOption:
            while index < tokens.count, case let .argument(value) = tokens[index] {
                consumed.append(value)
                index += 1
            }
        case .remaining:
            consumed.append(contentsOf: tokens[index...].map(\.rawValue))
            index = tokens.endIndex
        }
        return consumed
    }

    private static func buildOptionLookup(_ definitions: [OptionDefinition]) -> [String: OptionDefinition] {
        var lookup: [String: OptionDefinition] = [:]
        for definition in definitions {
            for name in definition.names {
                if let longName = name.longComponent {
                    lookup[longName] = definition
                } else if let shortName = name.shortComponent {
                    lookup[String(shortName)] = definition
                }
            }
        }
        return lookup
    }

    private static func buildFlagLookup(_ definitions: [FlagDefinition]) -> [String: String] {
        var lookup: [String: String] = [:]
        for definition in definitions {
            for name in definition.names {
                if let longName = name.longComponent {
                    lookup[longName] = definition.label
                } else if let shortName = name.shortComponent {
                    lookup[String(shortName)] = definition.label
                }
            }
        }
        return lookup
    }
}
