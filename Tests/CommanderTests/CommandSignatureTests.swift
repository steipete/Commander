import Commander
import Testing

private struct OutputOptions: CommanderParsable, Sendable {
    @Option(help: "Output format") var format: String?
    init() {}
}

private struct RuntimeOptions: CommanderParsable, Sendable {
    @Flag(name: .shortAndLong, help: "Verbose logging") var verbose = false
    @Option(help: "JSON output path") var json: String?
    @OptionGroup var output: OutputOptions
    init() {}
}

private struct SampleCommand: CommanderParsable, Sendable {
    @Argument(help: "Working directory") var directory: String = "."
    @Option(name: .shortAndLong, help: "Target application") var app: String?
    @Flag(name: .long("dry-run")) var dryRun = false
    @OptionGroup var runtime: RuntimeOptions

    init() {}
}

private struct JoinedOptionCommand: CommanderParsable, Sendable {
    @Option(name: .customShort("D", allowingJoined: true)) var define: String?
    init() {}
}

private struct ArgumentRequirementCommand: CommanderParsable, Sendable {
    @Argument var required: String
    @Argument var defaulted = "."
    @Argument var optional: String?
    init() {}
}

private struct OptionRequirementCommand: CommanderParsable, Sendable {
    @Option var required: String
    @Option var defaulted = "stdout"
    @Option var optional: String?
    init() {}
}

private struct RemainingArgumentCommand: CommanderParsable, Sendable {
    @Argument(parsing: .remaining) var values: String
    init() {}
}

@Test
func `collects command signature`() throws {
    let signature = CommandSignature.describe(SampleCommand())
    #expect(signature.arguments.count == 1)
    #expect(signature.options.count == 1)
    #expect(signature.flags.count == 1)
    #expect(signature.optionGroups.count == 1)

    let option = try #require(signature.options.first)
    #expect(option.label == "app")
    #expect(option.names.contains(.long("app")))

    let flag = try #require(signature.flags.first)
    #expect(flag.names.contains(.long("dry-run")))
}

@Test
func `command parser recursively flattens nested option groups`() throws {
    let signature = CommandSignature.describe(SampleCommand())
    let runtimeSignature = try #require(signature.optionGroups.first)
    #expect(runtimeSignature.optionGroups.count == 1)

    let parsed = try CommandParser(signature: signature).parse(arguments: [
        "Workspace",
        "--app",
        "Safari",
        "--verbose",
        "--json",
        "result.json",
        "--format",
        "json",
    ])

    #expect(parsed.positional == ["Workspace"])
    #expect(parsed.options["app"] == ["Safari"])
    #expect(parsed.options["json"] == ["result.json"])
    #expect(parsed.options["format"] == ["json"])
    #expect(parsed.flags == ["verbose"])
}

@Test
func `collects joined short option metadata`() throws {
    let signature = CommandSignature.describe(JoinedOptionCommand())
    let option = try #require(signature.options.first)

    #expect(option.joinedShortNames == ["D"])
}

@Test
func `distinguishes required defaulted and optional arguments`() {
    let arguments = CommandSignature.describe(ArgumentRequirementCommand()).arguments

    #expect(arguments.map(\.label) == ["required", "defaulted", "optional"])
    #expect(arguments.map(\.isOptional) == [false, true, true])
}

@Test
func `distinguishes required defaulted and optional options`() {
    let options = CommandSignature.describe(OptionRequirementCommand()).options

    #expect(options.map(\.label) == ["required", "defaulted", "optional"])
    #expect(options.map(\.isOptional) == [false, true, true])
}

@Test
func `required option metadata drives parser validation`() throws {
    let signature = CommandSignature.describe(OptionRequirementCommand())
    let parser = CommandParser(signature: signature)

    #expect(throws: CommanderError.missingValue(option: "--required")) {
        _ = try parser.parse(arguments: [])
    }

    let parsed = try parser.parse(arguments: ["--required", "value"])
    #expect(parsed.options["required"] == ["value"])
}

@Test
func `collects remaining argument metadata`() throws {
    let argument = try #require(CommandSignature.describe(RemainingArgumentCommand()).arguments.first)

    #expect(argument.parsing == .remaining)
}

@Test
func `signature validation does not require invocation arguments`() {
    let signature = CommandSignature(options: [
        .make(label: "output", names: [.long("output")]),
        .make(label: "legacyOutput", names: [.aliasLong("output")]),
    ])

    #expect(throws: CommanderError.duplicateOptionName(
        spelling: "--output",
        firstLabel: "output",
        duplicateLabel: "legacyOutput"))
    {
        try signature.validate()
    }
}
