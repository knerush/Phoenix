import SwiftUI
import GenerateFeatureDataStoreContract
import PhoenixDocument
import UniformTypeIdentifiers
import Factory

class CustomScriptViewModel: ObservableObject {
    
    @Injected(\.featureDataStore) private var dataStore: GenerateFeatureDataStoreProtocol
    
    var selectedFilePath: String {
        get {
            $configuration.customScriptPath.wrappedValue ?? "no file selected"
        }
        set {
            configuration.customScriptPath = getRelativePath(for: newValue)
        }
    }
    var rootURL: URL?
    
    @Binding var configuration: ProjectConfiguration

    init(configuration: Binding<ProjectConfiguration>, rootURL: URL?) {
        self._configuration = configuration
        self.rootURL = rootURL
    }
    
    private func getRelativePath(for fullPath: String) -> String? {
        guard let rootURL = rootURL,
              let mainFolderPath = dataStore.getModulesFolderURL(forFileURL: rootURL),
              let selectedFilePath = URL(string: fullPath) else { return nil }
        
        let selectedComponents = selectedFilePath.pathComponents
        let mainComponents = mainFolderPath.pathComponents

        if selectedComponents.starts(with: mainComponents) {
            let relativeComponents = selectedComponents.dropFirst(mainComponents.count)
            let relativePath = relativeComponents.joined(separator: "/")
            return relativePath
        } else {
            print("Script file should be under Modules folder")
            return nil
        }
    }
}
