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
        "--",
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
func `errors on unknown option`() {
    let parser = CommandParser(signature: signature)
    #expect(throws: CommanderError.unknownOption("--foo")) {
        _ = try parser.parse(arguments: ["--foo"])
    }
}

@Test
func `errors on unexpected argument when command has no positional arguments`() {
    let parser = CommandParser(signature: CommandSignature())
    #expect(throws: CommanderError.unexpectedArgument("extra")) {
        _ = try parser.parse(arguments: ["extra"])
    }
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
    let invocation = try program.resolve(argv: ["peekaboo", "demo", "Workspace"])
    #expect(invocation.descriptor.name == "demo")
    #expect(invocation.parsedValues.positional == ["Workspace"])
    #expect(invocation.path == ["demo"])
}

@Test
func `program detects unknown command`() {
    let program = Program(descriptors: [])
    #expect(throws: CommanderProgramError.unknownCommand("foo")) {
        _ = try program.resolve(argv: ["foo"])
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
