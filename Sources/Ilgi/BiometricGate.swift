import Foundation
import LocalAuthentication

enum BiometricGate {
    /// Touch ID(없으면 로그인 암호)로 인증한다. completion은 메인 스레드에서 호출.
    static func unlock(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "취소"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // 암호조차 설정되지 않은 기기에서는 잠금이 불가능하므로 통과시킨다
            DispatchQueue.main.async { completion(true) }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}
