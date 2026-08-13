import Foundation

extension CommandSignature {
    /// Validates the complete flattened signature without parsing arguments.
    ///
    /// Use this when registering commands or generating metadata so malformed
    /// definitions fail before a particular command happens to be invoked.
    public func validate() throws(CommanderError) {
        _ = try CommandSignatureIndex(validating: self.flattened())
    }
}

struct CommandSignatureIndex: Sendable {
    let options: [CommandNameKey: OptionDefinition]
    let flags: [CommandNameKey: String]
    let optionShortNames: Set<Character>
    let flagShortNames: Set<Character>

    init(validating signature: CommandSignature) throws(CommanderError) {
        if let variadicIndex = signature.arguments.firstIndex(where: { $0.parsing == .remaining }),
           variadicIndex != signature.arguments.index(before: signature.arguments.endIndex)
        {
            throw CommanderError.invalidArgumentOrder(signature.arguments[variadicIndex].label)
        }

        var optionLookup: [CommandNameKey: OptionDefinition] = [:]
        for definition in signature.options {
            for name in definition.names {
                let key = CommandNameKey(name)
                if let existing = optionLookup[key] {
                    throw CommanderError.duplicateOptionName(
                        spelling: key.spelling,
                        firstLabel: existing.label,
                        duplicateLabel: definition.label)
                }
                optionLookup[key] = definition
            }
        }

        var flagLookup: [CommandNameKey: String] = [:]
        for definition in signature.flags {
            for name in definition.names {
                let key = CommandNameKey(name)
                if let existingLabel = flagLookup[key] {
                    throw CommanderError.duplicateFlagName(
                        spelling: key.spelling,
                        firstLabel: existingLabel,
                        duplicateLabel: definition.label)
                }
                if let option = optionLookup[key] {
                    throw CommanderError.conflictingName(
                        spelling: key.spelling,
                        optionLabel: option.label,
                        flagLabel: definition.label)
                }
                flagLookup[key] = definition.label
            }
        }

        self.options = optionLookup
        self.flags = flagLookup
        self.optionShortNames = Set(optionLookup.keys.compactMap(\.shortComponent))
        self.flagShortNames = Set(flagLookup.keys.compactMap(\.shortComponent))
    }
}

enum CommandNameKey: Hashable, Sendable {
    case long(String)
    case short(Character)

    init(_ name: CommanderName) {
        switch name {
        case let .long(value), let .aliasLong(value):
            self = .long(value)
        case let .short(value), let .aliasShort(value):
            self = .short(value)
        }
    }

    var spelling: String {
        switch self {
        case let .long(value):
            "--\(value)"
        case let .short(value):
            "-\(value)"
        }
    }

    var shortComponent: Character? {
        if case let .short(value) = self {
            return value
        }
        return nil
    }
}
