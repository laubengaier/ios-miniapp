import Quick
import Nimble
@testable import MiniApp

// swiftlint:disable function_body_length
class MiniAppStorageTests: QuickSpec {

    override func spec() {
        describe("mini app storage") {
            context("when there is an error cleaning storage") {
                it("it won't crash") {
                    let storage = MiniAppStorage()
                    storage.cleanVersions(for: "test", differentFrom: "test", status: MiniAppStatus())
                }
            }
            context("when there is an error saving in storage") {
                it("it won't crash and return an error") {
                    let storage = MiniAppStorage()
                    let url = MockFile.createTestFile(fileName: "tmp")
                    try? FileManager.default.removeItem(at: url!)
                    let error = storage.save(sourcePath: url!, destinationPath: url!)
                    expect(error).toNot(beNil())
                }
            }
        }

        describe("miniapp secure storage") {

            context("when miniapp directory exists") {

                let miniAppId = "test-1234"
                beforeEach {
                    try? MiniAppSecureStorage.clearSecureStorage(for: miniAppId)
                    let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    let miniAppPath = cachePath.appendingPathComponent("/MiniApp").appendingPathComponent("/\(miniAppId)")
                    try? FileManager.default.createDirectory(at: miniAppPath, withIntermediateDirectories: true, attributes: nil)
                }

                it("will load the storage") {
                    let storage = MiniAppSecureStorage(appId: miniAppId)
                    var didLoadStorage = false
                    storage.loadStorage { success in
                        didLoadStorage = success
                    }
                    expect(didLoadStorage).toEventually(beTrue())
                }

                it("will unload the storage") {
                    let storage = MiniAppSecureStorage(appId: miniAppId)
                    var didLoadStorage = false
                    storage.loadStorage { success in
                        didLoadStorage = success
                        storage.set(dict: ["test1": "test1Value"]) { result in
                            switch result {
                            case .success:
                                storage.unloadStorage()
                                let test1 = try? storage.get(key: "test1")
                                expect(test1).to(beNil())
                            case let .failure(error):
                                fail(error.localizedDescription)
                            }
                        }
                    }
                    expect(didLoadStorage).toEventually(beTrue())
                }

                it("will load the storage and set some values") {
                    let storage = MiniAppSecureStorage(appId: miniAppId)
                    var didLoadStorage = false
                    storage.loadStorage { success in
                        didLoadStorage = success
                        storage.set(dict: ["test1": "test1Value", "test2": "test2Value", "test3": "test3Value"]) { result in
                            switch result {
                            case .success:
                                let test1 = try? storage.get(key: "test1")
                                expect(test1).to(equal("test1Value"))
                                let test2 = try? storage.get(key: "test2")
                                expect(test2).to(equal("test2Value"))
                                let test3 = try? storage.get(key: "test3")
                                expect(test3).to(equal("test3Value"))
                            case let .failure(error):
                                fail(error.localizedDescription)
                            }
                        }
                    }
                    expect(didLoadStorage).toEventually(beTrue())
                }

                it("will load the storage and add then remove some values") {
                    let storage = MiniAppSecureStorage(appId: miniAppId)
                    var didLoadStorage = false
                    storage.loadStorage { success in
                        didLoadStorage = success
                        storage.set(dict: ["test1": "test1Value", "test2": "test2Value"]) { result in
                            switch result {
                            case .success:
                                storage.remove(keys: ["test1", "test2"], completion: { removeResult in
                                    switch removeResult {
                                    case .success:
                                        let test1 = try? storage.get(key: "test1")
                                        expect(test1).to(beNil())
                                        let test2 = try? storage.get(key: "test2")
                                        expect(test2).to(beNil())
                                    case let .failure(error):
                                        fail(error.localizedDescription)
                                    }
                                })
                            case let .failure(error):
                                fail(error.localizedDescription)
                            }
                        }
                    }
                    expect(didLoadStorage).toEventually(beTrue())
                }

                it("will block operations when busy") {
                    let storage = MiniAppSecureStorage(appId: miniAppId)
                    var didLoadStorage = false
                    storage.loadStorage { success in
                        didLoadStorage = success
                        storage.set(dict: ["test1": "test1Value"]) { result in
                            switch result {
                            case .success: ()
                            case let .failure(error): fail(error.localizedDescription)
                            }
                        }
                        expect(storage.isBusy).to(beTrue())
                        storage.set(dict: ["test1": "test1Value"]) { result in
                            switch result {
                            case .success:
                                fail("second operation should fail")
                            case let .failure(error):
                                expect(error).to(equal(MiniAppSecureStorageError.storageBusyProcessing))
                            }
                        }
                    }
                    expect(didLoadStorage).toEventually(beTrue())
                }

                it("will clear secure storage for miniapp") {
                    let secureStorageUrl = FileManager.getMiniAppDirectory(with: miniAppId).appendingPathComponent("/securestorage.plist")
                    try? MiniAppSecureStorage.clearSecureStorage(for: miniAppId)
                    expect(FileManager.default.fileExists(atPath: secureStorageUrl.path)).to(beFalse())
                }

                it("will calculate size for an empty storage") {
                    let storage = MiniAppSecureStorage(appId: miniAppId)
                    do {
                        let fileSize: UInt64 = try storage.size()
                        expect(fileSize).to(equal(42))
                    } catch {
                        fail("could not get fileSize")
                    }
                }
            }
        }
    }
}
