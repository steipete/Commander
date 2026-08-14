import Foundation

/// Errors emitted when validating a ``CommandSignature`` or binding raw arguments
/// with ``CommandParser``.
public enum CommanderError: Error, CustomStringConvertible, Sendable, Equatable {
    case unknownOption(String)
    case missingValue(option: String)
    case missingArgument(String)
    case unexpectedArgument(String)
    case invalidArgumentOrder(String)
    case requiredArgumentAfterOptional(optionalLabel: String, requiredLabel: String)
    case invalidValue(option: String, value: String)
    case duplicateArgumentLabel(String)
    case duplicateOptionLabel(String)
    case duplicateFlagLabel(String)
    case optionHasNoNames(String)
    case emptyOptionName(String)
    case unreachableOptionName(optionLabel: String, spelling: String)
    case flagHasNoNames(String)
    case emptyFlagName(String)
    case unreachableFlagName(flagLabel: String, spelling: String)
    case undeclaredJoinedShortName(optionLabel: String, name: Character)
    case duplicateOptionName(spelling: String, firstLabel: String, duplicateLabel: String)
    case duplicateFlagName(spelling: String, firstLabel: String, duplicateLabel: String)
    case conflictingName(spelling: String, optionLabel: String, flagLabel: String)

    public var description: String {
        switch self {
        case let .unknownOption(name):
            "Unknown option \(name)"
        case let .missingValue(option):
            "Missing value for option \(option)"
        case let .missingArgument(label):
            "Missing argument: \(label)"
        case let .unexpectedArgument(value):
            "Unexpected argument: \(value)"
        case let .invalidArgumentOrder(label):
            "Variadic argument '\(label)' must be the final positional argument"
        case let .requiredArgumentAfterOptional(optionalLabel, requiredLabel):
            "Required argument '\(requiredLabel)' cannot follow optional argument '\(optionalLabel)'"
        case let .invalidValue(option, value):
            "Invalid value '\(value)' for option \(option)"
        case let .duplicateArgumentLabel(label):
            "Duplicate argument label '\(label)'"
        case let .duplicateOptionLabel(label):
            "Duplicate option label '\(label)'"
        case let .duplicateFlagLabel(label):
            "Duplicate flag label '\(label)'"
        case let .optionHasNoNames(label):
            "Option '\(label)' must declare at least one name"
        case let .emptyOptionName(label):
            "Option '\(label)' declares an empty long name"
        case let .unreachableOptionName(optionLabel, spelling):
            "Option '\(optionLabel)' declares unreachable spelling \(spelling)"
        case let .flagHasNoNames(label):
            "Flag '\(label)' must declare at least one name"
        case let .emptyFlagName(label):
            "Flag '\(label)' declares an empty long name"
        case let .unreachableFlagName(flagLabel, spelling):
            "Flag '\(flagLabel)' declares unreachable spelling \(spelling)"
        case let .undeclaredJoinedShortName(optionLabel, name):
            "Joined short name -\(name) is not declared for option '\(optionLabel)'"
        case let .duplicateOptionName(spelling, firstLabel, duplicateLabel):
            "Duplicate option spelling \(spelling) for '\(firstLabel)' and '\(duplicateLabel)'"
        case let .duplicateFlagName(spelling, firstLabel, duplicateLabel):
            "Duplicate flag spelling \(spelling) for '\(firstLabel)' and '\(duplicateLabel)'"
        case let .conflictingName(spelling, optionLabel, flagLabel):
            "Conflicting spelling \(spelling) for option '\(optionLabel)' and flag '\(flagLabel)'"
        }
    }
}
