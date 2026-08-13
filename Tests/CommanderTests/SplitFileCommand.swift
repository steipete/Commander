#if compiler(>=6.2)
final class SplitFileCommandState {
    var value = 0
}

struct SplitFileCommand {
    let state = SplitFileCommandState()

    init() {}
}
#endif
