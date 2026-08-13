import Foundation

/// Errors emitted by ``CommandParser`` when raw arguments cannot be bound to a
/// ``CommandSignature``.
public enum CommanderError: Error, CustomStringConvertible, Sendable, Equatable {
    case unknownOption(String)
    case missingValue(option: String)
    case missingArgument(String)
    case unexpectedArgument(String)
    case invalidArgumentOrder(String)
    case invalidValue(option: String, value: String)
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
        case let .invalidValue(option, value):
            "Invalid value '\(value)' for option \(option)"
        case let .duplicateOptionName(spelling, firstLabel, duplicateLabel):
            "Duplicate option spelling \(spelling) for '\(firstLabel)' and '\(duplicateLabel)'"
        case let .duplicateFlagName(spelling, firstLabel, duplicateLabel):
            "Duplicate flag spelling \(spelling) for '\(firstLabel)' and '\(duplicateLabel)'"
        case let .conflictingName(spelling, optionLabel, flagLabel):
            "Conflicting spelling \(spelling) for option '\(optionLabel)' and flag '\(flagLabel)'"
        }
    }
}
