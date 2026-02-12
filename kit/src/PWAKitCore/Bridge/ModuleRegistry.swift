import Foundation

// MARK: - ModuleRegistry

/// Thread-safe registry for bridge modules.
///
/// `ModuleRegistry` provides a centralized storage mechanism for `PWAModule`
/// implementations. It uses an actor to ensure thread-safe access to the
/// module storage, making it safe to use from any concurrency context.
///
/// ## Usage
///
/// ```swift
/// let registry = ModuleRegistry()
///
/// // Register a module
/// await registry.register(PlatformModule())
///
/// // Retrieve a module
/// if let module = await registry.module(named: "platform") {
///     // Use module
/// }
///
/// // List all modules
/// let names = await registry.registeredModuleNames
/// ```
///
/// ## Conditional Registration
///
/// The registry supports conditional registration based on feature flags:
///
/// ```swift
/// // Only register if feature is enabled
/// await registry.register(
///     HapticsModule(),
///     if: configuration.features.haptics
/// )
///
/// // Use a feature flag checker
/// let checker = FeatureFlagChecker(features: configuration.features)
/// await registry.register(
///     NotificationsModule(),
///     if: checker.notifications
/// )
/// ```
///
/// ## Duplicate Handling
///
/// By default, registering a module with the same name as an existing module
/// will replace the existing registration. Use the `allowOverwrite` parameter
/// to control this behavior.
public actor ModuleRegistry {
    /// Storage for registered modules, keyed by module name.
    private var modules: [String: any PWAModule] = [:]

    /// Creates a new empty module registry.
    public init() {}

    // MARK: - Registration

    /// Registers a module in the registry.
    ///
    /// If a module with the same name is already registered, this method will
    /// replace it if `allowOverwrite` is `true`, or log a warning and skip
    /// registration if `allowOverwrite` is `false`.
    ///
    /// - Parameters:
    ///   - module: The module to register.
    ///   - allowOverwrite: Whether to allow overwriting an existing registration.
    ///                     Defaults to `true`.
    /// - Returns: `true` if the module was registered, `false` if registration
    ///            was skipped due to duplicate name with `allowOverwrite` set to `false`.
    @discardableResult
    public func register(_ module: some PWAModule, allowOverwrite: Bool = true) -> Bool {
        let name = type(of: module).moduleName

        if modules[name] != nil, !allowOverwrite {
            return false
        }

        modules[name] = module
        return true
    }

    /// Registers a module conditionally based on a feature flag.
    ///
    /// The module will only be registered if `condition` is `true`.
    ///
    /// - Parameters:
    ///   - module: The module to register.
    ///   - condition: The condition that must be true for registration.
    ///   - allowOverwrite: Whether to allow overwriting an existing registration.
    ///                     Defaults to `true`.
    /// - Returns: `true` if the module was registered, `false` if the condition
    ///            was `false` or registration was skipped due to duplicate name.
    @discardableResult
    public func register(
        _ module: some PWAModule,
        if condition: Bool,
        allowOverwrite: Bool = true
    ) -> Bool {
        guard condition else { return false }
        return register(module, allowOverwrite: allowOverwrite)
    }

    /// Registers a module conditionally using a feature flag checker.
    ///
    /// This overload provides a convenient way to use `FeatureFlagChecker`
    /// for conditional registration.
    ///
    /// - Parameters:
    ///   - module: The module to register.
    ///   - checker: The feature flag checker to evaluate.
    ///   - flag: A closure that extracts the relevant flag from the checker.
    ///   - allowOverwrite: Whether to allow overwriting an existing registration.
    ///                     Defaults to `true`.
    /// - Returns: `true` if the module was registered, `false` otherwise.
    @discardableResult
    public func register(
        _ module: some PWAModule,
        using checker: FeatureFlagChecker,
        flag: (FeatureFlagChecker) -> Bool,
        allowOverwrite: Bool = true
    ) -> Bool {
        register(module, if: flag(checker), allowOverwrite: allowOverwrite)
    }

    // MARK: - Retrieval

    /// Retrieves a module by name.
    ///
    /// - Parameter name: The name of the module to retrieve.
    /// - Returns: The registered module, or `nil` if no module is registered
    ///            with the given name.
    public func module(named name: String) -> (any PWAModule)? {
        modules[name]
    }

    /// Checks if a module is registered with the given name.
    ///
    /// - Parameter name: The name to check.
    /// - Returns: `true` if a module is registered with the given name.
    public func hasModule(named name: String) -> Bool {
        modules[name] != nil
    }

    // MARK: - Listing

    /// The names of all registered modules.
    public var registeredModuleNames: [String] {
        Array(modules.keys).sorted()
    }

    /// The count of registered modules.
    public var moduleCount: Int {
        modules.count
    }

    /// All registered modules.
    ///
    /// The modules are returned in no particular order.
    public var allModules: [any PWAModule] {
        Array(modules.values)
    }

    // MARK: - Removal

    /// Removes a module from the registry.
    ///
    /// - Parameter name: The name of the module to remove.
    /// - Returns: The removed module, or `nil` if no module was registered
    ///            with the given name.
    @discardableResult
    public func unregister(named name: String) -> (any PWAModule)? {
        modules.removeValue(forKey: name)
    }

    /// Removes all modules from the registry.
    public func removeAll() {
        modules.removeAll()
    }
}

// MARK: - Bulk Registration

extension ModuleRegistry {
    /// Registers multiple modules at once.
    ///
    /// - Parameters:
    ///   - modulesToRegister: The modules to register.
    ///   - allowOverwrite: Whether to allow overwriting existing registrations.
    ///                     Defaults to `true`.
    /// - Returns: The count of successfully registered modules.
    @discardableResult
    public func registerAll(
        _ modulesToRegister: [any PWAModule],
        allowOverwrite: Bool = true
    ) -> Int {
        modulesToRegister.count(where: { register($0, allowOverwrite: allowOverwrite) })
    }

    /// Registers multiple modules conditionally based on feature flags.
    ///
    /// Each tuple in the array pairs a module with its enabled condition.
    /// Only modules whose condition is `true` will be registered.
    ///
    /// - Parameters:
    ///   - modulesWithConditions: Array of tuples containing modules and their
    ///                            enabled conditions.
    ///   - allowOverwrite: Whether to allow overwriting existing registrations.
    ///                     Defaults to `true`.
    /// - Returns: The count of successfully registered modules.
    @discardableResult
    public func registerAll(
        _ modulesWithConditions: [(module: any PWAModule, enabled: Bool)],
        allowOverwrite: Bool = true
    ) -> Int {
        modulesWithConditions.reduce(0) { count, entry in
            count + (register(entry.module, if: entry.enabled, allowOverwrite: allowOverwrite) ? 1 : 0)
        }
    }
}
