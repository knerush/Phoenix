import Package
import SwiftUI

class ViewModel: ObservableObject {
    // MARK: - Selection
    @Published var selectedComponentName: Name? = nil
    @Published var selectedFamilyName: String? = nil

    // MARK: - Popovers
    @Published var showingConfigurationPopup: Bool = false
    @Published var showingNewComponentPopup: Bool = false
    @Published var showingDependencyPopover: Bool = false
    @Published var fileErrorString: String? = nil

    func update(value: String) {
        print("Value: \(value)")
    }

    func onConfigurationButton() {
        showingConfigurationPopup = true
    }

    func onAddButton() {
        showingNewComponentPopup = true
    }

    func onDuplicate(component: Component) {
        
    }

    func onAddAll(document: inout PhoenixDocument) {
        var componentsFamilies = document.families
        for familyIndex in 0..<10 {
            let familyName = "Family\(familyIndex)"
            var family = ComponentsFamily(family: Family(name: familyName,
                                                         ignoreSuffix: false,
                                                         folder: nil),
                                          components: [])
            for componentIndex in 0..<20 {
                family.components.append(Component(name: Name(given: "Component\(componentIndex)", family: familyName),
                                                   iOSVersion: nil,
                                                   macOSVersion: nil,
                                                   modules: document.projectConfiguration.packageConfigurations.reduce(into: [String: LibraryType](), { partialResult, packageConfiguration in
                    partialResult[packageConfiguration.name] = .undefined
                }),
                                                   dependencies: [],
                                                   resources: []))
            }
            componentsFamilies.append(family)
        }
        document.families = componentsFamilies
    }

    func onGenerate(document: PhoenixDocument, withFileURL fileURL: URL?) {
        guard let fileURL = fileURL else {
            fileErrorString = "File must be saved before packages can be generated."
            return
        }

        let componentExtractor = ComponentExtractor()
        let allFamilies: [Family] = document.families.map { $0.family }
        let packagesWithPath: [PackageWithPath] = document.families.flatMap { componentFamily -> [PackageWithPath] in
            let family = componentFamily.family
            return componentFamily.components.flatMap { (component: Component) -> [PackageWithPath] in
                componentExtractor.packages(for: component,
                                            of: family,
                                            allFamilies: allFamilies,
                                            projectConfiguration: document.projectConfiguration)
            }
        }

        let packagesGenerator = PackageGenerator()
        for packageWithPath in packagesWithPath {
            let url = fileURL.deletingLastPathComponent().appendingPathComponent(packageWithPath.path, isDirectory: true)
            try? packagesGenerator.generate(package: packageWithPath.package, at: url)
        }
    }
}
