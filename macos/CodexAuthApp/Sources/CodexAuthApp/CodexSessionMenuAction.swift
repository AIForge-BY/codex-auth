import Foundation

@MainActor
struct CodexSessionMenuAction {
    let closeMenu: @MainActor () -> Void
    let chooseDirectory: @MainActor (@escaping @MainActor (String?) -> Void) -> Void
    let openSession: @MainActor (String) -> Void

    func run() {
        closeMenu()
        chooseDirectory { directoryPath in
            guard let directoryPath else {
                return
            }
            openSession(directoryPath)
        }
    }
}
