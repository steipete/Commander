#if compiler(>=6.2)
import Commander
import Testing

@MainActor
extension SplitFileCommand: ParsableCommand {}

private func requireSendable(_ value: some Sendable) {}

private func requireCommandMetatypeSendable(_ type: (some ParsableCommand).Type) {
    requireSendable(type)
}

@MainActor
@Test
func `split-file command conformance requires only a sendable metatype`() {
    let command = SplitFileCommand()
    command.state.value = 42

    #expect(command.state.value == 42)
    requireCommandMetatypeSendable(SplitFileCommand.self)
}
#endif
