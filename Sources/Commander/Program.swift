import Foundation

/// Describes a `ParsableCommand` so the lightweight ``Program`` router can
/// resolve `argv` without instantiating the command immediately.
public struct CommandDescriptor: Sendable {
    /// The token users type to invoke the command (e.g. `agent`).
    public let name: String
    /// One-line summary suitable for `--help` output.
    public let abstract: String
    /// Optional longer discussion block rendered after the abstract.
    public let discussion: String?
    /// All arguments, flags, and options accepted by the command.
    public let signature: CommandSignature
    /// Child commands that may follow the current token.
    public let subcommands: [CommandDescriptor]
    /// Name of the default child that should be used when a subcommand is
    /// required but omitted.
    public let defaultSubcommandName: String?

    public init(
        name: String,
        abstract: String,
        discussion: String?,
        signature: CommandSignature,
        subcommands: [CommandDescriptor] = [],
        defaultSubcommandName: String? = nil)
    {
        self.name = name
        self.abstract = abstract
        self.discussion = discussion
        self.signature = signature
        self.subcommands = subcommands
        self.defaultSubcommandName = defaultSubcommandName
    }
}

/// The fully resolved command plus the parsed values for the original `argv`.
public struct CommandInvocation: Sendable {
    public let descriptor: CommandDescriptor
    public let parsedValues: ParsedValues
    public let path: [String]
}

/// Errors surfaced while resolving a command path prior to running user code.
public enum CommanderProgramError: Error, CustomStringConvertible, Sendable, Equatable {
    case missingCommand
    case unknownCommand(String)
    case duplicateCommand(String)
    case invalidCommandName(path: String, name: String)
    case duplicateSubcommand(command: String, name: String)
    case invalidDefaultSubcommand(command: String, name: String)
    case invalidCommandSignature(command: String, error: CommanderError)
    case missingSubcommand(command: String)
    case unknownSubcommand(command: String, name: String)
    case parsingError(CommanderError)

    public var description: String {
        switch self {
        case .missingCommand:
            "No command specified"
        case let .unknownCommand(name):
            "Unknown command '\(name)'"
        case let .duplicateCommand(name):
            "Duplicate root command '\(name)'"
        case let .invalidCommandName(path, name):
            "Invalid command name '\(name)' at '\(path)'; names cannot be empty or begin with '-'"
        case let .duplicateSubcommand(command, name):
            "Duplicate subcommand '\(name)' for command '\(command)'"
        case let .invalidDefaultSubcommand(command, name):
            "Default subcommand '\(name)' is not registered for command '\(command)'"
        case let .invalidCommandSignature(command, error):
            "Invalid signature for command '\(command)': \(error.description)"
        case let .missingSubcommand(command):
            "Command '\(command)' requires a subcommand"
        case let .unknownSubcommand(command, name):
            "Unknown subcommand '\(name)' for command '\(command)'"
        case let .parsingError(error):
            error.description
        }
    }
}

/// Resolves `CommandLine.arguments` into concrete commands using descriptors.
public struct Program: Sendable {
    private let descriptorLookup: [String: CommandDescriptor]
    private let configurationError: CommanderProgramError?

    /// Creates a router for the provided command descriptors.
    public init(descriptors: [CommandDescriptor]) {
        var lookup: [String: CommandDescriptor] = [:]
        var duplicateName: String?
        for descriptor in descriptors {
            if lookup[descriptor.name] != nil {
                duplicateName = duplicateName ?? descriptor.name
            } else {
                lookup[descriptor.name] = descriptor
            }
        }
        self.descriptorLookup = lookup
        self.configurationError = if let duplicateName {
            .duplicateCommand(duplicateName)
        } else {
            descriptors.lazy.compactMap { Self.configurationError(in: $0, path: [$0.name]) }.first
        }
    }

    /// Resolves a complete process command line, including its executable at
    /// index zero.
    ///
    /// - Parameter commandLine: The complete command line, typically
    ///   `CommandLine.arguments`.
    /// - Throws: ``CommanderProgramError`` when the path or arguments are
    ///   invalid.
    public func resolve(commandLine: [String]) throws -> CommandInvocation {
        try self.validateConfiguration()
        guard !commandLine.isEmpty else {
            throw CommanderProgramError.missingCommand
        }
        return try self.resolve(arguments: Array(commandLine.dropFirst()))
    }

