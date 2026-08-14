import Testing
@testable import Commander

private let signature = CommandSignature(
    arguments: [ArgumentDefinition(label: "path", help: nil, isOptional: false)],
    options: [
        OptionDefinition(label: "app", names: [.long("app")], help: nil, parsing: .singleValue),
        OptionDefinition(label: "includes", names: [.long("include")], help: nil, parsing: .upToNextOption),
        OptionDefinition(label: "rest", names: [.long("rest")], help: nil, parsing: .remaining),
    ],
    flags: [FlagDefinition(label: "dryRun", names: [.long("dry-run")], help: nil)])

private func requireSendable(_ value: some Sendable) {}

@Test
func `parses options flags and arguments`() throws {
    let parser = CommandParser(signature: signature)
    let values = try parser.parse(arguments: [
        "Project",
        "--app",
        "Safari",
        "--dry-run",
        "--include",
        "a",
        "b",
        "--rest",
        "tail1",
        "tail2",
    ])

    #expect(values.options["app"] == ["Safari"])
    #expect(values.flags.contains("dryRun"))
    #expect(values.options["includes"] == ["a", "b"])
    #expect(values.options["rest"] == ["tail1", "tail2"])
    #expect(values.positional == ["Project"])
}

@Test
func `terminator does not activate an unselected remaining option`() throws {
    let signature = CommandSignature(
        arguments: [.make(label: "values", isOptional: true, parsing: .remaining)],
        options: [.make(label: "rest", names: [.long("rest")], parsing: .remaining)])

    let parsed = try CommandParser(signature: signature).parse(arguments: ["--", "tail"])

    #expect(parsed.positional == ["tail"])
    #expect(parsed.options["rest"] == nil)
}

@Test
func `errors on unknown option`() {
    let parser = CommandParser(signature: signature)
    #expect(throws: CommanderError.unknownOption("--foo")) {
        _ = try parser.parse(arguments: ["--foo"])
    }
}

@Test
func `parser rejects duplicate option spellings deterministically`() {
    let signature = CommandSignature(options: [
        .make(label: "primaryOutput", names: [.long("output")]),
        .make(label: "legacyOutput", names: [.aliasLong("output")]),
    ])
    let expected = CommanderError.duplicateOptionName(
        spelling: "--output",
        firstLabel: "primaryOutput",
        duplicateLabel: "legacyOutput")

    #expect(throws: expected) {
        _ = try CommandParser(signature: signature).parse(arguments: [])
    }
    #expect(expected.description == "Duplicate option spelling --output for 'primaryOutput' and 'legacyOutput'")
}

@Test
func `parser rejects unreachable joined short metadata before tokenization`() {
    let signature = CommandSignature(options: [
        .make(
            label: "define",
            names: [.long("define")],
            joinedShortNames: ["D"]),
    ])

    #expect(throws: CommanderError.undeclaredJoinedShortName(optionLabel: "define", name: "D")) {
        _ = try CommandParser(signature: signature).parse(arguments: ["-Ddebug"])
    }
}

@Test
func `parser rejects reserved option names before tokenization`() {
    let cases: [(OptionDefinition, CommanderError)] = [
        (
            .make(label: "input", names: [.aliasLong("key=value")]),
            .unreachableOptionName(optionLabel: "input", spelling: "--key=value")),
        (
            .make(label: "input", names: [.aliasShort("-")]),
            .unreachableOptionName(optionLabel: "input", spelling: "--")),
    ]

    for (definition, expectedError) in cases {
        let signature = CommandSignature(options: [definition])
        #expect(throws: expectedError) {
            _ = try CommandParser(signature: signature).parse(arguments: [])
        }
    }
}

@Test
func `parser rejects duplicate option labels before consuming input`() {
    let signature = CommandSignature(options: [
        .make(label: "output", names: [.long("output")]),
        .make(label: "output", names: [.long("destination")]),
    ])

    #expect(throws: CommanderError.duplicateOptionLabel("output")) {
        _ = try CommandParser(signature: signature).parse(arguments: ["--destination", "result.txt"])
    }
}

