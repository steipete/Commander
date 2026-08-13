import Commander
import Testing

private func publicErrorCaseName(_ error: CommanderError) -> String {
    switch error {
    case .unknownOption: "unknownOption"
    case .missingValue: "missingValue"
    case .missingArgument: "missingArgument"
    case .unexpectedArgument: "unexpectedArgument"
    case .invalidArgumentOrder: "invalidArgumentOrder"
    case .requiredArgumentAfterOptional: "requiredArgumentAfterOptional"
    case .invalidValue: "invalidValue"
    case .duplicateArgumentLabel: "duplicateArgumentLabel"
    case .duplicateOptionLabel: "duplicateOptionLabel"
    case .duplicateFlagLabel: "duplicateFlagLabel"
    case .duplicateOptionName: "duplicateOptionName"
    case .duplicateFlagName: "duplicateFlagName"
    case .conflictingName: "conflictingName"
    }
}

@Test
func `public validation cases remain constructible and exhaustively matchable`() {
    let errors: [CommanderError] = [
        .duplicateArgumentLabel("target"),
        .duplicateOptionLabel("output"),
        .duplicateFlagLabel("verbose"),
        .requiredArgumentAfterOptional(optionalLabel: "input", requiredLabel: "output"),
    ]

    #expect(errors.map(publicErrorCaseName) == [
        "duplicateArgumentLabel",
        "duplicateOptionLabel",
        "duplicateFlagLabel",
        "requiredArgumentAfterOptional",
    ])
    #expect(errors.map(\.description) == [
        "Duplicate argument label 'target'",
        "Duplicate option label 'output'",
        "Duplicate flag label 'verbose'",
        "Required argument 'output' cannot follow optional argument 'input'",
    ])
}
