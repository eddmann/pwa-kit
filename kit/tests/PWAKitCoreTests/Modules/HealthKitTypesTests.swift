import Foundation
import Testing

@testable import PWAKitApp

@Suite("HealthKitTypes Tests")
struct HealthKitTypesTests {
    // MARK: - HealthQuantityType Tests

    @Suite("HealthQuantityType")
    struct HealthQuantityTypeTests {
        @Test("Encodes to expected JSON string values")
        func encodesToExpectedValues() throws {
            let encoder = JSONEncoder()

            let stepCount = try encoder.encode(HealthQuantityType.stepCount)
            #expect(String(data: stepCount, encoding: .utf8) == "\"stepCount\"")

            let heartRate = try encoder.encode(HealthQuantityType.heartRate)
            #expect(String(data: heartRate, encoding: .utf8) == "\"heartRate\"")

            let activeEnergy = try encoder.encode(HealthQuantityType.activeEnergyBurned)
            #expect(String(data: activeEnergy, encoding: .utf8) == "\"activeEnergyBurned\"")

            let bodyMass = try encoder.encode(HealthQuantityType.bodyMass)
            #expect(String(data: bodyMass, encoding: .utf8) == "\"bodyMass\"")
        }

        @Test("Decodes from JSON string values")
        func decodesFromJSONStrings() throws {
            let decoder = JSONDecoder()

            let stepCount = try decoder.decode(
                HealthQuantityType.self,
                from: "\"stepCount\"".data(using: .utf8)!
            )
            #expect(stepCount == .stepCount)

            let heartRate = try decoder.decode(
                HealthQuantityType.self,
                from: "\"heartRate\"".data(using: .utf8)!
            )
            #expect(heartRate == .heartRate)

            let distanceWalkingRunning = try decoder.decode(
                HealthQuantityType.self,
                from: "\"distanceWalkingRunning\"".data(using: .utf8)!
            )
            #expect(distanceWalkingRunning == .distanceWalkingRunning)
        }

        @Test("Throws error for invalid value")
        func throwsForInvalidValue() {
            let decoder = JSONDecoder()

            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(
                    HealthQuantityType.self,
                    from: "\"invalid_type\"".data(using: .utf8)!
                )
            }
        }

        @Test("Is Sendable")
        func isSendable() async {
            let type = HealthQuantityType.heartRate

            await Task.detached {
                #expect(type == .heartRate)
            }.value
        }