@Test
func `parser rejects duplicate flag spellings deterministically`() {
    let signature = CommandSignature(flags: [
        .make(label: "verbose", names: [.short("v")]),
        .make(label: "trace", names: [.aliasShort("v")]),
    ])

    #expect(throws: CommanderError.duplicateFlagName(
        spelling: "-v",
        firstLabel: "verbose",
        duplicateLabel: "trace"))
    {
        _ = try CommandParser(signature: signature).parse(arguments: [])
    }
}

@Test
func `parser rejects unreachable flag names before tokenization`() {
    let cases: [(FlagDefinition, CommanderError)] = [
        (.make(label: "hidden", names: []), .flagHasNoNames("hidden")),
        (.make(label: "hidden", names: [.aliasLong("")]), .emptyFlagName("hidden")),
        (
            .make(label: "hidden", names: [.aliasLong("hidden=true")]),
            .unreachableFlagName(flagLabel: "hidden", spelling: "--hidden=true")),
        (
            .make(label: "hidden", names: [.aliasShort("-")]),
            .unreachableFlagName(flagLabel: "hidden", spelling: "--")),
    ]

    for (definition, expectedError) in cases {
        let signature = CommandSignature(flags: [definition])
        #expect(throws: expectedError) {
            _ = try CommandParser(signature: signature).parse(arguments: [])
        }
    }
}

@Test
func `parser rejects option flag spelling collisions`() {
    let signature = CommandSignature(
        options: [
            .make(label: "output", names: [.long("output")]),
        ],
        flags: [
            .make(label: "printOutput", names: [.aliasLong("output")]),
        ])

    #expect(throws: CommanderError.conflictingName(
        spelling: "--output",
        optionLabel: "output",
        flagLabel: "printOutput"))
    {
        _ = try CommandParser(signature: signature).parse(arguments: [])
    }
}

@Test
func `parser keeps distinct short and long spellings with the same component`() throws {
    let signature = CommandSignature(
        options: [
            .make(label: "longX", names: [.long("x")]),
        ],
        flags: [
            .make(label: "shortX", names: [.short("x")]),
        ])
    let parsed = try CommandParser(signature: signature).parse(arguments: ["--x", "value", "-x"])

    #expect(parsed.options["longX"] == ["value"])
    #expect(parsed.flags == ["shortX"])
}

@Test
func `errors on unexpected argument when command has no positional arguments`() {
    let parser = CommandParser(signature: CommandSignature())
    #expect(throws: CommanderError.unexpectedArgument("extra")) {
        _ = try parser.parse(arguments: ["extra"])
    }
}

@Test
func `errors on excess positional arguments`() {
    let signature = CommandSignature(arguments: [
        .make(label: "input"),
    ])

    #expect(throws: CommanderError.unexpectedArgument("extra")) {
        _ = try CommandParser(signature: signature).parse(arguments: ["file.txt", "extra"])
    }
}

@Test
func `remaining positional argument accepts multiple values`() throws {
    let signature = CommandSignature(arguments: [
        .make(label: "chord", parsing: .remaining),
    ])
    let parsed = try CommandParser(signature: signature).parse(arguments: ["cmd+a", "cmd+c"])

    #expect(parsed.positional == ["cmd+a", "cmd+c"])
}

@Test
func `required remaining positional argument still requires a value`() {
    let signature = CommandSignature(arguments: [
        .make(label: "chord", parsing: .remaining),
    ])

    #expect(throws: CommanderError.missingArgument("chord")) {
        _ = try CommandParser(signature: signature).parse(arguments: [])
    }
}

@Test
func `remaining positional argument must be final`() {
    let signature = CommandSignature(arguments: [
        .make(label: "inputs", parsing: .remaining),
        .make(label: "output"),
    ])

    #expect(throws: CommanderError.invalidArgumentOrder("inputs")) {
        _ = try CommandParser(signature: signature).parse(arguments: ["input.txt", "output.txt"])
    }
}

@Test
func `parser rejects optional positional arguments before required ones`() {
    let signature = CommandSignature(arguments: [
        .make(label: "input", isOptional: true),
        .make(label: "output"),
    ])

    #expect(throws: CommanderError.requiredArgumentAfterOptional(
        optionalLabel: "input",
        requiredLabel: "output"))
    {
        _ = try CommandParser(signature: signature).parse(arguments: ["result.txt"])
    }
}

@Test
func `errors when a required positional argument is missing`() {
    let signature = CommandSignature(arguments: [
        .make(label: "source"),
        .make(label: "destination", isOptional: true),
    ])

    #expect(throws: CommanderError.missingArgument("source")) {
        _ = try CommandParser(signature: signature).parse(arguments: [])
    }
}

