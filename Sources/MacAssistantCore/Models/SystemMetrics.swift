import Foundation

/// Динамические показатели системы. Значения объёма измеряются в байтах,
/// а проценты хранятся в диапазоне от 0 до 100 для исключения неоднозначности UI.
public struct SystemMetrics: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let cpuUsagePercent: Double?
    public let totalMemoryBytes: UInt64
    public let usedMemoryBytes: UInt64
    public let availableMemoryBytes: UInt64?
    public let memoryPressure: MemoryPressure?
    public let totalStorageBytes: UInt64
    public let availableStorageBytes: UInt64

    public init(
        capturedAt: Date = .now,
        cpuUsagePercent: Double?,
        totalMemoryBytes: UInt64,
        usedMemoryBytes: UInt64,
        availableMemoryBytes: UInt64?,
        memoryPressure: MemoryPressure?,
        totalStorageBytes: UInt64,
        availableStorageBytes: UInt64
    ) {
        self.capturedAt = capturedAt
        self.cpuUsagePercent = cpuUsagePercent
        self.totalMemoryBytes = totalMemoryBytes
        self.usedMemoryBytes = usedMemoryBytes
        self.availableMemoryBytes = availableMemoryBytes
        self.memoryPressure = memoryPressure
        self.totalStorageBytes = totalStorageBytes
        self.availableStorageBytes = availableStorageBytes
    }

    /// Защита от некорректных системных данных: при нулевой ёмкости возвращается
    /// `nil`, вместо вводящего в заблуждение процента.
    public var storageUsagePercent: Double? {
        guard totalStorageBytes > 0 else { return nil }
        // APFS способен вернуть доступное пространство больше логической ёмкости
        // из-за снимков или особенностей тома. Не допускаем переполнения UInt64.
        let used = totalStorageBytes >= availableStorageBytes
            ? totalStorageBytes - availableStorageBytes
            : 0
        return (Double(used) / Double(totalStorageBytes)) * 100
    }
}

public enum MemoryPressure: String, Codable, CaseIterable, Sendable {
    case normal
    case warning
    case critical
}
