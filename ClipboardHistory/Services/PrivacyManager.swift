import Foundation
import CryptoKit
import LocalAuthentication
import Security

/// 隐私管理器 — AES-GCM 加解密 + Keychain 密钥管理 + Touch ID 验证
final class PrivacyManager {
    static let shared = PrivacyManager()

    private var encryptionKey: SymmetricKey?

    /// Keychain 中存储密钥的标识符
    private let keychainTag = "com.clipboardhistory.encryptionKey"

    // MARK: - 初始化

    func setup() {
        // 尝试从 Keychain 读取已有密钥
        if let existingKey = loadKeyFromKeychain() {
            encryptionKey = existingKey
            print("🔑 已加载加密密钥")
        } else {
            // 生成新密钥并存储
            let newKey = SymmetricKey(size: .bits256)
            saveKeyToKeychain(newKey)
            encryptionKey = newKey
            print("🔑 已生成新的加密密钥")
        }
    }

    // MARK: - 加解密

    /// 加密明文字符串，返回加密数据（含 nonce 和 tag）
    func encrypt(_ plaintext: String) -> Data? {
        guard let key = encryptionKey,
              let plainData = plaintext.data(using: .utf8) else {
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(plainData, using: key)
            return sealedBox.combined
        } catch {
            print("❌ 加密失败: \(error)")
            return nil
        }
    }

    /// 解密数据，返回明文字符串
    func decrypt(_ combinedData: Data) -> String? {
        guard let key = encryptionKey else { return nil }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("❌ 解密失败: \(error)")
            return nil
        }
    }

    // MARK: - Touch ID / 密码验证

    /// 请求系统级生物识别或密码验证
    func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("❌ 设备不支持认证: \(error?.localizedDescription ?? "未知错误")")
            completion(false)
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "验证以查看来自黑名单应用的剪贴板内容"
        ) { success, authError in
            DispatchQueue.main.async {
                if success {
                    print("✅ 用户验证通过")
                    completion(true)
                } else {
                    print("❌ 用户验证失败: \(authError?.localizedDescription ?? "未知错误")")
                    completion(false)
                }
            }
        }
    }

    // MARK: - Keychain 操作

    private func saveKeyToKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }

        // 先删除旧密钥（如果存在）
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainTag,
            kSecAttrService as String: keychainTag,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 添加新密钥
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainTag,
            kSecAttrService as String: keychainTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("❌ Keychain 存储失败: \(status)")
        }
    }

    private func loadKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainTag,
            kSecAttrService as String: keychainTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let keyData = item as? Data else {
            return nil
        }

        return SymmetricKey(data: keyData)
    }
}