@Test
func `errors when a required option is missing`() {
    let signature = CommandSignature(options: [
        .make(
            label: "output",
            names: [.aliasLong("legacy-output"), .long("output")],
            isOptional: false),
    ])

    #expect(throws: CommanderError.missingValue(option: "--output")) {
        _ = try CommandParser(signature: signature).parse(arguments: [])
    }
}

@Test
func `errors when a required multi-value option has no values`() {
    let cases: [(OptionParsingStrategy, [String])] = [
        (.upToNextOption, ["--input", "--verbose"]),
        (.remaining, ["--input"]),
    ]

    for (strategy, arguments) in cases {
        let signature = CommandSignature(
            options: [
                .make(
                    label: "input",
                    names: [.long("input")],
                    isOptional: false,
                    parsing: strategy),
            ],
            flags: [.make(label: "verbose", names: [.long("verbose")])])

        #expect(throws: CommanderError.missingValue(option: "--input")) {
            _ = try CommandParser(signature: signature).parse(arguments: arguments)
        }
    }
}

@Test
func `manual option definitions remain optional by default`() throws {
    let signature = CommandSignature(options: [
        .make(label: "output", names: [.long("output")]),
    ])

    let parsed = try CommandParser(signature: signature).parse(arguments: [])
    #expect(parsed.options.isEmpty)
}

@Test
func `accepts omitted optional positional arguments`() throws {
    let signature = CommandSignature(arguments: [
        .make(label: "source"),
        .make(label: "destination", isOptional: true),
    ])
    let parsed = try CommandParser(signature: signature).parse(arguments: ["input.txt"])

    #expect(parsed.positional == ["input.txt"])
}

@Test
func `parser consumes negative numeric option values`() throws {
    let signature = CommandSignature(options: [
        .make(label: "count", names: [.long("count")]),
    ])
    let parsed = try CommandParser(signature: signature).parse(arguments: ["--count", "-1"])

    #expect(parsed.options["count"] == ["-1"])
}

@Test
func `parser preserves declared numeric short options and flag packs`() throws {
    let signature = CommandSignature(
        options: [
            .make(label: "slot", names: [.short("1")]),
        ],
        flags: [
            .make(label: "second", names: [.short("2")]),
            .make(label: "third", names: [.short("3")]),
        ])
    let parsed = try CommandParser(signature: signature).parse(arguments: ["-1", "value", "-23"])

    #expect(parsed.options["slot"] == ["value"])
    #expect(parsed.flags == ["second", "third"])
}

@Test
func `parser accepts attached long option values`() throws {
    let signature = CommandSignature(options: [
        .make(label: "output", names: [.long("output")]),
    ])
    let parsed = try CommandParser(signature: signature).parse(arguments: ["--output=-dash"])

    #expect(parsed.options["output"] == ["-dash"])
}

@Test
func `parser honors opt-in joined short option values`() throws {
    let signature = CommandSignature(options: [
        .make(label: "define", names: [.short("D")], joinedShortNames: ["D"]),
    ])
    let parsed = try CommandParser(signature: signature).parse(arguments: ["-Ddebug"])

    #expect(parsed.options["define"] == ["debug"])
}

@Test
func `parser honors numeric joined short options without claiming negative positionals`() throws {
    let joinedSignature = CommandSignature(options: [
        .make(label: "slot", names: [.short("1")], joinedShortNames: ["1"]),
    ])
    let positionalSignature = CommandSignature(arguments: [
        .make(label: "number"),
    ], options: [
        .make(label: "slot", names: [.short("1")]),
    ])

    let joined = try CommandParser(signature: joinedSignature).parse(arguments: ["-12"])
    let positional = try CommandParser(signature: positionalSignature).parse(arguments: ["-12"])

    #expect(joined.options["slot"] == ["2"])
    #expect(positional.positional == ["-12"])
}

@Test
func `parser rejects joined values when the short option does not opt in`() {
    let signature = CommandSignature(options: [
        .make(label: "output", names: [.short("o")]),
    ])

    #expect(throws: CommanderError.unknownOption("-o")) {
        _ = try CommandParser(signature: signature).parse(arguments: ["-ovalue"])
    }
}

