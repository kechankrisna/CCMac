import Foundation
import Darwin
import IOKit
import IOKit.ps

// MARK: - Real-time System Monitor using macOS APIs
class SystemMonitorService: ObservableObject {
    @Published var metrics = SystemMetrics(
        cpuUsage: 0, ramUsed: 0, ramTotal: 0,
        diskUsed: 0, diskTotal: 0,
        batteryLevel: 100, networkDown: 0, networkUp: 0
    )
    @Published var cpuHistory:     [Double] = Array(repeating: 0, count: 60)
    @Published var ramHistory:     [Double] = Array(repeating: 0, count: 60)
    @Published var diskHistory:    [Double] = Array(repeating: 0, count: 60)
    @Published var batteryHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var netDownHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var netUpHistory:   [Double] = Array(repeating: 0, count: 60)
    @Published var processes: [ProcessInfo2] = []

    private var timer: Timer?
    private var prevNetIn: UInt64 = 0
    private var prevNetOut: UInt64 = 0

    struct ProcessInfo2: Identifiable {
        let id: Int32
        var name: String
        var cpuUsage: Double
        var ramUsage: Int64
        var ramString: String { ByteCountFormatter.string(fromByteCount: ramUsage, countStyle: .memory) }
    }

    func startMonitoring() {
        updateMetrics()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateMetrics()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateMetrics() {
        DispatchQueue.global(qos: .utility).async {
            let cpu = self.getCPUUsage()
            let ram = self.getRAMUsage()
            let disk = self.getDiskUsage()
            let battery = self.getBatteryLevel()
            let net = self.getNetworkUsage()
            let procs = self.getTopProcesses()

            DispatchQueue.main.async {
                self.metrics = SystemMetrics(
                    cpuUsage: cpu,
                    ramUsed: ram.used,
                    ramTotal: ram.total,
                    diskUsed: disk.used,
                    diskTotal: disk.total,
                    batteryLevel: battery,
                    networkDown: net.down,
                    networkUp: net.up
                )
                self.cpuHistory.append(cpu)
                if self.cpuHistory.count > 60 { self.cpuHistory.removeFirst() }
                self.ramHistory.append(self.metrics.ramPercent * 100)
                if self.ramHistory.count > 60 { self.ramHistory.removeFirst() }
                self.diskHistory.append(self.metrics.diskPercent * 100)
                if self.diskHistory.count > 60 { self.diskHistory.removeFirst() }
                self.batteryHistory.append(battery)
                if self.batteryHistory.count > 60 { self.batteryHistory.removeFirst() }
                self.netDownHistory.append(net.down)
                if self.netDownHistory.count > 60 { self.netDownHistory.removeFirst() }
                self.netUpHistory.append(net.up)
                if self.netUpHistory.count > 60 { self.netUpHistory.removeFirst() }
                self.processes = procs
            }
        }
    }

    // MARK: - CPU Usage via host_statistics
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                          &numCpus, &cpuInfo, &numCpuInfo)
        guard result == KERN_SUCCESS else { return 0 }

        var totalUser: Int32 = 0, totalSystem: Int32 = 0, totalIdle: Int32 = 0
        for i in 0..<Int(numCpus) {
            totalUser   += cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)]
            totalSystem += cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)]
            totalIdle   += cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)]
        }
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo))

        let total = Double(totalUser + totalSystem + totalIdle)
        guard total > 0 else { return 0 }
        return Double(totalUser + totalSystem) / total * 100.0
    }

    // MARK: - RAM Usage via host_statistics64
    private func getRAMUsage() -> (used: Int64, total: Int64) {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let pageSize = Int64(vm_kernel_page_size)
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        guard result == KERN_SUCCESS else { return (0, total) }
        let free = Int64(stats.free_count + stats.inactive_count) * pageSize
        let used = total - free
        return (used, total)
    }

    // MARK: - Disk Usage via FileManager
    private func getDiskUsage() -> (used: Int64, total: Int64) {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free  = (attrs[.systemFreeSize] as? Int64) ?? 0
            return (total - free, total)
        } catch { return (0, 0) }
    }

    // MARK: - Battery Level via IOKit
    private func getBatteryLevel() -> Double {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources  = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        for source in sources {
            let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as! [String: Any]
            if let capacity = description[kIOPSCurrentCapacityKey as String] as? Int,
               let max      = description[kIOPSMaxCapacityKey as String] as? Int,
               max > 0 {
                return Double(capacity) / Double(max) * 100.0
            }
        }
        return 100.0 // Desktop Mac — no battery
    }

    // MARK: - Network Usage via getifaddrs (safe, no raw buffer arithmetic)
    private func getNetworkUsage() -> (down: Double, up: Double) {
        var totalIn:  UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return (0, 0) }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            let interface = addr.pointee
            // AF_LINK entries carry the per-interface byte counters
            if interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = interface.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                totalIn  += UInt64(ifData.ifi_ibytes)
                totalOut += UInt64(ifData.ifi_obytes)
            }
            cursor = interface.ifa_next
        }

        let downDelta = totalIn  > prevNetIn  ? Double(totalIn  - prevNetIn)  / 2.0 : 0
        let upDelta   = totalOut > prevNetOut ? Double(totalOut - prevNetOut) / 2.0 : 0
        prevNetIn  = totalIn
        prevNetOut = totalOut
        return (downDelta, upDelta)
    }

    // MARK: - Top Processes via proc_listpids
    private func getTopProcesses() -> [ProcessInfo2] {
        var result: [ProcessInfo2] = []
        let count = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard count > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(count))
        proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, count)

        for pid in pids where pid > 0 {
            var info = proc_taskinfo()
            let sz = MemoryLayout<proc_taskinfo>.size
            let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(sz))
            guard ret == Int32(sz) else { continue }

            let pathBufSize = 4096  // PROC_PIDPATHINFO_MAXSIZE
            var name = [CChar](repeating: 0, count: pathBufSize)
            proc_pidpath(pid, &name, UInt32(pathBufSize))
            var displayName = String(cString: name)
            if displayName.isEmpty { displayName = "pid \(pid)" }
            displayName = (displayName as NSString).lastPathComponent

            let ram = Int64(info.pti_resident_size)
            let cpu = Double(info.pti_total_user + info.pti_total_system) / Double(NSEC_PER_SEC)
            result.append(ProcessInfo2(id: pid, name: displayName, cpuUsage: cpu, ramUsage: ram))
        }
        return result
            .filter { $0.ramUsage > 1_000_000 }
            .sorted { $0.ramUsage > $1.ramUsage }
            .prefix(20)
            .map { $0 }
    }

    func freeRAM() {
        // Purge inactive pages — requires privilege; best-effort
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
        try? task.run()
    }
}
