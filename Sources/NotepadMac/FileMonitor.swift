import Darwin
import Foundation

@MainActor
final class FileMonitor {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url.standardizedFileURL
        self.onChange = onChange
    }

    func start() {
        stop()

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let nextSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.attrib, .delete, .extend, .rename, .write],
            queue: .main
        )
        nextSource.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.onChange()
            }
        }
        nextSource.setCancelHandler {
            close(descriptor)
        }
        source = nextSource
        nextSource.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        source?.cancel()
    }
}
