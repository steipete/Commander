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
    case .optionHasNoNames: "optionHasNoNames"
    case .emptyOptionName: "emptyOptionName"
    case .unreachableOptionName: "unreachableOptionName"
    case .flagHasNoNames: "flagHasNoNames"
    case .emptyFlagName: "emptyFlagName"
    case .unreachableFlagName: "unreachableFlagName"
    case .undeclaredJoinedShortName: "undeclaredJoinedShortName"
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
        .optionHasNoNames("output"),
        .emptyOptionName("output"),
        .unreachableOptionName(optionLabel: "output", spelling: "--output=value"),
        .flagHasNoNames("hidden"),
        .emptyFlagName("hidden"),
        .unreachableFlagName(flagLabel: "hidden", spelling: "--"),
        .undeclaredJoinedShortName(optionLabel: "define", name: "D"),
        .requiredArgumentAfterOptional(optionalLabel: "input", requiredLabel: "output"),
    ]

    #expect(errors.map(publicErrorCaseName) == [
        "duplicateArgumentLabel",
        "duplicateOptionLabel",
        "duplicateFlagLabel",
        "optionHasNoNames",
        "emptyOptionName",
        "unreachableOptionName",
        "flagHasNoNames",
        "emptyFlagName",
        "unreachableFlagName",
        "undeclaredJoinedShortName",
        "requiredArgumentAfterOptional",
    ])
    #expect(errors.map(\.description) == [
        "Duplicate argument label 'target'",
        "Duplicate option label 'output'",
        "Duplicate flag label 'verbose'",
        "Option 'output' must declare at least one name",
        "Option 'output' declares an empty long name",
        "Option 'output' declares unreachable spelling --output=value",
        "Flag 'hidden' must declare at least one name",
        "Flag 'hidden' declares an empty long name",
        "Flag 'hidden' declares unreachable spelling --",
        "Joined short name -D is not declared for option 'define'",
        "Required argument 'output' cannot follow optional argument 'input'",
    ])
}
