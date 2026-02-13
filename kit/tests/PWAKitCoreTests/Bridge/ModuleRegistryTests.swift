import Foundation
@testable import PWAKitApp
import Testing

// MARK: - MockModule

/// A simple mock module for testing registration.
struct MockModule: PWAModule {
    static let moduleName = "mock"
    static let supportedActions = ["test"]

    func handle(
        action _: String,
        payload _: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        nil
    }
}

// MARK: - AnotherMockModule

/// A second mock module with a different name.
struct AnotherMockModule: PWAModule {
    static let moduleName = "another"
    static let supportedActions = ["action1", "action2"]

    func handle(
        action _: String,
        payload _: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        nil
    }
}

// MARK: - NamedMockModule

/// A mock module with a configurable name for testing duplicates.
struct NamedMockModule: PWAModule {
    static var moduleName: String {
        "configurable"
    }

    static let supportedActions = ["do"]

    let identifier: String

    init(identifier: String = "default") {
        self.identifier = identifier
    }

    func handle(
        action _: String,
        payload _: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        AnyCodable(["id": AnyCodable(identifier)])
    }
}

// MARK: - ModuleRegistryTests

@Suite("ModuleRegistry Tests")
struct ModuleRegistryTests {
    // MARK: - Registration Tests

    @Test("Registers a module successfully")
    func registersModule() async {
        let registry = ModuleRegistry()

        let result = await registry.register(MockModule())

        #expect(result == true)
        #expect(await registry.moduleCount == 1)
    }

    @Test("Registers multiple modules")
    func registersMultipleModules() async {
        let registry = ModuleRegistry()

        await registry.register(MockModule())
        await registry.register(AnotherMockModule())

        #expect(await registry.moduleCount == 2)
    }

    @Test("Returns module names sorted alphabetically")
    func returnsModuleNamesSorted() async {
        let registry = ModuleRegistry()

        await registry.register(MockModule()) // "mock"
        await registry.register(AnotherMockModule()) // "another"

        let names = await registry.registeredModuleNames

        #expect(names == ["another", "mock"])
    }

    // MARK: - Retrieval Tests

    @Test("Retrieves registered module by name")
    func retrievesModule() async throws {
        let registry = ModuleRegistry()
        await registry.register(MockModule())

        let module = await registry.module(named: "mock")

        #expect(module != nil)
        #expect(try type(of: #require(module)).moduleName == "mock")
    }

    @Test("Returns nil for unregistered module")
    func returnsNilForUnregistered() async {
        let registry = ModuleRegistry()

        let module = await registry.module(named: "nonexistent")

        #expect(module == nil)
    }

    @Test("Checks if module exists")
    func checksModuleExists() async {
        let registry = ModuleRegistry()
        await registry.register(MockModule())

        #expect(await registry.hasModule(named: "mock") == true)
        #expect(await registry.hasModule(named: "nonexistent") == false)
    }

    @Test("Returns all modules")
    func returnsAllModules() async {
        let registry = ModuleRegistry()
        await registry.register(MockModule())
        await registry.register(AnotherMockModule())

        let modules = await registry.allModules

        #expect(modules.count == 2)
    }

    // MARK: - Duplicate Handling Tests

    @Test("Overwrites duplicate module by default")
    func overwritesDuplicateByDefault() async {
        let registry = ModuleRegistry()

        await registry.register(NamedMockModule(identifier: "first"))
        await registry.register(NamedMockModule(identifier: "second"))

        #expect(await registry.moduleCount == 1)

        // Verify the second one is registered
        if let module = await registry.module(named: "configurable") as? NamedMockModule {
            #expect(module.identifier == "second")
        } else {
            Issue.record("Module was not the expected type")
        }
    }

    @Test("Skips duplicate when allowOverwrite is false")
    func skipsDuplicateWhenNotAllowed() async {
        let registry = ModuleRegistry()

        let first = await registry.register(NamedMockModule(identifier: "first"), allowOverwrite: false)
        let second = await registry.register(NamedMockModule(identifier: "second"), allowOverwrite: false)

        #expect(first == true)
        #expect(second == false)
        #expect(await registry.moduleCount == 1)

        // Verify the first one is still registered
        if let module = await registry.module(named: "configurable") as? NamedMockModule {
            #expect(module.identifier == "first")
        } else {
            Issue.record("Module was not the expected type")
        }
    }

    // MARK: - Conditional Registration Tests

    @Test("Registers module when condition is true")
    func registersWhenConditionTrue() async {
        let registry = ModuleRegistry()

        let result = await registry.register(MockModule(), if: true)

        #expect(result == true)
        #expect(await registry.moduleCount == 1)
    }

    @Test("Skips registration when condition is false")
    func skipsWhenConditionFalse() async {
        let registry = ModuleRegistry()

        let result = await registry.register(MockModule(), if: false)

        #expect(result == false)
        #expect(await registry.moduleCount == 0)
    }

