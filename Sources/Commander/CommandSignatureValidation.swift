import Foundation

extension CommandSignature {
    /// Validates the complete flattened signature without parsing arguments.
    ///
    /// Use this when registering commands or generating metadata so malformed
    /// definitions, duplicate semantic labels, and ambiguous positional ordering
    /// fail before a particular command happens to be invoked.
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
        try Self.validateArguments(signature.arguments)

        var optionLookup: [CommandNameKey: OptionDefinition] = [:]
        var optionLabels: Set<String> = []
        for definition in signature.options {
            guard optionLabels.insert(definition.label).inserted else {
                throw CommanderError.duplicateOptionLabel(definition.label)
            }
            for key in try Self.validatedOptionNameKeys(for: definition) {
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
        var flagLabels: Set<String> = []
        for definition in signature.flags {
            guard flagLabels.insert(definition.label).inserted else {
                throw CommanderError.duplicateFlagLabel(definition.label)
            }
            for key in try Self.validatedNameKeys(
                label: definition.label,
                names: definition.names,
                kind: .flag)
            {
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

    private static func validatedOptionNameKeys(
        for definition: OptionDefinition) throws(CommanderError) -> [CommandNameKey]
    {
        let keys = try Self.validatedNameKeys(
            label: definition.label,
            names: definition.names,
            kind: .option)
        let declaredShortNames = Set(keys.compactMap(\.shortComponent))

        if let undeclaredName = definition.joinedShortNames.sorted().first(where: {
            !declaredShortNames.contains($0)
        }) {
            throw CommanderError.undeclaredJoinedShortName(
                optionLabel: definition.label,
                name: undeclaredName)
        }
        return keys
    }

    private static func validatedNameKeys(
        label: String,
        names: [CommanderName],
        kind: NamedDefinitionKind) throws(CommanderError) -> [CommandNameKey]
    {
        guard !names.isEmpty else {
            throw kind.noNamesError(label: label)
        }

        var keys: [CommandNameKey] = []
        for name in names {
            let key = CommandNameKey(name)
            switch key {
            case let .long(value) where value.isEmpty:
                throw kind.emptyNameError(label: label)
            case let .long(value) where value.contains("="):
                throw kind.unreachableNameError(label: label, spelling: key.spelling)
            case .short("-"):
                throw kind.unreachableNameError(label: label, spelling: key.spelling)
            default:
                break
            }
            keys.append(key)
        }
        return keys
    }

    private static func validateArguments(_ arguments: [ArgumentDefinition]) throws(CommanderError) {
        if let variadicIndex = arguments.firstIndex(where: { $0.parsing == .remaining }),
           variadicIndex != arguments.index(before: arguments.endIndex)
        {
            throw CommanderError.invalidArgumentOrder(arguments[variadicIndex].label)
        }

        var labels: Set<String> = []
        var firstOptionalLabel: String?
        for definition in arguments {
            guard labels.insert(definition.label).inserted else {
                throw CommanderError.duplicateArgumentLabel(definition.label)
            }
            if definition.isOptional {
                firstOptionalLabel = firstOptionalLabel ?? definition.label
            } else if let firstOptionalLabel {
                throw CommanderError.requiredArgumentAfterOptional(
                    optionalLabel: firstOptionalLabel,
                    requiredLabel: definition.label)
            }
        }
    }
}

private enum NamedDefinitionKind {
    case option
    case flag

    func noNamesError(label: String) -> CommanderError {
        switch self {
        case .option:
            .optionHasNoNames(label)
        case .flag:
            .flagHasNoNames(label)
        }
    }

    func emptyNameError(label: String) -> CommanderError {
        switch self {
        case .option:
            .emptyOptionName(label)
        case .flag:
            .emptyFlagName(label)
        }
    }

    func unreachableNameError(label: String, spelling: String) -> CommanderError {
        switch self {
        case .option:
            .unreachableOptionName(optionLabel: label, spelling: spelling)
        case .flag:
            .unreachableFlagName(flagLabel: label, spelling: spelling)
        }
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
