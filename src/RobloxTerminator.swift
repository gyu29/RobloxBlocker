import Cocoa
import Network

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var shouldTerminateRoblox = true
    private let terminationQueue = DispatchQueue(label: "com.robloxTerminator.queue")
    private var server: Server?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        startServer()
        terminationQueue.async {
            self.monitorRobloxProcesses()
        }
    }

    private func startServer() {
        server = Server()
        server?.start { [weak self] command in
            self?.handleCommand(command)
        }
    }

    private func handleCommand(_ command: String) {
        switch command {
        case "disable":
            shouldTerminateRoblox = false
        case "enable":
            shouldTerminateRoblox = true
        default:
            print("Unknown command: \(command)")
        }
    }

    private func monitorRobloxProcesses() {
        while true {
            if shouldTerminateRoblox {
                terminateRoblox()
            }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    private func terminateRoblox() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "Roblox"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let pids = output.split(separator: "\n")
                for pid in pids {
                    terminateProcess(pid: String(pid))
                }
            }
        } catch {
            print("Error finding Roblox processes: \(error)")
        }
    }

    private func terminateProcess(pid: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/kill")
        task.arguments = ["-9", pid]
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                print("Successfully terminated process with PID: \(pid)")
            } else {
                print("Failed to terminate process with PID: \(pid)")
            }
        } catch {
            print("Error terminating process with PID \(pid): \(error)")
        }
    }
}

class Server {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let serverQueue = DispatchQueue(label: "com.robloxTerminator.serverQueue")
    private var commandHandler: ((String) -> Void)?

    func start(commandHandler: @escaping (String) -> Void) {
        self.commandHandler = commandHandler
        
        let parameters = NWParameters.tcp
        listener = try? NWListener(using: parameters, on: 5080)
        
        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Server is ready on port 5080")
            case .failed(let error):
                print("Server failure: \(error)")
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
        
        listener?.start(queue: serverQueue)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receive(on: connection)
            case .failed(let error):
                print("Connection failed: \(error)")
                self?.connectionDidEnd(connection)
            case .cancelled:
                self?.connectionDidEnd(connection)
            default:
                break
            }
        }
        connection.start(queue: serverQueue)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                if let message = String(data: data, encoding: .utf8) {
                    let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.commandHandler?(trimmedMessage)
                }
            }
            if isComplete {
                self?.connectionDidEnd(connection)
            } else if error == nil {
                self?.receive(on: connection)
            }
        }
    }

    private func connectionDidEnd(_ connection: NWConnection) {
        if let index = connections.firstIndex(where: { $0 === connection }) {
            connections.remove(at: index)
        }
        connection.cancel()
    }
}
