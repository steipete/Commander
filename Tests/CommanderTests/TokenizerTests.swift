import Testing
@testable import Commander

@Test
func tokenizerParsesSingleShortOption() {
    let tokens = CommandLineTokenizer.tokenize(["-e", "value"])
    #expect(tokens.count == 2)
    #expect(tokens[0] == .option(name: "e"))
}

@Test
func tokenizerParsesCombinedFlags() {
    let tokens = CommandLineTokenizer.tokenize(["-abc"])
    #expect(tokens == [.flag(name: "a"), .flag(name: "b"), .flag(name: "c")])
}

@Test
func tokenizerPreservesNegativeNumbersAsArguments() {
    let tokens = CommandLineTokenizer.tokenize(["--count", "-1", "--ratio", "-0.5"])

    #expect(tokens == [
        .option(name: "count"),
        .argument("-1"),
        .option(name: "ratio"),
        .argument("-0.5"),
    ])
}

@Test
func tokenizerHonorsTerminator() {
    let tokens = CommandLineTokenizer.tokenize(["--", "tail", "values"])
    #expect(tokens.first == .terminator)
    #expect(tokens[1] == .argument("tail"))
    #expect(tokens[2] == .argument("values"))
}
