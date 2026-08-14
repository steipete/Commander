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
        self.signature = signature.flattened()
    }

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
        let nameLookups = try CommandSignatureIndex(validating: self.signature)
        let joinedOptionShortNames = Set(self.signature.options.flatMap(\.joinedShortNames))
        let tokens = CommandLineTokenizer.tokenize(
            arguments,
            optionShortNames: nameLookups.optionShortNames,
            joinedOptionShortNames: joinedOptionShortNames,
            flagShortNames: nameLookups.flagShortNames)
        let shortTokenContext = ShortTokenContext(
            optionLookup: nameLookups.options,
            flagLookup: nameLookups.flags,
            tokens: tokens)
        var positional: [String] = []
        var options: [String: [String]] = [:]
        var flags = Set<String>()

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            index += 1
            switch token {
            case let .option(name, attachedValue):
                let nameKey = CommandNameKey.long(name)
                if let definition = nameLookups.options[nameKey] {
                    let consumed = try Self.consumeOption(
                        definition,
                        displayName: "--\(name)",
                        attachedValue: attachedValue,
                        tokens: tokens,
                        index: &index)
                    options[definition.label, default: []].append(contentsOf: consumed)
                } else if attachedValue == nil, let flagLabel = nameLookups.flags[nameKey] {
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
                positional.append(contentsOf: tokens[index...].map(\.rawValue))
                index = tokens.endIndex
            }
        }

        try self.validate(positional: positional, options: options)

        return ParsedValues(positional: positional, options: options, flags: flags)
    }

    private struct ShortTokenContext {
        let optionLookup: [CommandNameKey: OptionDefinition]
        let flagLookup: [CommandNameKey: String]
        let tokens: [Token]
    }

    private func validate(positional: [String], options: [String: [String]]) throws {
        let acceptsRemainingArguments = self.signature.arguments.last?.parsing == .remaining
        if !acceptsRemainingArguments, positional.count > self.signature.arguments.count {
            throw CommanderError.unexpectedArgument(positional[self.signature.arguments.count])
        }
        for (index, definition) in self.signature.arguments.enumerated()
            where !definition.isOptional && index >= positional.count
        {
            throw CommanderError.missingArgument(definition.label)
        }
        if let missing = self.signature.options.first(where: {
            !$0.isOptional && options[$0.label]?.isEmpty != false
        }) {
            throw CommanderError.missingValue(option: Self.displayName(for: missing))
        }
    }

    private static func displayName(for definition: OptionDefinition) -> String {
        let preferredName = definition.names.first(where: { !$0.isAlias }) ?? definition.names.first
        return preferredName.map { CommandNameKey($0).spelling } ?? definition.label
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
        let firstNameKey = CommandNameKey.short(firstName)

        if body.count == 1 {
            if let definition = context.optionLookup[firstNameKey] {
                let consumed = try Self.consumeOption(
                    definition,
                    displayName: "-\(firstName)",
                    attachedValue: nil,
                    tokens: context.tokens,
                    index: &index)
                options[definition.label, default: []].append(contentsOf: consumed)
            } else if let flagLabel = context.flagLookup[firstNameKey] {
                flags.insert(flagLabel)
            } else {
                throw CommanderError.unknownOption("-\(firstName)")
            }
            return
        }

        if let definition = context.optionLookup[firstNameKey], definition.joinedShortNames.contains(firstName) {
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
            guard let flagLabel = context.flagLookup[.short(name)] else {
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
}
