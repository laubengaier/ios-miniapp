import Foundation
import CryptoKit

public protocol MiniAppSecureStorageDelegate: AnyObject {
    /// retrieve a value from the storage
    func get(key: String) throws -> String?

    /// add a key/value set and save it to the disk
    func set(dict: [String: String], completion: ((Result<Bool, MiniAppSecureStorageError>) -> Void)?)

    /// remove a set of keys from the storage and save it to disk
    func remove(keys: [String], completion: ((Result<Bool, MiniAppSecureStorageError>) -> Void)?)

    /// retrieve the storage size in bytes
    func size() -> MiniAppSecureStorageSize

    /// clears the current storage
    func clearSecureStorage() throws
}

public class MiniAppSecureStorage: MiniAppSecureStorageDelegate {

    let appId: String

    /// file size defined in bytes
    var fileSizeLimit: UInt64 = 2_000_000

    private var storage: [String: String]?
    private var isStoreLoading: Bool = false
    var isBusy: Bool = false

    private static let storageName: String = "securestorage"
    static var storageFullName: String { return storageName + ".plist" }

    public init(appId: String) {
        self.appId = appId
        try? setup(appId: appId)
    }

    private func setup(appId: String) throws {
        let secureStoragePath = MiniAppSecureStorage.storagePath(appId: appId)
        MiniAppLogger.d("🔑 Secure Storage: \(secureStoragePath)")
        guard
            !FileManager.default.fileExists(atPath: secureStoragePath.path)
        else {
            MiniAppLogger.d("🔑 Secure Storage: store exists")
            return
        }
        MiniAppLogger.d("🔑 Secure Storage: store does not exist")
        MiniAppLogger.d("🔑 Secure Storage: write to disk")
        let secureStorage: [String: String] = [:]
        let secureStorageData = try PropertyListEncoder().encode(secureStorage)
        try secureStorageData.write(to: secureStoragePath, options: .completeFileProtectionUnlessOpen)
    }

