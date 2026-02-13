import Foundation
@testable import PWAKitApp
import Testing

@Suite("UserAgentBuilder Tests")
struct UserAgentBuilderTests {
    // MARK: - User Agent Building

    @Test("Builds user agent with default parameters")
    func buildsUserAgentWithDefaultParameters() {
        let userAgent = UserAgentBuilder.buildUserAgent()

        #expect(userAgent.contains("Mozilla/5.0"))
        #expect(userAgent.contains("AppleWebKit"))
        #expect(userAgent.contains("PWAKit/"))
        #expect(userAgent.contains("Model/"))
    }

    @Test("Builds user agent with custom app version")
    func buildsUserAgentWithCustomAppVersion() {
        let userAgent = UserAgentBuilder.buildUserAgent(appVersion: "2.5.0")

        #expect(userAgent.contains("PWAKit/2.5.0"))
    }

    @Test("Builds user agent with additional components")
    func buildsUserAgentWithAdditionalComponents() {
        let userAgent = UserAgentBuilder.buildUserAgent(additionalComponents: ["CustomApp/1.0", "Feature/test"])

        #expect(userAgent.contains("CustomApp/1.0"))
        #expect(userAgent.contains("Feature/test"))
    }

    @Test("User agent contains OS version")
    func userAgentContainsOSVersion() {
        let userAgent = UserAgentBuilder.buildUserAgent()
        let osVersion = UserAgentBuilder.osVersion().replacingOccurrences(of: ".", with: "_")

        #expect(userAgent.contains(osVersion))
    }

    // MARK: - Base Safari User Agent

    @Test("Base Safari user agent has correct format")
    func baseSafariUserAgentHasCorrectFormat() {
        let base = UserAgentBuilder.baseSafariUserAgent()

        #expect(base.hasPrefix("Mozilla/5.0"))
        #expect(base.contains("AppleWebKit/605.1.15"))
        #expect(base.contains("(KHTML, like Gecko)"))
        #expect(base.contains("like Mac OS X"))
    }

    @Test("Base Safari user agent contains OS version")
    func baseSafariUserAgentContainsOSVersion() {
        let base = UserAgentBuilder.baseSafariUserAgent()
        let osVersion = UserAgentBuilder.osVersion().replacingOccurrences(of: ".", with: "_")

        #expect(base.contains(osVersion))
    }

    // MARK: - Device Model

    @Test("Device model is not empty")
    func deviceModelIsNotEmpty() {
        let model = UserAgentBuilder.deviceModel()

        #expect(!model.isEmpty)
    }

    @Test("Device model does not contain null characters")
    func deviceModelDoesNotContainNullCharacters() {
        let model = UserAgentBuilder.deviceModel()

        #expect(!model.contains("\0"))
    }

    // MARK: - OS Information

    @Test("OS version is not empty")
    func osVersionIsNotEmpty() {
        let version = UserAgentBuilder.osVersion()

        #expect(!version.isEmpty)
    }

    @Test("OS name is not empty")
    func osNameIsNotEmpty() {
        let name = UserAgentBuilder.osName()

        #expect(!name.isEmpty)
    }

    // MARK: - Bundle Version

    @Test("Bundle version returns non-empty string")
    func bundleVersionReturnsNonEmptyString() {
        let version = UserAgentBuilder.bundleVersion()

        #expect(!version.isEmpty)
    }

    @Test("Build number returns non-empty string")
    func buildNumberReturnsNonEmptyString() {
        let buildNumber = UserAgentBuilder.buildNumber()

        #expect(!buildNumber.isEmpty)
    }

    // MARK: - Shell Identifier

    @Test("Shell identifier is PWAKit")
    func shellIdentifierIsPWAKit() {
        #expect(UserAgentBuilder.shellIdentifier == "PWAKit")
    }

    // MARK: - User Agent Parsing

    @Test("Detects PWAKit in user agent")
    func detectsPWAKitInUserAgent() {
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) PWAKit/1.0.0 Model/iPhone15,2"

        #expect(UserAgentBuilder.isPWAKit(userAgent) == true)
    }

    @Test("Does not detect PWAKit in standard user agent")
    func doesNotDetectPWAKitInStandardUserAgent() {
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"

        #expect(UserAgentBuilder.isPWAKit(userAgent) == false)
    }

    @Test("Extracts shell version from user agent")
    func extractsShellVersionFromUserAgent() {
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) PWAKit/2.5.3 Model/iPhone15,2"

        let version = UserAgentBuilder.extractShellVersion(from: userAgent)

        #expect(version == "2.5.3")
    }

    @Test("Returns nil for missing shell version")
    func returnsNilForMissingShellVersion() {
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"

        let version = UserAgentBuilder.extractShellVersion(from: userAgent)

        #expect(version == nil)
    }

    @Test("Extracts device model from user agent")
    func extractsDeviceModelFromUserAgent() {
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) PWAKit/1.0.0 Model/iPhone15,2"

        let model = UserAgentBuilder.extractDeviceModel(from: userAgent)

        #expect(model == "iPhone15,2")
    }

    @Test("Returns nil for missing device model")
    func returnsNilForMissingDeviceModel() {
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) PWAKit/1.0.0"

        let model = UserAgentBuilder.extractDeviceModel(from: userAgent)

        #expect(model == nil)
    }

    // MARK: - User Agent Format Verification

    @Test("User agent matches expected format")
    func userAgentMatchesExpectedFormat() {
        let userAgent = UserAgentBuilder.buildUserAgent(appVersion: "1.0.0")

        // Verify the format:
        // Mozilla/5.0 (Device; CPU ... like Mac OS X) AppleWebKit/... (KHTML, like Gecko) PWAKit/version
        // Model/identifier

        // Check it starts with Mozilla
        #expect(userAgent.hasPrefix("Mozilla/5.0"))

        // Check PWAKit is present with version
        #expect(userAgent.contains("PWAKit/1.0.0"))

        // Check Model is present
        #expect(userAgent.contains("Model/"))

        // Check overall structure - PWAKit comes after the base Safari UA
        let baseEnd = userAgent.range(of: "(KHTML, like Gecko)")
        let shellStart = userAgent.range(of: "PWAKit/")

        #expect(baseEnd != nil)
        #expect(shellStart != nil)

        if let baseEnd, let shellStart {
            #expect(baseEnd.upperBound < shellStart.lowerBound)
        }
    }

    @Test("Built user agent can be parsed")
    func builtUserAgentCanBeParsed() {
        let userAgent = UserAgentBuilder.buildUserAgent(appVersion: "3.2.1")

        #expect(UserAgentBuilder.isPWAKit(userAgent) == true)
        #expect(UserAgentBuilder.extractShellVersion(from: userAgent) == "3.2.1")

        let model = UserAgentBuilder.extractDeviceModel(from: userAgent)
        #expect(model == UserAgentBuilder.deviceModel())
    }
}