@Test
func `remaining option preserves raw option-looking arguments`() throws {
    let signature = CommandSignature(options: [
        .make(label: "rest", names: [.long("rest")], parsing: .remaining),
    ])
    let parsed = try CommandParser(signature: signature).parse(arguments: [
        "--rest",
        "one",
        "--literal=value",
        "-x",
        "--",
        "tail",
    ])

    #expect(parsed.options["rest"] == ["one", "--literal=value", "-x", "--", "tail"])
}

@Test
func `command parser is sendable`() {
    requireSendable(CommandParser(signature: CommandSignature()))
}

@Test
func `program resolves command`() throws {
    let descriptor = CommandDescriptor(name: "demo", abstract: "", discussion: nil, signature: signature)
    let program = Program(descriptors: [descriptor])
    let invocation = try program.resolve(commandLine: ["/tmp/mycli", "demo", "Workspace"])
    #expect(invocation.descriptor.name == "demo")
    #expect(invocation.parsedValues.positional == ["Workspace"])
    #expect(invocation.path == ["demo"])
}

@Test
func `program reports a missing required option as a parsing error`() {
    let descriptor = CommandDescriptor(
        name: "export",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(options: [
            .make(label: "output", names: [.long("output")], isOptional: false),
        ]))
    let program = Program(descriptors: [descriptor])

    #expect(throws: CommanderProgramError.parsingError(.missingValue(option: "--output"))) {
        _ = try program.resolve(arguments: ["export"])
    }
}

@Test
func `program resolves an explicit argument tail`() throws {
    let descriptor = CommandDescriptor(name: "demo", abstract: "", discussion: nil, signature: signature)
    let invocation = try Program(descriptors: [descriptor]).resolve(arguments: ["demo", "Workspace"])

    #expect(invocation.descriptor.name == "demo")
    #expect(invocation.parsedValues.positional == ["Workspace"])
}

@Test
func `program legacy argv entry point accepts generic executable names`() throws {
    let descriptor = CommandDescriptor(name: "demo", abstract: "", discussion: nil, signature: signature)
    let program = Program(descriptors: [descriptor])

    #expect(try program.resolve(argv: ["mycli", "demo", "Workspace"]).descriptor.name == "demo")
}

@Test
func `program legacy argv entry point preserves executable root collisions`() throws {
    let executable = CommandDescriptor(
        name: "mycli",
        abstract: "",
        discussion: nil,
        signature: CommandSignature())
    let demo = CommandDescriptor(name: "demo", abstract: "", discussion: nil, signature: signature)
    let invocation = try Program(descriptors: [executable, demo]).resolve(argv: ["mycli", "demo", "Workspace"])

    #expect(invocation.descriptor.name == "demo")
    #expect(invocation.parsedValues.positional == ["Workspace"])
}

@Test
func `program legacy argv entry point reports the unknown command rather than the executable`() {
    let program = Program(descriptors: [])

    #expect(throws: CommanderProgramError.unknownCommand("typo")) {
        _ = try program.resolve(argv: ["mycli", "typo"])
    }
}

@Test
func `program reports a missing command for an executable-only command line`() {
    let program = Program(descriptors: [])

    #expect(throws: CommanderProgramError.missingCommand) {
        _ = try program.resolve(commandLine: ["/tmp/mycli"])
    }
}

@Test
func `program detects unknown command`() {
    let program = Program(descriptors: [])
    #expect(throws: CommanderProgramError.unknownCommand("foo")) {
        _ = try program.resolve(arguments: ["foo"])
    }
}

@Test
func `program rejects duplicate root command names without trapping`() {
    let first = CommandDescriptor(name: "demo", abstract: "First", discussion: nil, signature: CommandSignature())
    let duplicate = CommandDescriptor(
        name: "demo",
        abstract: "Duplicate",
        discussion: nil,
        signature: CommandSignature())
    let program = Program(descriptors: [first, duplicate])

    #expect(throws: CommanderProgramError.duplicateCommand("demo")) {
        _ = try program.resolve(arguments: ["demo"])
    }
}

