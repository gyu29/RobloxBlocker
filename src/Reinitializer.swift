import Cocoa
import Foundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        monitorRobloxTerminator()
    }

    func monitorRobloxTerminator() {
        while true {
            if !isProcessRunning(processName: "RobloxTerminator") {
                startRobloxTerminator()
            }
            sleep(5)
        }
    }

    func isProcessRunning(processName: String) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-f", processName]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        let handle = pipe.fileHandleForReading
        task.launch()
        
        let data = handle.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return !output.isEmpty
        }
        return false
    }

    func startRobloxTerminator() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["/Applications/RobloxTerminator.app"]
        task.launch()
    }
}
