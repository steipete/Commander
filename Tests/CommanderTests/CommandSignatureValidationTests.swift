import Commander
import Testing

private struct NamelessFlagCommand: CommanderParsable {
    @Flag(names: []) var hidden = false
}

private struct ReservedNameCommand: CommanderParsable {
    @Option(name: .customLong("key=value")) var option: String?
    @Flag(name: .customShort("-", allowingJoined: false)) var flag = false
}

@Test
func `validation rejects duplicate argument labels`() {
    let signature = CommandSignature(arguments: [
        .make(label: "target"),
        .make(label: "target", isOptional: true),
    ])

    #expect(throws: CommanderError.duplicateArgumentLabel("target")) {
        try signature.validate()
    }
}

@Test
func `validation rejects duplicate option labels across distinct spellings`() {
    let signature = CommandSignature(options: [
        .make(label: "output", names: [.long("output")]),
        .make(label: "output", names: [.long("destination")]),
    ])

    #expect(throws: CommanderError.duplicateOptionLabel("output")) {
        try signature.validate()
    }
}

@Test
func `validation rejects options without names`() {
    let signature = CommandSignature(options: [
        .make(label: "output", names: []),
    ])

    #expect(throws: CommanderError.optionHasNoNames("output")) {
        try signature.validate()
    }
}

@Test
func `validation rejects empty primary and alias long names`() {
    for name: CommanderName in [.long(""), .aliasLong("")] {
        let signature = CommandSignature(options: [
            .make(label: "output", names: [name]),
        ])

        #expect(throws: CommanderError.emptyOptionName("output")) {
            try signature.validate()
        }
    }
}

@Test
func `validation rejects joined short names absent from their option`() {
    let signature = CommandSignature(options: [
        .make(
            label: "define",
            names: [.long("define")],
            joinedShortNames: ["Z", "D"]),
    ])

    #expect(throws: CommanderError.undeclaredJoinedShortName(optionLabel: "define", name: "D")) {
        try signature.validate()
    }
}

@Test
func `validation rejects reserved primary and alias option names`() {
    let cases: [(CommanderName, String)] = [
        (.long("key=value"), "--key=value"),
        (.aliasLong("legacy=value"), "--legacy=value"),
        (.short("-"), "--"),
        (.aliasShort("-"), "--"),
    ]

    for (name, spelling) in cases {
        let signature = CommandSignature(options: [
            .make(label: "input", names: [name]),
        ])

        #expect(throws: CommanderError.unreachableOptionName(optionLabel: "input", spelling: spelling)) {
            try signature.validate()
        }
    }
}

@Test
func `validation accepts a declared joined short alias`() throws {
    let signature = CommandSignature(options: [
        .make(
            label: "define",
            names: [.long("define"), .aliasShort("D")],
            joinedShortNames: ["D"]),
    ])

    try signature.validate()
    let parsed = try CommandParser(signature: signature).parse(arguments: ["-Ddebug"])
    #expect(parsed.options["define"] == ["debug"])
}

@Test
func `validation rejects duplicate flag labels across distinct spellings`() {
    let signature = CommandSignature(flags: [
        .make(label: "verbose", names: [.long("verbose")]),
        .make(label: "verbose", names: [.long("chatty")]),
    ])

    #expect(throws: CommanderError.duplicateFlagLabel("verbose")) {
        try signature.validate()
    }
}

@Test
func `validation rejects flags without names`() {
    let signature = CommandSignature(flags: [
        .make(label: "hidden", names: []),
    ])

    #expect(throws: CommanderError.flagHasNoNames("hidden")) {
        try signature.validate()
    }
}

@Test
func `validation rejects empty primary and alias flag long names`() {
    for name: CommanderName in [.long(""), .aliasLong("")] {
        let signature = CommandSignature(flags: [
            .make(label: "hidden", names: [name]),
        ])

        #expect(throws: CommanderError.emptyFlagName("hidden")) {
            try signature.validate()
        }
    }
}

@Test
func `validation rejects reserved primary and alias flag names`() {
    let cases: [(CommanderName, String)] = [
        (.long("dry=run"), "--dry=run"),
        (.aliasLong("legacy=true"), "--legacy=true"),
        (.short("-"), "--"),
        (.aliasShort("-"), "--"),
    ]

    for (name, spelling) in cases {
        let signature = CommandSignature(flags: [
            .make(label: "dryRun", names: [name]),
        ])

        #expect(throws: CommanderError.unreachableFlagName(flagLabel: "dryRun", spelling: spelling)) {
            try signature.validate()
        }
    }
}

@Test
func `validation rejects a reflected flag without names`() {
    let signature = CommandSignature.describe(NamelessFlagCommand())

    #expect(throws: CommanderError.flagHasNoNames("hidden")) {
        try signature.validate()
    }
}

@Test
func `validation rejects reserved names reflected from property wrappers`() {
    let signature = CommandSignature.describe(ReservedNameCommand())

    #expect(throws: CommanderError.unreachableOptionName(optionLabel: "option", spelling: "--key=value")) {
        try signature.validate()
    }
}

@Test
func `validation rejects duplicate labels flattened from nested groups`() {
    let signature = CommandSignature(
        options: [
            .make(label: "output", names: [.long("output")]),
        ],
        optionGroups: [
            CommandSignature(optionGroups: [
                CommandSignature(options: [
                    .make(label: "output", names: [.long("destination")]),
                ]),
            ]),
        ])

    #expect(throws: CommanderError.duplicateOptionLabel("output")) {
        try signature.validate()
    }
}

@Test
func `aliases on one definition preserve one semantic label`() throws {
    let signature = CommandSignature(
        options: [
            .make(label: "output", names: [.long("output"), .aliasLong("destination")]),
        ],
        flags: [
            .make(label: "verbose", names: [.long("verbose"), .aliasLong("chatty")]),
        ])

    try signature.validate()
    let parsed = try CommandParser(signature: signature).parse(arguments: [
        "--output",
        "first",
        "--destination",
        "second",
        "--verbose",
        "--chatty",
    ])

    #expect(parsed.options["output"] == ["first", "second"])
    #expect(parsed.flags == ["verbose"])
}

@Test
func `validation rejects a required argument after an optional argument`() {
    let signature = CommandSignature(arguments: [
        .make(label: "input", isOptional: true),
        .make(label: "output"),
    ])

    #expect(throws: CommanderError.requiredArgumentAfterOptional(
        optionalLabel: "input",
        requiredLabel: "output"))
    {
        try signature.validate()
    }
}

@Test
func `validation rejects a required remaining argument after an optional argument`() {
    let signature = CommandSignature(arguments: [
        .make(label: "input", isOptional: true),
        .make(label: "rest", parsing: .remaining),
    ])

    #expect(throws: CommanderError.requiredArgumentAfterOptional(
        optionalLabel: "input",
        requiredLabel: "rest"))
    {
        try signature.validate()
    }
}

@Test
func `validation accepts required arguments before optional and remaining arguments`() throws {
    let signature = CommandSignature(arguments: [
        .make(label: "input"),
        .make(label: "output", isOptional: true),
        .make(label: "rest", isOptional: true, parsing: .remaining),
    ])

    try signature.validate()
}
