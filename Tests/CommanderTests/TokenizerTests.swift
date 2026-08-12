import Testing
@testable import Commander

@Test
func `tokenizer parses single short option`() {
    let tokens = CommandLineTokenizer.tokenize(["-e", "value"])
    #expect(tokens.count == 2)
    #expect(tokens[0] == .short("e"))
}

@Test
func `tokenizer parses combined flags`() {
    let tokens = CommandLineTokenizer.tokenize(["-abc"])
    #expect(tokens == [.short("abc")])
}

@Test
func `tokenizer preserves negative numbers as arguments`() {
    let tokens = CommandLineTokenizer.tokenize(["--count", "-1", "--ratio", "-0.5"])

    #expect(tokens == [
        .option(name: "count", attachedValue: nil),
        .argument("-1"),
        .option(name: "ratio", attachedValue: nil),
        .argument("-0.5"),
    ])
}

@Test
func `tokenizer preserves declared numeric short names`() {
    let tokens = CommandLineTokenizer.tokenize(
        ["-1", "-23"],
        optionShortNames: ["1"],
        flagShortNames: ["2", "3"])

    #expect(tokens == [
        .short("1"),
        .short("23"),
    ])
}

@Test
func `tokenizer recognizes numeric joined short options without claiming negative positionals`() {
    let joined = CommandLineTokenizer.tokenize(
        ["-12"],
        optionShortNames: ["1"],
        joinedOptionShortNames: ["1"])
    let positional = CommandLineTokenizer.tokenize(
        ["-12"],
        optionShortNames: ["1"])

    #expect(joined == [.short("12")])
    #expect(positional == [.argument("-12")])
}

@Test
func `tokenizer preserves attached long option values`() {
    let tokens = CommandLineTokenizer.tokenize(["--output=-dash", "--empty="])

    #expect(tokens == [
        .option(name: "output", attachedValue: "-dash"),
        .option(name: "empty", attachedValue: ""),
    ])
    #expect(tokens.map(\.rawValue) == ["--output=-dash", "--empty="])
}

@Test
func `tokenizer honors terminator`() {
    let tokens = CommandLineTokenizer.tokenize(["--", "tail", "values"])
    #expect(tokens.first == .terminator)
    #expect(tokens[1] == .argument("tail"))
    #expect(tokens[2] == .argument("values"))
}