    /// Walks the command tree from an argument tail whose first token is the
    /// root command.
    public func resolve(arguments: [String]) throws -> CommandInvocation {
        try self.validateConfiguration()
        var args = arguments
        guard let commandName = args.first else {
            throw CommanderProgramError.missingCommand
        }
        guard var descriptor = descriptorLookup[commandName] else {
            throw CommanderProgramError.unknownCommand(commandName)
        }
        args.removeFirst()
        var remainingArguments = args
        var commandPath = [commandName]
        descriptor = try self.resolveDescriptor(descriptor, arguments: &remainingArguments, path: &commandPath)
        let parser = CommandParser(signature: descriptor.signature)
        do {
            let parsed = try parser.parse(arguments: remainingArguments)
            return CommandInvocation(descriptor: descriptor, parsedValues: parsed, path: commandPath)
        } catch let error as CommanderError {
            throw CommanderProgramError.parsingError(error)
        }
    }

    /// Legacy spelling for ``resolve(commandLine:)``. This retains the original
    /// full-process-arguments contract without guessing whether an executable
    /// name that matches a root command should be removed.
    public func resolve(argv: [String]) throws -> CommandInvocation {
        try self.resolve(commandLine: argv)
    }

    private func validateConfiguration() throws {
        if let configurationError {
            throw configurationError
        }
    }

    private static func configurationError(
        in descriptor: CommandDescriptor,
        path: [String]) -> CommanderProgramError?
    {
        if let error = invalidCommandNameError(name: descriptor.name, path: path) {
            return error
        }

        var names: Set<String> = []
        for child in descriptor.subcommands {
            guard names.insert(child.name).inserted else {
                return .duplicateSubcommand(command: path.joined(separator: " "), name: child.name)
            }
        }

        do {
            try descriptor.signature.validate()
        } catch {
            return .invalidCommandSignature(command: path.joined(separator: " "), error: error)
        }

        if let defaultName = descriptor.defaultSubcommandName {
            if let error = Self.invalidCommandNameError(name: defaultName, path: path + [defaultName]) {
                return error
            }
            if !names.contains(defaultName) {
                return .invalidDefaultSubcommand(command: path.joined(separator: " "), name: defaultName)
            }
        }

        for child in descriptor.subcommands {
            if let error = Self.configurationError(in: child, path: path + [child.name]) {
                return error
            }
        }
        return nil
    }

    private static func invalidCommandNameError(
        name: String,
        path: [String]) -> CommanderProgramError?
    {
        guard name.isEmpty || name.hasPrefix("-") else { return nil }
        let displayPath = path.map { $0.isEmpty ? "<empty>" : $0 }.joined(separator: " ")
        return .invalidCommandName(path: displayPath, name: name)
    }

    private func resolveDescriptor(
        _ descriptor: CommandDescriptor,
        arguments: inout [String],
        path: inout [String]) throws -> CommandDescriptor
    {
        guard !descriptor.subcommands.isEmpty else {
            return descriptor
        }

        if arguments.isEmpty {
            if let defaultChild = lookupDefaultSubcommand(for: descriptor) {
                path.append(defaultChild.name)
                return try self.resolveDescriptor(defaultChild, arguments: &arguments, path: &path)
            }
            throw CommanderProgramError.missingSubcommand(command: descriptor.name)
        }

        let nextToken = arguments[0]
        if nextToken.isCommanderOptionToken {
            if let defaultChild = lookupDefaultSubcommand(for: descriptor) {
                path.append(defaultChild.name)
                return try self.resolveDescriptor(defaultChild, arguments: &arguments, path: &path)
            }
            throw CommanderProgramError.missingSubcommand(command: descriptor.name)
        }

        guard let match = descriptor.subcommands.first(where: { $0.name == nextToken }) else {
            throw CommanderProgramError.unknownSubcommand(command: descriptor.name, name: nextToken)
        }
        arguments.removeFirst()
        path.append(match.name)
        return try self.resolveDescriptor(match, arguments: &arguments, path: &path)
    }

    private func lookupDefaultSubcommand(for descriptor: CommandDescriptor) -> CommandDescriptor? {
        guard let name = descriptor.defaultSubcommandName else { return nil }
        return descriptor.subcommands.first(where: { $0.name == name })
    }
}

extension String {
    fileprivate var isCommanderOptionToken: Bool {
        guard let first = self.first else { return false }
        return first == "-"
    }
}
