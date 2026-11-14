import Foundation
import CoreGraphics

// Configuration JSON Model
struct AppConfig: Codable {
    var preferredWidth: Int32?
    var preferredHeight: Int32?
    var requireHiDPI: Bool?
    var preferredRefreshRate: Double?
    var enablePresenterMirroring: Bool?
}

enum ConfigError: Error {
    case invalidValues
}

let defaultConfig = AppConfig(
    preferredWidth: 2560,
    preferredHeight: 1440,
    requireHiDPI: true,
    preferredRefreshRate: 60.0,
    enablePresenterMirroring: false
)

func log(_ message: String) {
    print(message)
    fflush(stdout)
}

func loadConfig() -> AppConfig {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let configURL = home.appendingPathComponent(".config/display-autoscaler/config.json")
    do {
        let data = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(AppConfig.self, from: data)
        let hasWidth = config.preferredWidth != nil
        let hasHeight = config.preferredHeight != nil
        let hasValidDimensions = hasWidth == hasHeight
            && (config.preferredWidth.map { $0 > 0 } ?? true)
            && (config.preferredHeight.map { $0 > 0 } ?? true)
        let hasValidRefreshRate = config.preferredRefreshRate.map {
            $0.isFinite && $0 > 0
        } ?? true

        guard hasValidDimensions && hasValidRefreshRate else {
            throw ConfigError.invalidValues
        }
        return config
    } catch {
        log("[display-autoscaler:warn] Could not load a valid config.json, using conservative defaults: \(error)")
        return defaultConfig
    }
}

// Helper to query detailed text descriptions of a display mode
func getDisplayDetailsString(displayID: CGDirectDisplayID) -> String {
    guard let mode = CGDisplayCopyDisplayMode(displayID), mode.width > 0, mode.height > 0 else {
        return "Unknown Mode"
    }
    let w = mode.width
    let h = mode.height
    let pw = mode.pixelWidth
    let ph = mode.pixelHeight
    let refresh = mode.refreshRate
    let isHiDPI = pw > w
    let aspect = Double(w) / Double(h)
    let aspectStr = String(format: "%.2f", aspect)
    
    return "\(w)x\(h) (Physical: \(pw)x\(ph)) | Refresh: \(refresh)Hz | Aspect: \(aspectStr) | HiDPI: \(isHiDPI)"
}

// --- Feature 5: Diagnostic Desktop Logger ---
func writeDesktopDiagnosticReport() {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let reportURL = home.appendingPathComponent("Desktop/display-diagnostic-report.txt")
    
    var report = "=== Display Autoscaler Diagnostics ===\n"
    report += "Generated: \(Date().description)\n\n"
    
    let displayCapacity: UInt32 = 16
    var onlineCount: UInt32 = 0
    var list = [CGDirectDisplayID](repeating: 0, count: Int(displayCapacity))
    guard CGGetOnlineDisplayList(displayCapacity, &list, &onlineCount) == .success else {
        log("[display-autoscaler:error] Could not get the online display list for diagnostics.")
        return
    }
    report += "Online Displays Detected: \(onlineCount)\n"

    for (i, id) in list.prefix(Int(onlineCount)).enumerated() {
        let isBuiltin = CGDisplayIsBuiltin(id) != 0
        let isActive = CGDisplayIsActive(id) != 0
        let isMirrored = CGDisplayIsInMirrorSet(id) != 0
        let details = getDisplayDetailsString(displayID: id)
        
        report += "Display [\(i)]: ID \(id)\n"
        report += "  - Built-in: \(isBuiltin)\n"
        report += "  - Active: \(isActive)\n"
        report += "  - Mirrored: \(isMirrored)\n"
        report += "  - Mode: \(details)\n\n"
    }
    
    report += "=== Troubleshooting Tips ===\n"
    report += "1. If a display is blank: Confirm macOS detects it and check the cable, adapter, dock, and display input.\n"
    report += "2. Mirroring: Enable 'enablePresenterMirroring' in config.json to mirror an external display with the built-in display.\n"
    report += "3. Hardware limits: The number of supported displays depends on your Mac model and connection setup.\n"
    
    do {
        try report.write(to: reportURL, atomically: true, encoding: .utf8)
        log("[display-autoscaler:info] Wrote diagnostic report to desktop.")
    } catch {
        log("[display-autoscaler:error] Failed to write diagnostic report: \(error)")
    }
}

