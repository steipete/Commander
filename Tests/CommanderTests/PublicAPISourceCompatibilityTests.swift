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

private func publicProgramErrorCaseName(_ error: CommanderProgramError) -> String {
    switch error {
    case .missingCommand: "missingCommand"
    case .unknownCommand: "unknownCommand"
    case .duplicateCommand: "duplicateCommand"
    case .invalidCommandName: "invalidCommandName"
    case .duplicateSubcommand: "duplicateSubcommand"
    case .invalidDefaultSubcommand: "invalidDefaultSubcommand"
    case .invalidCommandSignature: "invalidCommandSignature"
    case .missingSubcommand: "missingSubcommand"
    case .unknownSubcommand: "unknownSubcommand"
    case .parsingError: "parsingError"
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

@Test
func `public command name validation case remains constructible and exhaustively matchable`() {
    let error = CommanderProgramError.invalidCommandName(path: "admin jobs --hidden", name: "--hidden")

    #expect(publicProgramErrorCaseName(error) == "invalidCommandName")
    #expect(
        error.description ==
            "Invalid command name '--hidden' at 'admin jobs --hidden'; names cannot be empty or begin with '-'")
}