    // MARK: - Load/Unload
    public func loadStorage(completion: ((Bool) -> Void)? = nil) {
        isStoreLoading = true
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            let loadedStorage = FileManager.default.retrievePlist(
                MiniAppSecureStorage.storageFullName,
                from: MiniAppSecureStorage.miniAppPath(appId: strongSelf.appId),
                as: [String: String].self
            )
            DispatchQueue.main.async {
                strongSelf.isStoreLoading = false
                strongSelf.storage = loadedStorage
                completion?(loadedStorage != nil)
            }
        }
    }

    func unloadStorage() {
        self.storage = nil
    }

    // MARK: - Actions
    public func get(key: String) throws -> String? {
        guard let storage = storage else { throw MiniAppSecureStorageError.storageNotExistent }
        MiniAppLogger.d("🔑 Secure Storage: get '\(key)'")
        return storage[key]
    }

    public func set(dict: [String: String], completion: ((Result<Bool, MiniAppSecureStorageError>) -> Void)? = nil) {
        guard storageFileSize <= fileSizeLimit else {
            completion?(.failure(MiniAppSecureStorageError.storageSizeExceeded))
            return
        }
        guard storage != nil else {
            completion?(.failure(MiniAppSecureStorageError.storageNotExistent))
            return
        }
        guard !isBusy else {
            completion?(.failure(MiniAppSecureStorageError.storageBusyProcessing))
            return
        }
        isBusy = true
        for (key, value) in dict {
            MiniAppLogger.d("🔑 Secure Storage: set '\(key)'")
            storage?[key] = value
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            do {
                try strongSelf.saveStoreToDisk()
            } catch let error {
                strongSelf.isBusy = false
                if let error = error as? MiniAppSecureStorageError {
                    completion?(.failure(error))
                } else {
                    completion?(.failure(.unknown(description: error.localizedDescription)))
                }
                return
            }
            DispatchQueue.main.async {
                strongSelf.isBusy = false
                completion?(.success(true))
                MiniAppLogger.d("🔑 Secure Storage: set finish")
            }
        }
    }

    public func remove(keys: [String], completion: ((Result<Bool, MiniAppSecureStorageError>) -> Void)? = nil) {
        guard storage != nil else {
            completion?(.failure(MiniAppSecureStorageError.storageNotExistent))
            return
        }
        guard !isBusy else {
            completion?(.failure(MiniAppSecureStorageError.storageBusyProcessing))
            return
        }
        isBusy = true
        for key in keys {
            MiniAppLogger.d("🔑 Secure Storage: remove '\(key)'")
            storage?.removeValue(forKey: key)
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            do {
                try strongSelf.saveStoreToDisk()
            } catch let error {
                strongSelf.isBusy = false
                if let error = error as? MiniAppSecureStorageError {
                    completion?(.failure(error))
                } else {
                    completion?(.failure(.unknown(description: error.localizedDescription)))
                }
                return
            }
            DispatchQueue.main.async {
                strongSelf.isBusy = false
                completion?(.success(true))
            }
        }
    }

    // MARK: - Internal
    private func loadLocalStorage() -> [String: String]? {
        let secureStoragePath = MiniAppSecureStorage.miniAppPath(appId: appId)
        let secureStorageName = MiniAppSecureStorage.storageName + ".plist"
        let loadedStorage = FileManager.default.retrievePlist(secureStorageName, from: secureStoragePath, as: [String: String].self)
        return loadedStorage
    }

    private static func miniAppPath(appId: String) -> URL {
        return FileManager.getMiniAppDirectory(with: appId)
    }

    private static func storagePath(appId: String) -> URL {
        return FileManager.getMiniAppDirectory(with: appId).appendingPathComponent("/\(storageName).plist")
    }

    private func saveStoreToDisk(completion: (() -> Void)? = nil) throws {
        guard let storage = storage else { throw MiniAppSecureStorageError.storageNotExistent }
        MiniAppLogger.d("🔑 Secure Storage: write store to disk")
        let secureStoragePath = MiniAppSecureStorage.storagePath(appId: appId)
        let secureStorageData = try PropertyListEncoder().encode(storage)
        try secureStorageData.write(to: secureStoragePath, options: .completeFileProtectionUnlessOpen)
        MiniAppLogger.d("🔑 Secure Storage: write store to disk completed")
    }

    // MARK: - Clear
    public static func wipeSecureStorages() throws {
        MiniAppLogger.d("🔑 Secure Storage: destroy")
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let miniAppPath = cachePath.appendingPathComponent("/MiniApp/")
        guard let contentNames = try? FileManager.default.contentsOfDirectory(atPath: miniAppPath.path) else { return }
        for name in contentNames {
            let url = miniAppPath.appendingPathComponent("/" + name)
            if let isDirectory = (try url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory, isDirectory {
                do {
                    try FileManager.default.removeItem(at: url.appendingPathComponent("/" + storageFullName))
                    MiniAppLogger.d("🔑 Secure Storage: destroyed storaged for \(name)")
                } catch {
                    MiniAppLogger.d("🔑 Secure Storage: could not destroy storaged for \(name)")
                }
            } else {
                MiniAppLogger.d("🔑 Secure Storage: ignored \(name)")
            }
        }
    }

    public func clearSecureStorage() throws {
        MiniAppLogger.d("🔑 Secure Storage: destroy")
        try FileManager.default.removeItem(at: MiniAppSecureStorage.storagePath(appId: appId))
    }

    // MARK: - Size
    var storageFileSize: UInt64 {
        let fileSize = MiniAppSecureStorage.storagePath(appId: appId).fileSize
        MiniAppLogger.d("🔑 Secure Storage: size -> \(fileSize)")
        return fileSize
    }

    public func size() -> MiniAppSecureStorageSize {
        return MiniAppSecureStorageSize(used: storageFileSize, max: fileSizeLimit)
    }

    public static func storageSize(for miniAppId: String) throws -> UInt64 {
        let fileSize = MiniAppSecureStorage.storagePath(appId: miniAppId).fileSize
        guard fileSize > 0 else { throw MiniAppSecureStorageError.storageFileEmpty }
        MiniAppLogger.d("🔑 Secure Storage: size -> \(fileSize)")
        return fileSize
    }
}

public struct MiniAppSecureStorageSize: Codable {
    let used: UInt64
    let max: UInt64
}

public enum MiniAppSecureStorageError: Error, MiniAppErrorProtocol, Equatable {
    case unknown(description: String)
    case storageNotExistent
    case storageFileEmpty
    case storageBusyProcessing
    case storageKeyNotFound
    case storageSizeExceeded

    var name: String {
        switch self {
        case .unknown:
            return "unknown"
        case .storageNotExistent:
            return "storageNotExistent"
        case .storageFileEmpty:
            return "storageFileEmpty"
        case .storageBusyProcessing:
            return "storageBusyProcessing"
        case .storageKeyNotFound:
            return "storageKeyNotFound"
        case .storageSizeExceeded:
            return "storageSizeExceeded"
        }
    }

    var description: String {
        switch self {
        case .unknown(let description):
            return description
        case .storageNotExistent:
            return "Storage does not exist"
        case .storageFileEmpty:
            return "Storage file is empty"
        case .storageBusyProcessing:
            return "Storage busy processing"
        case .storageKeyNotFound:
            return "Storage key not available"
        case .storageSizeExceeded:
            return "Storage size was exceeded"
        }
    }
}
