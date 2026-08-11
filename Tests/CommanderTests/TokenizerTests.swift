import Testing
@testable import Commander

@Test
func `tokenizer parses single short option`() {
    let tokens = CommandLineTokenizer.tokenize(["-e", "value"])
    #expect(tokens.count == 2)
    #expect(tokens[0] == .option(name: "e"))
}

@Test
func `tokenizer parses combined flags`() {
    let tokens = CommandLineTokenizer.tokenize(["-abc"])
    #expect(tokens == [.flag(name: "a"), .flag(name: "b"), .flag(name: "c")])
}

@Test
func `tokenizer preserves negative numbers as arguments`() {
    let tokens = CommandLineTokenizer.tokenize(["--count", "-1", "--ratio", "-0.5"])

    #expect(tokens == [
        .option(name: "count"),
        .argument("-1"),
        .option(name: "ratio"),
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
        .option(name: "1"),
        .flag(name: "2"),
        .flag(name: "3"),
    ])
}

@Test
func `tokenizer honors terminator`() {
    let tokens = CommandLineTokenizer.tokenize(["--", "tail", "values"])
    #expect(tokens.first == .terminator)
    #expect(tokens[1] == .argument("tail"))
    #expect(tokens[2] == .argument("values"))
}