    @Test("Registers with feature flag checker")
    func registersWithFeatureFlagChecker() async {
        let registry = ModuleRegistry()
        let checker = FeatureFlagChecker(features: FeaturesConfiguration(haptics: true))

        let result = await registry.register(
            MockModule(),
            using: checker,
            flag: { $0.haptics }
        )

        #expect(result == true)
        #expect(await registry.moduleCount == 1)
    }

    @Test("Skips registration with disabled feature flag")
    func skipsWithDisabledFeatureFlag() async {
        let registry = ModuleRegistry()
        let checker = FeatureFlagChecker(features: FeaturesConfiguration(healthkit: false))

        let result = await registry.register(
            MockModule(),
            using: checker,
            flag: { $0.healthkit }
        )

        #expect(result == false)
        #expect(await registry.moduleCount == 0)
    }

    // MARK: - Removal Tests

    @Test("Unregisters module by name")
    func unregistersModule() async {
        let registry = ModuleRegistry()
        await registry.register(MockModule())

        let removed = await registry.unregister(named: "mock")

        #expect(removed != nil)
        #expect(await registry.moduleCount == 0)
    }

    @Test("Returns nil when unregistering nonexistent module")
    func unregisterNonexistentReturnsNil() async {
        let registry = ModuleRegistry()

        let removed = await registry.unregister(named: "nonexistent")

        #expect(removed == nil)
    }

    @Test("Removes all modules")
    func removesAllModules() async {
        let registry = ModuleRegistry()
        await registry.register(MockModule())
        await registry.register(AnotherMockModule())

        await registry.removeAll()

        #expect(await registry.moduleCount == 0)
        #expect(await registry.registeredModuleNames.isEmpty)
    }

    // MARK: - Bulk Registration Tests

    @Test("Registers all modules in array")
    func registersAllModulesInArray() async {
        let registry = ModuleRegistry()
        let modules: [any PWAModule] = [MockModule(), AnotherMockModule()]

        let count = await registry.registerAll(modules)

        #expect(count == 2)
        #expect(await registry.moduleCount == 2)
    }

    @Test("Bulk registration respects allowOverwrite")
    func bulkRegistrationRespectsOverwrite() async {
        let registry = ModuleRegistry()
        await registry.register(MockModule())

        // Try to re-register MockModule - should be skipped
        let modules: [any PWAModule] = [MockModule(), AnotherMockModule()]
        let count = await registry.registerAll(modules, allowOverwrite: false)

        #expect(count == 1) // Only AnotherMockModule registered
        #expect(await registry.moduleCount == 2)
    }

    @Test("Registers modules with conditions")
    func registersModulesWithConditions() async {
        let registry = ModuleRegistry()
        let modulesWithConditions: [(module: any PWAModule, enabled: Bool)] = [
            (MockModule(), true),
            (AnotherMockModule(), false),
        ]

        let count = await registry.registerAll(modulesWithConditions)

        #expect(count == 1) // Only MockModule registered
        #expect(await registry.hasModule(named: "mock") == true)
        #expect(await registry.hasModule(named: "another") == false)
    }

    @Test("Conditional bulk registration uses feature configuration")
    func conditionalBulkRegistrationWithFeatures() async {
        let registry = ModuleRegistry()
        let features = FeaturesConfiguration(haptics: true, healthkit: false)

        let modulesWithConditions: [(module: any PWAModule, enabled: Bool)] = [
            (MockModule(), features.haptics),
            (AnotherMockModule(), features.healthkit),
        ]

        let count = await registry.registerAll(modulesWithConditions)

        #expect(count == 1)
        #expect(await registry.hasModule(named: "mock") == true)
        #expect(await registry.hasModule(named: "another") == false)
    }

    // MARK: - Thread Safety Tests

    @Test("Handles concurrent registration safely")
    func handlesConcurrentRegistration() async {
        let registry = ModuleRegistry()

        // Perform multiple registrations concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 100 {
                group.addTask {
                    if i % 2 == 0 {
                        await registry.register(MockModule())
                    } else {
                        await registry.register(AnotherMockModule())
                    }
                }
            }
        }

        // Should have exactly 2 modules (last registration for each wins)
        #expect(await registry.moduleCount == 2)
    }

    @Test("Handles concurrent access safely")
    func handlesConcurrentAccess() async {
        let registry = ModuleRegistry()
        await registry.register(MockModule())
        await registry.register(AnotherMockModule())

        // Perform multiple reads and writes concurrently
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    await registry.hasModule(named: "mock")
                }
                group.addTask {
                    _ = await registry.module(named: "another")
                    return true
                }
                group.addTask {
                    _ = await registry.registeredModuleNames
                    return true
                }
            }
        }

        // Registry should still be consistent
        #expect(await registry.moduleCount == 2)
    }

    // MARK: - Empty Registry Tests

    @Test("New registry is empty")
    func newRegistryIsEmpty() async {
        let registry = ModuleRegistry()

        #expect(await registry.moduleCount == 0)
        #expect(await registry.registeredModuleNames.isEmpty)
        #expect(await registry.allModules.isEmpty)
    }
}
