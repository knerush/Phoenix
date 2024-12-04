import Factory
import Foundation
import GenerateFeatureDataStore
import GenerateFeatureDataStoreContract

extension Container {
    static let generateFeatureDataStore = Factory(Container.shared) {
        GenerateFeatureDataStore(
            dictionaryCache: UserDefaults.standard
        ) as GenerateFeatureDataStoreProtocol
    }.scope(.singleton)
}

extension Container {
    var featureDataStore: Factory<GenerateFeatureDataStoreProtocol> {
        self {
            GenerateFeatureDataStore(
                dictionaryCache: UserDefaults.standard
            ) as GenerateFeatureDataStoreProtocol
        }.scope(.singleton)
    }
}