@Test
func `program rejects malformed root command names before unrelated resolution`() {
    let valid = CommandDescriptor(name: "version", abstract: "", discussion: nil, signature: CommandSignature())
    let cases = [
        (name: "", path: "<empty>"),
        (name: "-", path: "-"),
        (name: "--hidden", path: "--hidden"),
    ]

    for testCase in cases {
        let invalid = CommandDescriptor(
            name: testCase.name,
            abstract: "",
            discussion: nil,
            signature: CommandSignature())
        let program = Program(descriptors: [valid, invalid])

        #expect(throws: CommanderProgramError.invalidCommandName(path: testCase.path, name: testCase.name)) {
            _ = try program.resolve(arguments: ["version"])
        }
    }
}

@Test
func `program rejects duplicate nested subcommand names deterministically`() {
    let leaf = CommandDescriptor(name: "run", abstract: "First", discussion: nil, signature: CommandSignature())
    let duplicate = CommandDescriptor(
        name: "run",
        abstract: "Duplicate",
        discussion: nil,
        signature: CommandSignature())
    let nested = CommandDescriptor(
        name: "jobs",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [leaf, duplicate])
    let root = CommandDescriptor(
        name: "admin",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [nested])
    let program = Program(descriptors: [root])

    let expected = CommanderProgramError.duplicateSubcommand(command: "admin jobs", name: "run")
    #expect(throws: expected) {
        _ = try program.resolve(arguments: ["admin", "jobs", "run"])
    }
    #expect(expected.description == "Duplicate subcommand 'run' for command 'admin jobs'")
}

@Test
func `program rejects an invalid inactive command signature`() {
    let valid = CommandDescriptor(name: "version", abstract: "", discussion: nil, signature: CommandSignature())
    let invalid = CommandDescriptor(
        name: "run",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(flags: [
            .make(label: "verbose", names: [.short("v")]),
            .make(label: "trace", names: [.aliasShort("v")]),
        ]))
    let jobs = CommandDescriptor(
        name: "jobs",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [invalid])
    let program = Program(descriptors: [valid, jobs])
    let expected = CommanderProgramError.invalidCommandSignature(
        command: "jobs run",
        error: .duplicateFlagName(spelling: "-v", firstLabel: "verbose", duplicateLabel: "trace"))

    #expect(throws: expected) {
        _ = try program.resolve(arguments: ["version"])
    }
}

@Test
func `program rejects a malformed inactive nested command with its full path`() {
    let version = CommandDescriptor(name: "version", abstract: "", discussion: nil, signature: CommandSignature())
    let hidden = CommandDescriptor(
        name: "--hidden",
        abstract: "",
        discussion: nil,
        signature: CommandSignature())
    let jobs = CommandDescriptor(
        name: "jobs",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [hidden])
    let admin = CommandDescriptor(
        name: "admin",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [jobs])
    let program = Program(descriptors: [version, admin])
    let expected = CommanderProgramError.invalidCommandName(path: "admin jobs --hidden", name: "--hidden")

    #expect(throws: expected) {
        _ = try program.resolve(arguments: ["version"])
    }
    #expect(
        expected.description ==
            "Invalid command name '--hidden' at 'admin jobs --hidden'; names cannot be empty or begin with '-'")
}

@Test
func `program rejects a nameless flag in an inactive nested command`() {
    let version = CommandDescriptor(name: "version", abstract: "", discussion: nil, signature: CommandSignature())
    let run = CommandDescriptor(
        name: "run",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(flags: [
            .make(label: "hidden", names: []),
        ]))
    let admin = CommandDescriptor(
        name: "admin",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [run])
    let program = Program(descriptors: [version, admin])
    let expected = CommanderProgramError.invalidCommandSignature(
        command: "admin run",
        error: .flagHasNoNames("hidden"))

    #expect(throws: expected) {
        _ = try program.resolve(arguments: ["version"])
    }
}

@Test
func `program reports the full inactive command path for duplicate semantic labels`() {
    let version = CommandDescriptor(name: "version", abstract: "", discussion: nil, signature: CommandSignature())
    let run = CommandDescriptor(
        name: "run",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(options: [
            .make(label: "output", names: [.long("output")]),
            .make(label: "output", names: [.long("destination")]),
        ]))
    let jobs = CommandDescriptor(
        name: "jobs",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [run])
    let admin = CommandDescriptor(
        name: "admin",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [jobs])
    let program = Program(descriptors: [version, admin])
    let expected = CommanderProgramError.invalidCommandSignature(
        command: "admin jobs run",
        error: .duplicateOptionLabel("output"))

    #expect(throws: expected) {
        _ = try program.resolve(arguments: ["version"])
    }
    #expect(
        expected.description ==
            "Invalid signature for command 'admin jobs run': Duplicate option label 'output'")
}

