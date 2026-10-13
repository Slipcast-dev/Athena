import XCTest
@testable import MacAssistantCore

final class ArchitectureTests: XCTestCase {
    /// Контейнер не должен подменять отсутствие реализации фиктивными метриками.
    @MainActor
    func testDefaultContainerReportsUnavailableSystemInformation() async {
        let container = AppContainer.makeDefault()

        do {
            _ = try await container.services.systemInformation.systemInfo()
            XCTFail("Ожидалась явная ошибка отсутствующей реализации")
        } catch let error as ServiceError {
            XCTAssertEqual(error, .unavailable(feature: "Системная информация"))
        } catch {
            XCTFail("Получена неожиданная ошибка: \(error)")
        }
    }

    func testStorageUsageIsNilWhenTotalStorageIsZero() {
        let metrics = SystemMetrics(
            cpuUsagePercent: nil,
            totalMemoryBytes: 0,
            usedMemoryBytes: 0,
            availableMemoryBytes: nil,
            memoryPressure: nil,
            totalStorageBytes: 0,
            availableStorageBytes: 0
        )

        XCTAssertNil(metrics.storageUsagePercent)
    }

    func testStorageUsageUsesTotalAndAvailableBytes() {
        let metrics = SystemMetrics(
            cpuUsagePercent: nil,
            totalMemoryBytes: 0,
            usedMemoryBytes: 0,
            availableMemoryBytes: nil,
            memoryPressure: nil,
            totalStorageBytes: 1_000,
            availableStorageBytes: 250
        )

        XCTAssertEqual(metrics.storageUsagePercent, 75)
    }
}