        @Test("All cases are defined")
        func allCasesAreDefined() {
            let allCases = HealthQuantityType.allCases
            #expect(allCases.count >= 20)
            #expect(allCases.contains(.stepCount))
            #expect(allCases.contains(.heartRate))
            #expect(allCases.contains(.activeEnergyBurned))
            #expect(allCases.contains(.distanceWalkingRunning))
            #expect(allCases.contains(.bodyMass))
        }
    }

    // MARK: - WorkoutActivityType Tests

    @Suite("WorkoutActivityType")
    struct WorkoutActivityTypeTests {
        @Test("Encodes to expected JSON string values")
        func encodesToExpectedValues() throws {
            let encoder = JSONEncoder()

            let running = try encoder.encode(WorkoutActivityType.running)
            #expect(String(data: running, encoding: .utf8) == "\"running\"")

            let strengthTraining = try encoder.encode(WorkoutActivityType.strengthTraining)
            #expect(String(data: strengthTraining, encoding: .utf8) == "\"strengthTraining\"")

            let stairClimbing = try encoder.encode(WorkoutActivityType.stairClimbing)
            #expect(String(data: stairClimbing, encoding: .utf8) == "\"stairClimbing\"")

            let hiit = try encoder.encode(WorkoutActivityType.hiit)
            #expect(String(data: hiit, encoding: .utf8) == "\"hiit\"")
        }

        @Test("Decodes from JSON string values")
        func decodesFromJSONStrings() throws {
            let decoder = JSONDecoder()

            let running = try decoder.decode(
                WorkoutActivityType.self,
                from: "\"running\"".data(using: .utf8)!
            )
            #expect(running == .running)

            let yoga = try decoder.decode(
                WorkoutActivityType.self,
                from: "\"yoga\"".data(using: .utf8)!
            )
            #expect(yoga == .yoga)

            let mixedCardio = try decoder.decode(
                WorkoutActivityType.self,
                from: "\"mixedCardio\"".data(using: .utf8)!
            )
            #expect(mixedCardio == .mixedCardio)
        }

        @Test("Throws error for invalid value")
        func throwsForInvalidValue() {
            let decoder = JSONDecoder()

            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(
                    WorkoutActivityType.self,
                    from: "\"invalid_workout\"".data(using: .utf8)!
                )
            }
        }

        @Test("Is Sendable")
        func isSendable() async {
            let type = WorkoutActivityType.cycling

            await Task.detached {
                #expect(type == .cycling)
            }.value
        }

        @Test("All cases are defined")
        func allCasesAreDefined() {
            let allCases = WorkoutActivityType.allCases
            #expect(allCases.count >= 18)
            #expect(allCases.contains(.running))
            #expect(allCases.contains(.swimming))
            #expect(allCases.contains(.yoga))
            #expect(allCases.contains(.other))
        }
    }

    // MARK: - SleepStage Tests

    @Suite("SleepStage")
    struct SleepStageTests {
        @Test("Encodes to expected JSON string values")
        func encodesToExpectedValues() throws {
            let encoder = JSONEncoder()

            let inBed = try encoder.encode(SleepStage.inBed)
            #expect(String(data: inBed, encoding: .utf8) == "\"inBed\"")

            let deepSleep = try encoder.encode(SleepStage.asleepDeep)
            #expect(String(data: deepSleep, encoding: .utf8) == "\"asleepDeep\"")

            let rem = try encoder.encode(SleepStage.asleepREM)
            #expect(String(data: rem, encoding: .utf8) == "\"asleepREM\"")
        }

        @Test("Decodes from JSON string values")
        func decodesFromJSONStrings() throws {
            let decoder = JSONDecoder()

            let inBed = try decoder.decode(
                SleepStage.self,
                from: "\"inBed\"".data(using: .utf8)!
            )
            #expect(inBed == .inBed)

            let core = try decoder.decode(
                SleepStage.self,
                from: "\"asleepCore\"".data(using: .utf8)!
            )
            #expect(core == .asleepCore)

            let awake = try decoder.decode(
                SleepStage.self,
                from: "\"awake\"".data(using: .utf8)!
            )
            #expect(awake == .awake)
        }

        @Test("Throws error for invalid value")
        func throwsForInvalidValue() {
            let decoder = JSONDecoder()

            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(
                    SleepStage.self,
                    from: "\"invalid_stage\"".data(using: .utf8)!
                )
            }
        }

        @Test("Is Sendable")
        func isSendable() async {
            let stage = SleepStage.asleepDeep

            await Task.detached {
                #expect(stage == .asleepDeep)
            }.value
        }

        @Test("All cases are defined")
        func allCasesAreDefined() {
            let allCases = SleepStage.allCases
            #expect(allCases.count == 6)
            #expect(allCases.contains(.inBed))
            #expect(allCases.contains(.awake))
            #expect(allCases.contains(.asleepCore))
            #expect(allCases.contains(.asleepDeep))
            #expect(allCases.contains(.asleepREM))
            #expect(allCases.contains(.asleepUnspecified))
        }
    }

    // MARK: - HealthSample Tests

    @Suite("HealthSample")
    struct HealthSampleTests {
        let startDate = Date(timeIntervalSince1970: 1_705_312_200) // 2024-01-15T10:30:00Z
        let endDate = Date(timeIntervalSince1970: 1_705_312_200)

        @Test("Encodes with all fields")
        func encodesWithAllFields() throws {
            let sample = HealthSample(
                value: 72.0,
                unit: "count/min",
                startDate: startDate,
                endDate: endDate,
                quantityType: .heartRate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(sample)
            let json = String(data: data, encoding: .utf8)!

            // Note: JSON may encode 72.0 as "72" or "72.0" depending on platform
            // Note: JSON escapes forward slash as \/ so "count/min" becomes "count\/min"
            #expect(json.contains("\"value\":72") || json.contains("\"value\":72.0"))
            #expect(json.contains("\"unit\":\"count\\/min\"") || json.contains("\"unit\":\"count/min\""))
            #expect(json.contains("\"quantityType\":\"heartRate\""))
        }

        @Test("Encodes with minimal fields")
        func encodesWithMinimalFields() throws {
            let sample = HealthSample(
                value: 10000,
                unit: "count",
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sample)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"value\":10000"))
            #expect(json.contains("\"unit\":\"count\""))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "value": 85.5,
                "unit": "kg",
                "startDate": "2024-01-15T10:30:00Z",
                "endDate": "2024-01-15T10:30:00Z",
                "quantityType": "bodyMass"
            }
            """

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sample = try decoder.decode(
                HealthSample.self,
                from: json.data(using: .utf8)!
            )

            #expect(sample.value == 85.5)
            #expect(sample.unit == "kg")
            #expect(sample.quantityType == .bodyMass)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = HealthSample(
                value: 5000,
                unit: "count",
                startDate: startDate,
                endDate: endDate,
                quantityType: .stepCount
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(HealthSample.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let sample = HealthSample(
                value: 120,
                unit: "count/min",
                startDate: startDate,
                endDate: endDate,
                quantityType: .heartRate
            )

            await Task.detached {
                #expect(sample.value == 120)
            }.value
        }
    }

    // MARK: - WorkoutData Tests

    @Suite("WorkoutData")
    struct WorkoutDataTests {
        let startDate = Date(timeIntervalSince1970: 1_705_302_000) // 2024-01-15T07:00:00Z
        let endDate = Date(timeIntervalSince1970: 1_705_303_800) // 2024-01-15T07:30:00Z

        @Test("Encodes with all fields")
        func encodesWithAllFields() throws {
            let workout = WorkoutData(
                type: .running,
                duration: 1800.0,
                calories: 350.5,
                distance: 5000.0,
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(workout)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"type\":\"running\""))
            #expect(json.contains("\"duration\":1800"))
            #expect(json.contains("\"calories\":350.5"))
            #expect(json.contains("\"distance\":5000"))
        }

        @Test("Encodes with minimal fields")
        func encodesWithMinimalFields() throws {
            let workout = WorkoutData(
                type: .yoga,
                duration: 3600.0,
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(workout)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"type\":\"yoga\""))
            #expect(json.contains("\"duration\":3600"))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "type": "cycling",
                "duration": 2400.0,
                "calories": 500.0,
                "distance": 15000.0,
                "startDate": "2024-01-15T07:00:00Z",
                "endDate": "2024-01-15T07:40:00Z"
            }
            """

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let workout = try decoder.decode(
                WorkoutData.self,
                from: json.data(using: .utf8)!
            )

            #expect(workout.type == .cycling)
            #expect(workout.duration == 2400.0)
            #expect(workout.calories == 500.0)
            #expect(workout.distance == 15000.0)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = WorkoutData(
                type: .swimming,
                duration: 1200.0,
                calories: 200.0,
                distance: 1000.0,
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(WorkoutData.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let workout = WorkoutData(
                type: .running,
                duration: 1800.0,
                calories: 350.5,
                startDate: startDate,
                endDate: endDate
            )

            await Task.detached {
                #expect(workout.type == .running)
            }.value
        }
    }

    // MARK: - SleepSample Tests

    @Suite("SleepSample")
    struct SleepSampleTests {
        let startDate = Date(timeIntervalSince1970: 1_705_280_400) // 2024-01-15T01:00:00Z
        let endDate = Date(timeIntervalSince1970: 1_705_284_900) // 2024-01-15T02:15:00Z

        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let sample = SleepSample(
                stage: .asleepDeep,
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(sample)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"stage\":\"asleepDeep\""))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "stage": "asleepREM",
                "startDate": "2024-01-15T01:00:00Z",
                "endDate": "2024-01-15T02:15:00Z"
            }
            """

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sample = try decoder.decode(
                SleepSample.self,
                from: json.data(using: .utf8)!
            )

            #expect(sample.stage == .asleepREM)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = SleepSample(
                stage: .asleepCore,
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(SleepSample.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let sample = SleepSample(
                stage: .awake,
                startDate: startDate,
                endDate: endDate
            )

            await Task.detached {
                #expect(sample.stage == .awake)
            }.value
        }
    }

    // MARK: - HealthQueryRequest Tests

    @Suite("HealthQueryRequest")
    struct HealthQueryRequestTests {
        let startDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01T00:00:00Z
        let endDate = Date(timeIntervalSince1970: 1_705_363_199) // 2024-01-15T23:59:59Z

        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let request = HealthQueryRequest(
                quantityType: .stepCount,
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"quantityType\":\"stepCount\""))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "quantityType": "heartRate",
                "startDate": "2024-01-01T00:00:00Z",
                "endDate": "2024-01-15T23:59:59Z"
            }
            """

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let request = try decoder.decode(
                HealthQueryRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.quantityType == .heartRate)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = HealthQueryRequest(
                quantityType: .activeEnergyBurned,
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(HealthQueryRequest.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let request = HealthQueryRequest(
                quantityType: .stepCount,
                startDate: startDate,
                endDate: endDate
            )

            await Task.detached {
                #expect(request.quantityType == .stepCount)
            }.value
        }
    }

    // MARK: - WorkoutQueryRequest Tests

    @Suite("WorkoutQueryRequest")
    struct WorkoutQueryRequestTests {
        let startDate = Date(timeIntervalSince1970: 1_704_067_200)
        let endDate = Date(timeIntervalSince1970: 1_705_363_199)

        @Test("Encodes with workout type filter")
        func encodesWithWorkoutType() throws {
            let request = WorkoutQueryRequest(
                startDate: startDate,
                endDate: endDate,
                workoutType: .running
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"workoutType\":\"running\""))
        }

        @Test("Encodes without workout type filter")
        func encodesWithoutWorkoutType() throws {
            let request = WorkoutQueryRequest(
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"workoutType\":null") || !json.contains("\"workoutType\""))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "startDate": "2024-01-01T00:00:00Z",
                "endDate": "2024-01-15T23:59:59Z",
                "workoutType": "swimming"
            }
            """

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let request = try decoder.decode(
                WorkoutQueryRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.workoutType == .swimming)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = WorkoutQueryRequest(
                startDate: startDate,
                endDate: endDate,
                workoutType: .cycling
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(WorkoutQueryRequest.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let request = WorkoutQueryRequest(
                startDate: startDate,
                endDate: endDate
            )

            await Task.detached {
                #expect(request.workoutType == nil)
            }.value
        }
    }

    // MARK: - SleepQueryRequest Tests

    @Suite("SleepQueryRequest")
    struct SleepQueryRequestTests {
        let startDate = Date(timeIntervalSince1970: 1_705_269_600) // 2024-01-14T22:00:00Z
        let endDate = Date(timeIntervalSince1970: 1_705_302_000) // 2024-01-15T07:00:00Z

        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let request = SleepQueryRequest(
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"startDate\""))
            #expect(json.contains("\"endDate\""))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "startDate": "2024-01-14T22:00:00Z",
                "endDate": "2024-01-15T07:00:00Z"
            }
            """

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let request = try decoder.decode(
                SleepQueryRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.startDate == startDate)
            #expect(request.endDate == endDate)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = SleepQueryRequest(
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(SleepQueryRequest.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let request = SleepQueryRequest(
                startDate: startDate,
                endDate: endDate
            )

            await Task.detached {
                #expect(request.startDate == startDate)
            }.value
        }
    }

    // MARK: - SaveWorkoutRequest Tests

    @Suite("SaveWorkoutRequest")
    struct SaveWorkoutRequestTests {
        let startDate = Date(timeIntervalSince1970: 1_705_302_000)
        let endDate = Date(timeIntervalSince1970: 1_705_303_800)

        @Test("Encodes with all fields")
        func encodesWithAllFields() throws {
            let request = SaveWorkoutRequest(
                workoutType: .running,
                startDate: startDate,
                endDate: endDate,
                calories: 350.5,
                distance: 5000.0
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"workoutType\":\"running\""))
            #expect(json.contains("\"calories\":350.5"))
            #expect(json.contains("\"distance\":5000"))
        }

        @Test("Encodes with minimal fields")
        func encodesWithMinimalFields() throws {
            let request = SaveWorkoutRequest(
                workoutType: .yoga,
                startDate: startDate,
                endDate: endDate
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"workoutType\":\"yoga\""))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "workoutType": "cycling",
                "startDate": "2024-01-15T07:00:00Z",
                "endDate": "2024-01-15T07:30:00Z",
                "calories": 500.0,
                "distance": 15000.0
            }
            """

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let request = try decoder.decode(
                SaveWorkoutRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.workoutType == .cycling)
            #expect(request.calories == 500.0)
            #expect(request.distance == 15000.0)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = SaveWorkoutRequest(
                workoutType: .swimming,
                startDate: startDate,
                endDate: endDate,
                calories: 200.0,
                distance: 1000.0
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(SaveWorkoutRequest.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let request = SaveWorkoutRequest(
                workoutType: .running,
                startDate: startDate,
                endDate: endDate
            )

            await Task.detached {
                #expect(request.workoutType == .running)
            }.value
        }
    }

    // MARK: - AuthorizationRequest Tests

    @Suite("AuthorizationRequest")
    struct AuthorizationRequestTests {
        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let request = AuthorizationRequest(
                read: [.stepCount, .heartRate],
                write: [.stepCount]
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"read\""))
            #expect(json.contains("\"stepCount\""))
            #expect(json.contains("\"heartRate\""))
            #expect(json.contains("\"write\""))
        }

        @Test("Encodes with empty write array")
        func encodesWithEmptyWrite() throws {
            let request = AuthorizationRequest(
                read: [.heartRate]
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"write\":[]"))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "read": ["stepCount", "activeEnergyBurned"],
                "write": ["stepCount"]
            }
            """

            let decoder = JSONDecoder()
            let request = try decoder.decode(
                AuthorizationRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.read.count == 2)
            #expect(request.read.contains(.stepCount))
            #expect(request.read.contains(.activeEnergyBurned))
            #expect(request.write.count == 1)
            #expect(request.write.contains(.stepCount))
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = AuthorizationRequest(
                read: [.heartRate, .stepCount],
                write: [.activeEnergyBurned]
            )

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AuthorizationRequest.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let request = AuthorizationRequest(
                read: [.stepCount],
                write: []
            )

            await Task.detached {
                #expect(request.read.count == 1)
            }.value
        }
    }

    // MARK: - HealthSamplesResponse Tests

    @Suite("HealthSamplesResponse")
    struct HealthSamplesResponseTests {
        let startDate = Date(timeIntervalSince1970: 1_705_312_200)

        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let response = HealthSamplesResponse(samples: [
                HealthSample(
                    value: 72.0,
                    unit: "count/min",
                    startDate: startDate,
                    endDate: startDate,
                    quantityType: .heartRate
                ),
            ])

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"samples\""))
            #expect(json.contains("\"value\":72"))
        }

        @Test("Empty static property has correct values")
        func emptyStaticProperty() {
            let empty = HealthSamplesResponse.empty

            #expect(empty.samples.isEmpty)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = HealthSamplesResponse(samples: [
                HealthSample(
                    value: 5000,
                    unit: "count",
                    startDate: startDate,
                    endDate: startDate,
                    quantityType: .stepCount
                ),
            ])

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(HealthSamplesResponse.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let response = HealthSamplesResponse.empty

            await Task.detached {
                #expect(response.samples.isEmpty)
            }.value
        }
    }

    // MARK: - WorkoutsResponse Tests

    @Suite("WorkoutsResponse")
    struct WorkoutsResponseTests {
        let startDate = Date(timeIntervalSince1970: 1_705_302_000)
        let endDate = Date(timeIntervalSince1970: 1_705_303_800)

        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let response = WorkoutsResponse(workouts: [
                WorkoutData(
                    type: .running,
                    duration: 1800.0,
                    calories: 350.5,
                    startDate: startDate,
                    endDate: endDate
                ),
            ])

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"workouts\""))
            #expect(json.contains("\"type\":\"running\""))
        }

        @Test("Empty static property has correct values")
        func emptyStaticProperty() {
            let empty = WorkoutsResponse.empty

            #expect(empty.workouts.isEmpty)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = WorkoutsResponse(workouts: [
                WorkoutData(
                    type: .yoga,
                    duration: 3600.0,
                    startDate: startDate,
                    endDate: endDate
                ),
            ])

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(WorkoutsResponse.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let response = WorkoutsResponse.empty

            await Task.detached {
                #expect(response.workouts.isEmpty)
            }.value
        }
    }

    // MARK: - SleepResponse Tests

    @Suite("SleepResponse")
    struct SleepResponseTests {
        let startDate = Date(timeIntervalSince1970: 1_705_280_400)
        let endDate = Date(timeIntervalSince1970: 1_705_284_900)

        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let response = SleepResponse(samples: [
                SleepSample(
                    stage: .asleepDeep,
                    startDate: startDate,
                    endDate: endDate
                ),
            ])

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"samples\""))
            #expect(json.contains("\"stage\":\"asleepDeep\""))
        }

        @Test("Empty static property has correct values")
        func emptyStaticProperty() {
            let empty = SleepResponse.empty

            #expect(empty.samples.isEmpty)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = SleepResponse(samples: [
                SleepSample(
                    stage: .asleepREM,
                    startDate: startDate,
                    endDate: endDate
                ),
            ])

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(SleepResponse.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let response = SleepResponse.empty

            await Task.detached {
                #expect(response.samples.isEmpty)
            }.value
        }
    }

    // MARK: - HealthKitAvailabilityResponse Tests

    @Suite("HealthKitAvailabilityResponse")
    struct HealthKitAvailabilityResponseTests {
        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let response = HealthKitAvailabilityResponse(available: true)

            let encoder = JSONEncoder()
            let data = try encoder.encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json == "{\"available\":true}")
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = "{\"available\":false}"

            let decoder = JSONDecoder()
            let response = try decoder.decode(
                HealthKitAvailabilityResponse.self,
                from: json.data(using: .utf8)!
            )

            #expect(response.available == false)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = HealthKitAvailabilityResponse(available: true)

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(HealthKitAvailabilityResponse.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let response = HealthKitAvailabilityResponse(available: true)

            await Task.detached {
                #expect(response.available == true)
            }.value
        }
    }

    // MARK: - SaveWorkoutResponse Tests

    @Suite("SaveWorkoutResponse")
    struct SaveWorkoutResponseTests {
        @Test("Successful save encodes correctly")
        func successfulSaveEncodes() throws {
            let response = SaveWorkoutResponse()

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"success\":true"))
            #expect(!json.contains("\"error\"") || json.contains("\"error\":null"))
        }

        @Test("Failed save encodes correctly")
        func failedSaveEncodes() throws {
            let response = SaveWorkoutResponse(error: "Authorization denied")

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"success\":false"))
            #expect(json.contains("\"error\":\"Authorization denied\""))
        }

        @Test("Decodes successful response from JSON")
        func decodesSuccessfulFromJSON() throws {
            let json = """
            {
                "success": true,
                "error": null
            }
            """

            let decoder = JSONDecoder()
            let response = try decoder.decode(
                SaveWorkoutResponse.self,
                from: json.data(using: .utf8)!
            )

            #expect(response.success == true)
            #expect(response.error == nil)
        }

        @Test("Decodes failed response from JSON")
        func decodesFailedFromJSON() throws {
            let json = """
            {
                "success": false,
                "error": "Unable to save workout"
            }
            """

            let decoder = JSONDecoder()
            let response = try decoder.decode(
                SaveWorkoutResponse.self,
                from: json.data(using: .utf8)!
            )

            #expect(response.success == false)
            #expect(response.error == "Unable to save workout")
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = SaveWorkoutResponse()

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(SaveWorkoutResponse.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let response = SaveWorkoutResponse()

            await Task.detached {
                #expect(response.success == true)
            }.value
        }

        @Test("Convenience initializer for success sets correct values")
        func successInitializerSetsCorrectValues() {
            let response = SaveWorkoutResponse()

            #expect(response.success == true)
            #expect(response.error == nil)
        }

        @Test("Convenience initializer for failure sets correct values")
        func failureInitializerSetsCorrectValues() {
            let response = SaveWorkoutResponse(error: "Something went wrong")

            #expect(response.success == false)
            #expect(response.error == "Something went wrong")
        }
    }
}