@Test
func `program rejects an unregistered default subcommand`() {
    let apps = CommandDescriptor(name: "apps", abstract: "", discussion: nil, signature: CommandSignature())
    let list = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [apps],
        defaultSubcommandName: "windows")
    let program = Program(descriptors: [list])

    #expect(throws: CommanderProgramError.invalidDefaultSubcommand(command: "list", name: "windows")) {
        _ = try program.resolve(arguments: ["list"])
    }
}

@Test
func `program rejects a malformed default subcommand name before selection`() {
    let hidden = CommandDescriptor(
        name: "--hidden",
        abstract: "",
        discussion: nil,
        signature: CommandSignature())
    let root = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [hidden],
        defaultSubcommandName: "--hidden")
    let program = Program(descriptors: [root])
    let expected = CommanderProgramError.invalidCommandName(path: "list --hidden", name: "--hidden")

    #expect(throws: expected) {
        _ = try program.resolve(arguments: ["list"])
    }
    #expect(throws: expected) {
        _ = try program.resolve(arguments: ["list", "--hidden"])
    }
}

@Test
func `program resolves nested subcommand`() throws {
    let child = CommandDescriptor(name: "windows", abstract: "", discussion: nil, signature: signature)
    let parent = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [child])
    let program = Program(descriptors: [parent])
    let invocation = try program.resolve(argv: ["peekaboo", "list", "windows", "Workspace"])
    #expect(invocation.descriptor.name == "windows")
    #expect(invocation.parsedValues.positional == ["Workspace"])
    #expect(invocation.path == ["list", "windows"])
}

@Test
func `program uses default subcommand when missing`() throws {
    let runtimeSignature = CommandSignature().withStandardRuntimeFlags()
    let apps = CommandDescriptor(
        name: "apps",
        abstract: "",
        discussion: nil,
        signature: runtimeSignature)
    let parent = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [apps],
        defaultSubcommandName: "apps")
    let program = Program(descriptors: [parent])
    let invocation = try program.resolve(argv: ["peekaboo", "list", "--json-output"])
    #expect(invocation.descriptor.name == "apps")
    #expect(invocation.parsedValues.flags.contains("jsonOutput"))
    #expect(invocation.path == ["list", "apps"])
}

@Test
func `program preserves valid siblings explicit defaults and option parsing`() throws {
    let run = CommandDescriptor(
        name: "run",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(options: [
            .make(label: "output", names: [.long("output")]),
        ]))
    let version = CommandDescriptor(name: "version", abstract: "", discussion: nil, signature: CommandSignature())
    let root = CommandDescriptor(
        name: "tool",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [run, version],
        defaultSubcommandName: "run")
    let program = Program(descriptors: [root])

    let implicit = try program.resolve(arguments: ["tool", "--output", "implicit.txt"])
    let explicit = try program.resolve(arguments: ["tool", "run", "--output", "explicit.txt"])
    let sibling = try program.resolve(arguments: ["tool", "version"])

    #expect(implicit.path == ["tool", "run"])
    #expect(implicit.parsedValues.options["output"] == ["implicit.txt"])
    #expect(explicit.path == ["tool", "run"])
    #expect(explicit.parsedValues.options["output"] == ["explicit.txt"])
    #expect(sibling.path == ["tool", "version"])
}

@Test
func `program errors when subcommand missing`() {
    let child = CommandDescriptor(name: "apps", abstract: "", discussion: nil, signature: signature)
    let parent = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [child])
    let program = Program(descriptors: [parent])
    #expect(throws: CommanderProgramError.missingSubcommand(command: "list")) {
        _ = try program.resolve(argv: ["peekaboo", "list"])
    }
}

@Test
func `program errors on unknown subcommand`() {
    let child = CommandDescriptor(name: "windows", abstract: "", discussion: nil, signature: signature)
    let parent = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [child])
    let program = Program(descriptors: [parent])
    #expect(throws: CommanderProgramError.unknownSubcommand(command: "list", name: "apps")) {
        _ = try program.resolve(argv: ["peekaboo", "list", "apps"])
    }
}
