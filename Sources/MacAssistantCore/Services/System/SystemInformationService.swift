import Darwin
import Darwin.Mach
import Foundation

/// Последовательные значения суммарных процессорных тиков ядра.
/// Абсолютное значение не интерпретируется: для нагрузки важна только разница.
public struct CPUTimeSnapshot: Equatable, Sendable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

/// Чистая функция вынесена из Mach-вызова, чтобы критичный расчёт можно было
/// проверить на фиксированных значениях без зависимости от текущей нагрузки Mac.
public enum CPUUsageCalculator {
    public static func usagePercent(previous: CPUTimeSnapshot, current: CPUTimeSnapshot) -> Double? {
        let userDelta = current.user >= previous.user ? current.user - previous.user : 0
        let systemDelta = current.system >= previous.system ? current.system - previous.system : 0
        let idleDelta = current.idle >= previous.idle ? current.idle - previous.idle : 0
        let niceDelta = current.nice >= previous.nice ? current.nice - previous.nice : 0
        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta

        guard totalDelta > 0 else { return nil }
        let activeDelta = userDelta + systemDelta + niceDelta
        return min(100, (Double(activeDelta) / Double(totalDelta)) * 100)
    }
}

public struct MemoryPageSnapshot: Equatable, Sendable {
    public let pageSize: UInt64
    public let freePages: UInt64
    public let inactivePages: UInt64

    public init(pageSize: UInt64, freePages: UInt64, inactivePages: UInt64) {
        self.pageSize = pageSize
        self.freePages = freePages
        self.inactivePages = inactivePages
    }
}

public enum MemoryUsageCalculator {
    /// Inactive-страницы считаются доступными для повторного использования
    /// системой. Это не показатель pressure, поэтому он возвращается отдельно.
    public static func availableBytes(from snapshot: MemoryPageSnapshot) -> UInt64 {
        let availablePages = snapshot.freePages.addingReportingOverflow(snapshot.inactivePages)
        let pages = availablePages.overflow ? UInt64.max : availablePages.partialValue
        let bytes = pages.multipliedReportingOverflow(by: snapshot.pageSize)
        return bytes.overflow ? UInt64.max : bytes.partialValue
    }

    public static func usedBytes(totalBytes: UInt64, availableBytes: UInt64) -> UInt64 {
        totalBytes >= availableBytes ? totalBytes - availableBytes : 0
    }
}

/// Читает только публичные системные счётчики и не требует `sudo`, TCC-разрешений
/// или запуска внешних процессов. Actor сериализует доступ к предыдущему CPU-снимку.
public actor SystemInformationService: SystemInformationProviding {
    private var previousCPUSnapshot: CPUTimeSnapshot?

    public init() {}

    public func systemInfo() async throws -> SystemInfo {
        let physicalCores = try sysctlInteger(named: "hw.physicalcpu")
        let logicalCores = try sysctlInteger(named: "hw.logicalcpu")
        let modelIdentifier = try sysctlString(named: "hw.model")
        let architecture = try sysctlString(named: "hw.machine")

        return SystemInfo(
            modelName: modelIdentifier,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: architecture,
            physicalCPUCoreCount: physicalCores,
            logicalCPUCoreCount: logicalCores
        )
    }

    public func systemMetrics() async throws -> SystemMetrics {
        let currentCPU = try readCPUSnapshot()
        let cpuUsage = previousCPUSnapshot.flatMap {
            CPUUsageCalculator.usagePercent(previous: $0, current: currentCPU)
        }
        previousCPUSnapshot = currentCPU

        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memorySnapshot = try readMemoryPageSnapshot()
        let availableMemory = MemoryUsageCalculator.availableBytes(from: memorySnapshot)
        let storage = try readStorageCapacity()

        return SystemMetrics(
            cpuUsagePercent: cpuUsage,
            totalMemoryBytes: totalMemory,
            usedMemoryBytes: MemoryUsageCalculator.usedBytes(
                totalBytes: totalMemory,
                availableBytes: availableMemory
            ),
            availableMemoryBytes: availableMemory,
            // В публичном API на этом этапе нет достаточного сигнала для
            // достоверной классификации pressure, поэтому значение не выдумывается.
            memoryPressure: nil,
            totalStorageBytes: storage.total,
            availableStorageBytes: storage.available
        )
    }

    private func readCPUSnapshot() throws -> CPUTimeSnapshot {
        var cpuLoad = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &cpuLoad) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw SystemServiceError.machCallFailed(code: result) }

        return CPUTimeSnapshot(
            user: UInt64(cpuLoad.cpu_ticks.0),
            system: UInt64(cpuLoad.cpu_ticks.1),
            idle: UInt64(cpuLoad.cpu_ticks.2),
            nice: UInt64(cpuLoad.cpu_ticks.3)
        )
    }

    private func readMemoryPageSnapshot() throws -> MemoryPageSnapshot {
        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw SystemServiceError.machCallFailed(code: result) }

        return MemoryPageSnapshot(
            pageSize: UInt64(vm_kernel_page_size),
            freePages: UInt64(statistics.free_count),
            inactivePages: UInt64(statistics.inactive_count)
        )
    }

    private func readStorageCapacity() throws -> (total: UInt64, available: UInt64) {
        let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
        let values = try rootURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        guard let total = values.volumeTotalCapacity, total > 0 else {
            throw SystemServiceError.missingValue(name: "общая ёмкость накопителя")
        }
        // Foundation использует Int64 для preferred-значения APFS и Int для
        // устаревшего fallback. Приводим их до объединения, не теряя разрядность.
        let legacyAvailable = values.volumeAvailableCapacity.map(Int64.init)
        guard let available = values.volumeAvailableCapacityForImportantUsage
            ?? legacyAvailable else {
            throw SystemServiceError.missingValue(name: "доступное место на накопителе")
        }

        return (UInt64(total), UInt64(max(available, 0)))
    }
}

private func sysctlInteger(named name: String) throws -> Int {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    let result = sysctlbyname(name, &value, &size, nil, 0)
    guard result == 0 else { throw SystemServiceError.sysctlFailed(name: name, code: errno) }
    return Int(value)
}

private func sysctlString(named name: String) throws -> String {
    var size = 0
    let sizeResult = sysctlbyname(name, nil, &size, nil, 0)
    guard sizeResult == 0, size > 0 else {
        throw SystemServiceError.sysctlFailed(name: name, code: errno)
    }

    var bytes = [CChar](repeating: 0, count: size)
    let valueResult = bytes.withUnsafeMutableBufferPointer {
        sysctlbyname(name, $0.baseAddress, &size, nil, 0)
    }
    guard valueResult == 0, let value = String(validatingCString: bytes) else {
        throw SystemServiceError.sysctlFailed(name: name, code: errno)
    }
    return value
}

public enum SystemServiceError: LocalizedError, Equatable, Sendable {
    case sysctlFailed(name: String, code: Int32)
    case machCallFailed(code: kern_return_t)
    case missingValue(name: String)

    public var errorDescription: String? {
        switch self {
        case let .sysctlFailed(name, _): "Не удалось получить системное значение «\(name)»."
        case .machCallFailed: "Не удалось получить системную статистику macOS."
        case let .missingValue(name): "Система не предоставила значение: \(name)."
        }
    }
}