func optimizeDisplaySettings(displayID: CGDirectDisplayID) {
    guard CGDisplayIsActive(displayID) != 0, CGDisplayIsBuiltin(displayID) == 0 else {
        return
    }

    let beforeDetails = getDisplayDetailsString(displayID: displayID)
    log("[display-autoscaler:info] [BEFORE] Display ID \(displayID): \(beforeDetails)")

    let config = loadConfig()
    let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
    guard let modes = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode] else {
        log("[display-autoscaler:error] Failed to fetch display modes for ID: \(displayID)")
        return
    }

    guard let currentMode = CGDisplayCopyDisplayMode(displayID),
          currentMode.width > 0, currentMode.height > 0 else {
        log("[display-autoscaler:error] Failed to read the current display mode for ID: \(displayID)")
        return
    }
    let targetAspect = Double(currentMode.width) / Double(currentMode.height)
    let aspectTolerance = 0.05

    var bestMode: CGDisplayMode? = nil
    var fallbackModes = [CGDisplayMode]()

    for mode in modes {
        let w = Int32(mode.width)
        let h = Int32(mode.height)
        let aspect = Double(w) / Double(h)
        guard w > 0, h > 0, abs(aspect - targetAspect) <= aspectTolerance else {
            continue
        }

        let isHiDPI = mode.pixelWidth > mode.width
        if (config.requireHiDPI ?? true) && !isHiDPI {
            continue
        }

        if (w == 1920 && h == 1080) || (w == 1280 && h == 720) {
            fallbackModes.append(mode)
        }

        if let prefW = config.preferredWidth, let prefH = config.preferredHeight {
            if w == prefW && h == prefH {
                if let currentBest = bestMode {
                    let targetRefresh = config.preferredRefreshRate ?? 60.0
                    if abs(mode.refreshRate - targetRefresh) < abs(currentBest.refreshRate - targetRefresh) {
                        bestMode = mode
                    }
                } else {
                    bestMode = mode
                }
            }
        } else {
            if let currentBest = bestMode {
                let modePixels = Double(mode.pixelWidth) * Double(mode.pixelHeight)
                let bestPixels = Double(currentBest.pixelWidth) * Double(currentBest.pixelHeight)
                let refreshTarget = config.preferredRefreshRate ?? 60.0
                let bestIsHiDPI = currentBest.pixelWidth > currentBest.width
                if modePixels > bestPixels
                    || (modePixels == bestPixels && isHiDPI && !bestIsHiDPI)
                    || (modePixels == bestPixels
                        && abs(mode.refreshRate - refreshTarget) < abs(currentBest.refreshRate - refreshTarget)) {
                    bestMode = mode
                }
            } else {
                bestMode = mode
            }
        }
    }
    
    let sortedFallbackModes = fallbackModes.sorted {
        Double($0.pixelWidth) * Double($0.pixelHeight)
            > Double($1.pixelWidth) * Double($1.pixelHeight)
    }

    var candidates = [CGDisplayMode]()
    if let bestMode {
        candidates.append(bestMode)
    }
    candidates.append(contentsOf: sortedFallbackModes.filter { fallback in
        !candidates.contains(where: { isSameDisplayMode($0, fallback) })
    })

    guard !candidates.isEmpty else {
        log("[display-autoscaler:warn] No suitable display mode found; leaving the current mode unchanged.")
        return
    }

    var modeApplied = false
    for candidate in candidates {
        let isSelectedHiDPI = candidate.pixelWidth > candidate.width
        log("[display-autoscaler:info] Trying Mode: \(candidate.width)x\(candidate.height) (Physical: \(candidate.pixelWidth)x\(candidate.pixelHeight)) @ \(candidate.refreshRate)Hz (HiDPI: \(isSelectedHiDPI))")
        if isSameDisplayMode(currentMode, candidate) {
            log("[display-autoscaler:info] Display already uses this mode.")
            modeApplied = true
            break
        }
        if applyDisplayMode(displayID: displayID, mode: candidate) {
            modeApplied = true
            break
        }
        log("[display-autoscaler:warn] Mode failed; trying the next compatible option.")
    }

    guard modeApplied else {
        log("[display-autoscaler:warn] Could not apply the selected mode; leaving the current mode unchanged.")
        return
    }

    if config.enablePresenterMirroring ?? false {
        configureMirroring(targetDisplayID: displayID)
    }
}

func isSameDisplayMode(_ first: CGDisplayMode, _ second: CGDisplayMode) -> Bool {
    let sameDimensions = first.width == second.width
        && first.height == second.height
        && first.pixelWidth == second.pixelWidth
        && first.pixelHeight == second.pixelHeight
    let sameRefreshRate = first.refreshRate == 0 || second.refreshRate == 0
        || abs(first.refreshRate - second.refreshRate) < 0.5
    return sameDimensions && sameRefreshRate
}

