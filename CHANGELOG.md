# Changelog

All notable changes to Commander will be documented in this file.

## Unreleased

### Highlights
- Command routing and argument parsing now fail closed on ambiguous spellings, duplicate semantic labels, invalid positional ordering, and malformed invocations instead of silently choosing or ignoring input.

### Breaking
- `CommanderError` and `CommanderProgramError` gained validation cases; downstream exhaustive switches must handle the new failures.
- `CommanderProgramError` now rejects empty and option-shaped command names with `invalidCommandName`; exhaustive switches must handle the new case.
- `CommanderError` now distinguishes duplicate argument, option, and flag labels plus required-after-optional positional definitions; exhaustive switches must add the four new cases.
- `CommanderError` now rejects nameless options, empty or unreachable option spellings, and undeclared joined-short names with dedicated cases; exhaustive switches must add the four new cases.
- `CommanderError` now rejects nameless flags and empty or unreachable flag spellings with dedicated cases; exhaustive switches must add the three new cases.

### Added
- Accept attached long-option values such as `--output=-dash` and opt-in joined short values such as `-Ddebug`.
- Add explicit `Program.resolve(commandLine:)` and `resolve(arguments:)` entry points for generic executables and pre-trimmed argument tails.

### Fixed
- Reject empty and option-shaped root, nested, and default command names during registration, including malformed inactive branches.
- Reject option definitions whose names are empty, reserved by tokenization, or inconsistent with their joined-short metadata.
- Record option requiredness in command signatures and reject omitted or valueless non-optional, non-defaulted options before command code can access an unbound wrapper.
- Reject flag definitions whose names are empty or reserved by tokenization.
- Keep tokens after a bare `--` positional instead of routing them into an unselected `remaining` option.
- Require sendable command metatypes instead of sendable command instances on Swift 6.2+, avoiding retroactive `Sendable` diagnostics when a command adopts `ParsableCommand` in another source file.
- Validate every registered command signature and default-subcommand target before resolving any path so malformed inactive commands fail closed.
- Reject duplicate semantic labels within each argument, option, or flag category while preserving multiple aliases declared on one definition.
- Reject required positional arguments declared after optional ones, which cannot be bound unambiguously by position.
- Reject duplicate option, flag, root-command, and nested subcommand names with typed errors instead of silently overwriting definitions, choosing the first match, or trapping.
- Flatten nested option groups inside `CommandParser` so direct parsing honors grouped options and flags.
- Reject excess positional arguments unless the final argument explicitly uses the `remaining` parsing strategy.
- Treat negative numeric tokens as option values instead of misclassifying them as short flags.
- Preserve explicitly declared numeric short options and flag packs when classifying negative numeric tokens.
- Recognize numeric-looking joined short options such as `-12` when `-1` owns an attached value.
- Preserve option-looking arguments byte-for-byte when an option uses the `remaining` parsing strategy.
- Remove the Peekaboo-specific executable-name heuristic from `Program` routing.
- Reject missing required positional arguments while treating defaulted argument wrappers as optional input.

## [0.2.4] - 2026-07-15

### Platform/CI
- Update macOS CI and Apple simulator builds to macOS 26 and Xcode 26.6.

## [0.2.3] - 2026-07-02

### Highlights
- Commands that declare no positional inputs now reject stray arguments instead of accepting malformed invocations.
- CI once again verifies builds across all advertised Apple simulator platforms.

### Fixed
- Reject unexpected positional arguments when a command declares no positional inputs.
- Restore CI build coverage for the advertised iOS, tvOS, watchOS, and visionOS simulator targets.

## [0.2.2] - 2026-04-28

### Changed
- Refresh DocC build plugin dependency pins.

### Fixed
- Normalize the package copyright header.

## [0.2.1] - 2026-01-18

### Changed
- Update copyrights for 2026.
- Drop legacy agent-scripts pointer.

## [0.2.0] - 2025-12-05

### Breaking
- Commands now declare metadata via `commandDescription` (using `CommandDescription` / `MainActorCommandDescription.describe`) instead of the old ArgumentParser-style `configuration`. Update command types and any helpers that read command metadata.

### Added
- Commander-native `CommandDescription` model with support for abstracts, discussions, versions, usage examples, default subcommands, and “show help on empty invocation” behavior.
- Alias support for flag/option names (`CommanderName.aliasLong` / `aliasShort`) so you can keep compatibility spellings (e.g., `--json-output`, `--jsonOutput`) while presenting clean primary names such as `--json` / `-j`.
- Standard runtime flags now include `--log-level <trace|verbose|debug|info|warning|error|critical>` alongside `-v/--verbose` and the new JSON aliases.
- Added a DocC catalog plus multiplatform guide; README refreshed with the current platform story.

### Fixed
- Optional positional arguments no longer trap when accessed before binding; they now surface `nil` as expected for optional types.

### Platform/CI
- CI matrix trimmed to the platforms we actually exercise (macOS, Linux, Apple simulators); Windows/Android legs were removed and badges now match the supported set.

## [0.1.0] - 2025-11-11

### Highlights
- Declarative property-wrapper API (`@Option`, `@Argument`, `@Flag`, `@OptionGroup`) that builds `CommandSignature` metadata for parsing, help, and agent tooling.
- Program router (`Program.resolve`) that walks root/subcommand/default-subcommand hierarchies and returns parsed `CommandInvocation` values.
- Standard runtime flags out of the box (`-v/--verbose`, `--json-output`) with centralized parsing/validation.
- Binder APIs (`CommanderBindableCommand`, `CommanderBindableValues`) so existing command structs can hydrate from parsed values without rewriting runtime logic.
- Concurrency-safe by default with strict concurrency settings enabled across the package.
