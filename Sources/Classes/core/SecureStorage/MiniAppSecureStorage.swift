import Foundation
import CryptoKit

public class MiniAppSecureStorage: MiniAppSecureStorageDelegate {

    /// miniapp id related to the store
    let appId: String

    /// file size defined in bytes
    var fileSizeLimit: UInt64

    /// state if the storage is currently loading
    var isStoreLoading: Bool = false

    /// storage is busy with set, remove etc
    var isBusy: Bool = false

    static var storageName: String { return "securestorage" }

    let database: MiniAppSecureStorageDatabase

    public init(
        appId: String,
        storageMaxSizeInBytes: UInt64? = nil,
        database: MiniAppSecureStorageDatabase? = nil
    ) {
        self.appId = appId
        self.fileSizeLimit = storageMaxSizeInBytes ?? 2_000_000
        self.database = database ?? MiniAppSecureStorageSqliteDatabase(appId: appId)
    }

    deinit {
        MiniAppLogger.d("🔑 Secure Storage: deinit")
    }

    // MARK: - Load/Unload
    public func loadStorage(completion: ((Bool) -> Void)? = nil) {
        isStoreLoading = true
        database.load(completion: { [weak self] error in
            self?.isStoreLoading = false
            guard error == nil else {
                completion?(false)
                return
            }
            completion?(true)
        })
    }

    func unloadStorage() {
        try? database.unload()
    }

    // MARK: - Actions
    func get(key: String) throws -> String? {
        return try database.get(key: key)
    }

    func set(dict: [String: String], completion: ((Result<Bool, MiniAppSecureStorageError>) -> Void)? = nil) {
        guard (try? getInMemoryStorageFileSize(dict: dict)) != nil else {
            completion?(.failure(.storageUnvailable))
            return
        }
        guard database.isStoreAvailable else {
            completion?(.failure(.storageUnvailable))
            return
        }
        guard !isBusy else {
            completion?(.failure(.storageBusy))
            return
        }

        do {
            try validateAvailableSpace(for: dict)
            MiniAppLogger.d("🔑 Secure Storage: sufficient space for insert available")
        } catch let error {
            let storageError = error as? MiniAppSecureStorageError
            completion?(.failure(storageError ?? .storageIOError))
            return
        }

        isBusy = true

        do {
            try database.set(dict: dict)
            try database.save(completion: { [weak self] result in
                switch result {
                case .success:
                    self?.isBusy = false
                    completion?(.success(true))
                case let .failure(error):
                    self?.isBusy = false
                    completion?(.failure(error))
                }
            })
        } catch {
            isBusy = false
            completion?(.failure(.storageIOError))
            return
        }
    }

    func remove(keys: [String], completion: ((Result<Bool, MiniAppSecureStorageError>) -> Void)? = nil) {
        guard database.isStoreAvailable else {
            completion?(.failure(MiniAppSecureStorageError.storageUnvailable))
            return
        }
        guard !isBusy else {
            completion?(.failure(MiniAppSecureStorageError.storageBusy))
            return
        }

        isBusy = true

        do {
            try database.remove(keys: keys)
            try database.save(completion: { [weak self] result in
                switch result {
                case .success:
                    self?.isBusy = false
                    completion?(.success(true))
                case let .failure(error):
                    self?.isBusy = false
                    completion?(.failure(error))
                }
            })
        } catch let error {
            isBusy = false
            completion?(.failure((error as? MiniAppSecureStorageError) ?? .storageIOError))
        }
    }

    // MARK: - Wipe
    // MARK: Wipe all secure storages
    internal static func wipeSecureStorages() {
        MiniAppLogger.d("🔑 Secure Storage: destroy")
        MiniAppSecureStorageSqliteDatabase.wipe()
        MiniAppSecureStoragePlistDatabase.wipe()
    }

    // MARK: Wipe storage for MiniApp ID
    internal static func wipeSecureStorage(for miniAppId: String) {
        MiniAppSecureStorageSqliteDatabase.wipe(for: miniAppId)
        MiniAppSecureStoragePlistDatabase.wipe(for: miniAppId)
    }

    func clearSecureStorage() throws {
        database.clear { result in
            switch result {
            case .success:
                MiniAppLogger.d("🔑 Secure Storage: cleared")
            case .failure:
                MiniAppLogger.d("🔑 Secure Storage: clear failed")
            }
        }
    }

    // MARK: - Size
    func size() -> MiniAppSecureStorageSize {
        return MiniAppSecureStorageSize(used: database.storageFileSize, max: fileSizeLimit)
    }
}

// MARK: - Space
extension MiniAppSecureStorage {
    func getInMemoryStorageFileSize(dict: [String: String]) throws -> UInt64 {
        guard
            let storageSize = try? PropertyListEncoder().encode(dict)
        else {
            throw MiniAppSecureStorageError.storageUnvailable
        }
        let size = storageSize.count
        MiniAppLogger.d("🔑 Secure Storage: memory size -> \(size)")
        return UInt64(size)
    }

    func validateAvailableSpace(for dict: [String: String]) throws {
        guard
            let dictData = try? PropertyListEncoder().encode(dict),
            let memorySize = try? getInMemoryStorageFileSize(dict: dict)
        else {
            throw MiniAppSecureStorageError.storageIOError
        }
        let estimatedAddSize = UInt64(dictData.count)
        let estimatedFinalSize = memorySize + estimatedAddSize
        guard estimatedFinalSize <= fileSizeLimit else {
            throw MiniAppSecureStorageError.storageFullError
        }
    }
}

// MARK: - Notifications
extension MiniAppSecureStorage {
    static func sendLoadStorageReady() {
        NotificationCenter.default.sendCustomEvent(
            MiniAppEvent.Event(type: .secureStorageReady, comment: "MiniApp Secure Storage Ready")
        )
    }

    static func sendLoadStorageError() {
        NotificationCenter.default.sendCustomEvent(
            MiniAppEvent.Event(type: .secureStorageError, comment: "MiniApp Secure Storage Error")
        )
    }
}
