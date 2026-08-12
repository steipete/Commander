import Commander
import Testing

private struct RuntimeOptions: CommanderParsable, Sendable {
    @Flag(name: .shortAndLong, help: "Verbose logging") var verbose = false
    @Option(help: "JSON output path") var json: String?
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
