import Foundation
import LocalAuthentication

enum BiometricGate {
    /// Authenticates with Touch ID (or the login password). completion is called on the main thread.
    static func unlock(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "취소"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // A device without even a password can't lock, so allow through
            DispatchQueue.main.async { completion(true) }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}