func applyDisplayMode(displayID: CGDirectDisplayID, mode: CGDisplayMode) -> Bool {
    var configRef: CGDisplayConfigRef?
    let status = CGBeginDisplayConfiguration(&configRef)
    guard status == .success, let cfg = configRef else {
        log("[display-autoscaler:error] Could not begin display configuration: \(status)")
        return false
    }

    let configErr = CGConfigureDisplayWithDisplayMode(cfg, displayID, mode, nil)
    guard configErr == .success else {
        CGCancelDisplayConfiguration(cfg)
        log("[display-autoscaler:error] Could not configure display mode: \(configErr)")
        return false
    }

    let commitErr = CGCompleteDisplayConfiguration(cfg, .forSession)
    guard commitErr == .success else {
        log("[display-autoscaler:error] Could not commit display mode for this session: \(commitErr)")
        return false
    }

    let afterDetails = getDisplayDetailsString(displayID: displayID)
    log("[display-autoscaler:info] [AFTER]  Display ID \(displayID): \(afterDetails)")
    return true
}

func configureMirroring(targetDisplayID: CGDirectDisplayID) {
    guard CGDisplayIsInMirrorSet(targetDisplayID) == 0 else {
        log("[display-autoscaler:info] Display \(targetDisplayID) is already in a mirror set.")
        return
    }

    let displayCapacity: UInt32 = 16
    var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCapacity))
    var activeCount: UInt32 = 0
    guard CGGetActiveDisplayList(displayCapacity, &activeDisplays, &activeCount) == .success,
          let masterID = activeDisplays.prefix(Int(activeCount)).first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
        log("[display-autoscaler:warn] Cannot mirror: no active built-in display was found.")
        return
    }

    var configRef: CGDisplayConfigRef?
    let status = CGBeginDisplayConfiguration(&configRef)
    guard status == .success, let cfg = configRef else {
        log("[display-autoscaler:error] Could not begin mirroring configuration: \(status)")
        return
    }

    let mirrorErr = CGConfigureDisplayMirrorOfDisplay(cfg, targetDisplayID, masterID)
    guard mirrorErr == .success else {
        CGCancelDisplayConfiguration(cfg)
        log("[display-autoscaler:error] Could not configure display mirroring: \(mirrorErr)")
        return
    }

    let commitErr = CGCompleteDisplayConfiguration(cfg, .forSession)
    if commitErr == .success {
        log("[display-autoscaler:info] Mirroring enabled for this session. Master ID \(masterID) -> Slave ID \(targetDisplayID)")
    } else {
        log("[display-autoscaler:error] Could not commit mirroring for this session: \(commitErr)")
    }
}

func optimizeAllExternalDisplays() {
    let displayCapacity: UInt32 = 16
    var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCapacity))
    var activeCount: UInt32 = 0
    guard CGGetActiveDisplayList(displayCapacity, &activeDisplays, &activeCount) == .success else {
        log("[display-autoscaler:error] Could not get the active display list.")
        return
    }

    log("[display-autoscaler:info] Active display count: \(activeCount)")
    for (index, displayID) in activeDisplays.prefix(Int(activeCount)).enumerated() {
        let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
        log("[display-autoscaler:info] Active Display [\(index)]: ID=\(displayID), Builtin=\(isBuiltin)")
        if !isBuiltin {
            optimizeDisplaySettings(displayID: displayID)
        }
    }

    writeDesktopDiagnosticReport()
}

let displayCallback: CGDisplayReconfigurationCallBack = { (displayID, flags, userInfo) in
    if flags.contains(.addFlag), CGDisplayIsBuiltin(displayID) == 0 {
        log("[display-autoscaler:info] External display connected. ID: \(displayID)")
        DispatchQueue.main.async {
            optimizeDisplaySettings(displayID: displayID)
            writeDesktopDiagnosticReport()
        }
    }
}

log("[display-autoscaler:info] Starting display agent. Registering callback...")
let context = UnsafeMutableRawPointer(bitPattern: 0)
let callbackStatus = CGDisplayRegisterReconfigurationCallback(displayCallback, context)
guard callbackStatus == .success else {
    log("[display-autoscaler:error] Could not register the display callback: \(callbackStatus)")
    exit(EXIT_FAILURE)
}

// Trigger initial optimization
optimizeAllExternalDisplays()

// Keep the process alive to receive display reconfiguration callbacks.
RunLoop.current.run()
