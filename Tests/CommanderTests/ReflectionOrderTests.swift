import Commander
import Testing

private class BaseFields {
    @Option var required: String
    @Argument var first: String
    @Flag var verbose = false
}

private final class DerivedFields: BaseFields {
    @Argument var second: String
}

private struct FirstGroup: CommanderParsable {
    @Argument var first: String
    init() {}
}

private struct GroupedFields {
    @OptionGroup var group: FirstGroup
    @Argument var second: String
}

private struct GroupedRemainingFields {
    @OptionGroup var group: FirstGroup
    @Argument(parsing: .remaining) var rest: String
}

@Test
func `inherited fields are accepted and required`() throws {
    let signature = CommandSignature.describe(DerivedFields())
    #expect(signature.flattened().arguments.map(\.label) == ["first", "second"])
    let parser = CommandParser(signature: signature)
    let result = try parser.parse(arguments: ["aaa", "bbb", "--required", "value", "--verbose"])
    #expect(result.options["required"] == ["value"])
    #expect(result.flags.contains("verbose"))
    #expect(result.positional == ["aaa", "bbb"])
    #expect(throws: CommanderError.missingValue(option: "--required")) {
        try parser.parse(arguments: ["aaa", "bbb"])
    }
}

@Test
func `grouped positionals keep declaration order`() throws {
    let signature = CommandSignature.describe(GroupedFields()).flattened()
    #expect(signature.arguments.map(\.label) == ["first", "second"])
    #expect(try CommandParser(signature: signature).parse(arguments: ["aaa", "bbb"]).positional == ["aaa", "bbb"])
}

@Test
func `group before final remaining accepts tail`() throws {
    let signature = CommandSignature.describe(GroupedRemainingFields())
    #expect(signature.flattened().arguments.map(\.label) == ["first", "rest"])
    let result = try CommandParser(signature: signature).parse(arguments: ["aaa", "bbb", "ccc"])
    #expect(result.positional == ["aaa", "bbb", "ccc"])
}

@Test
func `manually built signature keeps direct arguments before groups`() {
    let signature = CommandSignature(
        arguments: [.make(label: "direct")],
        optionGroups: [CommandSignature(arguments: [.make(label: "grouped")])])
    #expect(signature.flattened().arguments.map(\.label) == ["direct", "grouped"])
}
