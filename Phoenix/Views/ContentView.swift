import Package
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ViewModel = .init()
    @EnvironmentObject private var store: PhoenixDocumentStore
    private let familyFolderNameProvider: FamilyFolderNameProviding = FamilyFolderNameProvider()
    
    var body: some View {
        HSplitView {
            componentsList()

            if let selectedComponentName = viewModel.selectedComponentName,
               let selectedComponent = store.getComponent(withName: selectedComponentName) {
                componentView(for: selectedComponent)
                    .sheet(isPresented: .constant(viewModel.showingDependencyPopover)) {
                        dependencyPopover(component: selectedComponent)
                    }
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("No Component Selected")
                            .font(.title)
                            .padding()
                        Spacer()
                    }
                    Spacer()
                }.frame(minWidth: 750)
            }
        }.sheet(isPresented: .constant(viewModel.showingNewComponentPopup)) {
            newComponentPopover()
        }.sheet(item: .constant(store.getFamily(withName: viewModel.selectedFamilyName ?? ""))) { family in
            familyPopover(family: family)
        }.toolbar {
            //            Button(action: viewModel.onAddAll, label: { Text("Add everything in the universe") })
            Button(action: viewModel.onAddButton) {
                Image(systemName: "plus.circle.fill")
                Text("New Component")
            }.keyboardShortcut("A", modifiers: [.command, .shift])
            Button(action: { viewModel.onGenerate(document: store.document.wrappedValue, withFileURL: store.fileURL) }) {
                Image(systemName: "shippingbox.fill")
                Text("Generate")
            }.keyboardShortcut(.init("R"), modifiers: .command)
        }
    }

    // MARK: - Views
    func componentsList() -> some View {
        ComponentsList(sections: store
            .componentsFamilies
            .map { componentsFamily in
                    .init(name: sectionTitle(forFamily: componentsFamily.family),
                          rows: componentsFamily.components.map { component in
                            .init(name: componentName(component, for: componentsFamily.family),
                                  isSelected: viewModel.selectedComponentName == component.name,
                                  onSelect: { viewModel.selectedComponentName = component.name })
                    },
                          onSelect: { viewModel.selectedFamilyName = componentsFamily.family.name })
            })
        .frame(minWidth: 250)
    }

    func componentView(for component: Component) -> some View {
        ComponentView(
            title: store.title(for: component.name),
            platformsContent: {
                Group {
                    CustomMenu(title: iOSPlatformMenuTitle(forComponent: component),
                               data: IOSVersion.allCases,
                               onSelection: { store.setIOSVersionForComponent(withName: component.name, iOSVersion: $0) },
                               hasRemove: component.iOSVersion != nil,
                               onRemove: { store.removeIOSVersionForComponent(withName: component.name) })
                    .frame(width: 150)
                    CustomMenu(title: macOSPlatformMenuTitle(forComponent: component),
                               data: MacOSVersion.allCases,
                               onSelection: { store.setMacOSVersionForComponent(withName: component.name, macOSVersion: $0) },
                               hasRemove: component.macOSVersion != nil,
                               onRemove: { store.removeMacOSVersionForComponent(withName: component.name) })
                    .frame(width: 150)
                }
            },
            dependencies: component.dependencies.sorted(),
            dependencyView: { dependencyType in
                VStack(spacing: 0) {
                    Divider()
                    switch dependencyType {
                    case let .local(dependency):
                        DependencyView<PackageTargetType, String>(
                            title: store.title(for: dependency.name),
                            onSelection: { viewModel.selectedComponentName = dependency.name },
                            onRemove: { store.removeDependencyForComponent(withComponentName: component.name, componentDependency: dependency) },
                            allTypes: componentTypes(for: dependency, component: component),
                            allSelectionValues: configurationTargetTypes().map { $0.title },
                            onUpdateTargetTypeValue: { store.updateModuleTypeForDependency(withComponentName: component.name, dependency: dependency, type: $0, value: $1) })
                    case let .remote(dependency):
                        RemoteDependencyView(
                            name: dependency.name.name,
                            urlString: dependency.url,
                            allVersionsTypes: [
                                .init(title: "branch", value: ExternalDependencyVersion.branch(name: "main")),
                                .init(title: "from", value: ExternalDependencyVersion.from(version: "1.0.0"))
                            ],
                            onSubmitVersionType: { updateVersion(for: dependency, version: $0) },
                            versionPlaceholder: versionPlaceholder(for: dependency),
                            versionTitle: dependency.version.title,
                            versionText: dependency.version.stringValue,
                            onSubmitVersionText: { store.updateVersionStringValueForRemoteDependency(withComponentName: component.name, dependency: dependency, stringValue: $0) },
                            allDependencyTypes: allDependencyTypes(dependency: dependency, component: component),
                            enabledTypes: enabledDependencyTypes(for: dependency),
                            onUpdateDependencyType: { store.updateModuleTypeForRemoteDependency(withComponentName: component.name, dependency: dependency, type: $0, value: $1) },
                            onRemove: { store.removeRemoteDependencyForComponent(withComponentName: component.name, dependency: dependency) }
                        )
                    }
                }
            },
            allLibraryTypes: LibraryType.allCases,
            allModuleTypes: configurationTargetTypes().map { $0.title },
            isModuleTypeOn: {
                guard let moduleType = ModuleType(rawValue: $0.lowercased()) else { return false }
                return component.modules[moduleType] != nil
            },
            onModuleTypeSwitchedOn: { store.addModuleTypeForComponent(withName: component.name, moduleType: $0) },
            onModuleTypeSwitchedOff: { store.removeModuleTypeForComponent(withName: component.name, moduleType:$0) },
            moduleTypeTitle: { $0 },
            onSelectionOfLibraryTypeForModuleType: { store.set(forComponentWithName: component.name, libraryType: $0, forModuleType: $1) },
            onRemove: {
                guard let name = viewModel.selectedComponentName else { return }
                store.removeComponent(withName: name)
                viewModel.selectedComponentName = nil
            },
            allTargetTypes: allTargetTypes(forComponent: component),
            onRemoveResourceWithId: { store.removeResource(withId: $0, forComponentWithName: component.name) },
            onAddResourceWithName: { store.addResource($0, forComponentWithName: component.name) },
            onShowDependencyPopover: { viewModel.showingDependencyPopover = true },
            resourcesValueBinding: componentResourcesValueBinding(component: component)
        )
        .frame(minWidth: 750)
    }

    func newComponentPopover() -> some View {
        return NewComponentPopover(onSubmit: { name, familyName in
            let name = Name(given: name, family: familyName)
            if name.given.isEmpty {
                return "Given name cannot be empty"
            } else if name.family.isEmpty {
                return "Component must be part of a family"
            } else if store.nameExists(name: name) {
                return "Name already in use"
            } else {
                store.addNewComponent(withName: name)
                viewModel.selectedComponentName = name
                viewModel.showingNewComponentPopup = false
            }
            return nil
        }, onDismiss: {
            viewModel.showingNewComponentPopup = false
        })
    }

    func dependencyPopover(component: Component) -> some View {
        let filteredNames = Dictionary(grouping: store.allNames.filter { name in
            component.name != name && !component.dependencies.contains { componentDependencyType in
                guard case let .local(componentDependency) = componentDependencyType else { return false }
                return componentDependency.name == name
            }
        }, by: { $0.family })
        let sections = filteredNames.reduce(into: [ComponentDependenciesListSection]()) { partialResult, keyValue in
            partialResult.append(ComponentDependenciesListSection(name: keyValue.key,
                                                                  rows: keyValue.value.map { name in
                ComponentDependenciesListRow(name: store.title(for: name),
                                             onSelect: {
                    store.addDependencyToComponent(withName: component.name, dependencyName: name)
                    viewModel.showingDependencyPopover = false
                })
            }))
        }.sorted { lhs, rhs in
            lhs.name < rhs.name
        }
        return ComponentDependenciesPopover(
            sections: sections,
            onExternalSubmit: { remoteDependency in
                let urlString = remoteDependency.urlString

                let name: ExternalDependencyName
                switch remoteDependency.productType {
                case .name:
                    name = .name(remoteDependency.productName)
                case .product:
                    name = .product(name: remoteDependency.productName, package: remoteDependency.productPackage)
                }

                let version: ExternalDependencyVersion
                switch remoteDependency.versionType {
                case .from:
                    version = .from(version: remoteDependency.versionValue)
                case .branch:
                    version = .branch(name: remoteDependency.versionValue)
                }
                store.addRemoteDependencyToComponent(withName: component.name, dependency: RemoteDependency(url: urlString,
                                                                                                            name: name,
                                                                                                            value: version))
                viewModel.showingDependencyPopover = false
            },
            onDismiss: {
                viewModel.showingDependencyPopover = false
            }).frame(minWidth: 900, minHeight: 400)
    }

    func familyPopover(family: Family) -> some View {
        return FamilyPopover(name: family.name,
                             ignoreSuffix: family.ignoreSuffix,
                             onUpdateSelectedFamily: { store.updateFamily(withName: family.name, ignoresSuffix: !$0) },
                             folderName: family.folder ?? "",
                             onUpdateFolderName: { store.updateFamily(withName: family.name, folder: $0) },
                             defaultFolderName: familyFolderNameProvider.folderName(forFamily: family.name),
                             componentNameExample: "Component\(family.ignoreSuffix ? "" : family.name)",
                             onDismiss: { viewModel.selectedFamilyName = nil })
    }

    // MARK: - Private
    
    private func componentName(_ component: Component, for family: Family) -> String {
        family.ignoreSuffix == true ? component.name.given : component.name.given + component.name.family
    }
    
    private func sectionTitle(forFamily family: Family) -> String {
        if let folder = family.folder {
            return folder
        }
        return familyFolderNameProvider.folderName(forFamily: family.name)
    }

    private func iOSPlatformMenuTitle(forComponent component: Component) -> String {
        if let iOSVersion = component.iOSVersion {
            return ".iOS(.\(iOSVersion))"
        } else {
            return "Add iOS"
        }
    }

    private func macOSPlatformMenuTitle(forComponent component: Component) -> String {
        if let macOSVersion = component.macOSVersion {
            return ".macOS(.\(macOSVersion))"
        } else {
            return "Add macOS"
        }
    }

    private func moduleTypeTitle(for moduleType: ModuleType, component: Component) -> String {
        if let libraryType = component.modules[moduleType] {
            return "\(libraryType)"
        } else {
            return "Add Type"
        }
    }

    private func packageTargetType(for targetType: ModuleType?) -> PackageTargetType? {
        switch targetType {
        case .contract:
            return .init(name: "Contract", isTests: false)
        case .implementation:
            return .init(name: "Implementation", isTests: false)
        case .mock:
            return .init(name: "Mock", isTests: false)
        default:
            return nil
        }
    }

    private func componentTypes(for dependency: ComponentDependency, component: Component) -> [IdentifiableWithSubtypeAndSelection<PackageTargetType, String>] {
        let values = configurationTargetTypes().compactMap { targetType -> IdentifiableWithSubtypeAndSelection<PackageTargetType, String>? in
            let selectedValue: PackageTargetType?
            let selectedSubValue: PackageTargetType?
            switch (targetType.value, targetType.subValue) {
            case (PackageTargetType(name: "Contract", isTests: false), nil):
                selectedValue = packageTargetType(for: dependency.contract)
                selectedSubValue = nil
            case (PackageTargetType(name: "Implementation", isTests: false), PackageTargetType(name: "Implementation", isTests: true)):
                selectedValue = packageTargetType(for: dependency.implementation)
                selectedSubValue = packageTargetType(for: dependency.tests)
            case (PackageTargetType(name: "Mock", isTests: false), nil):
                selectedValue = packageTargetType(for: dependency.mock)
                selectedSubValue = nil
            default:
                return nil
            }

            return IdentifiableWithSubtypeAndSelection<PackageTargetType, String>(
                title: targetType.title,
                subtitle: targetType.subtitle,
                value: targetType.value,
                subValue: targetType.subValue,
                selectedValue: selectedValue?.name,
                selectedSubValue: selectedSubValue?.name)
        }

        return values.filter { value in
            component.modules.keys.contains { moduleType in
                switch (moduleType, value.title) {
                case (.contract, "Contract"),
                    (.implementation, "Implementation"),
                    (.mock, "Mock"):
                    return true
                default:
                    return false
                }
            }
        }
    }

    private func updateVersion(for dependency: RemoteDependency, version: ExternalDependencyVersion) {
        guard let name = viewModel.selectedComponentName else { return }
        store.updateVersionForRemoteDependency(withComponentName: name, dependency: dependency, version: version)
    }

    private func versionPlaceholder(for dependency: RemoteDependency) -> String {
        switch dependency.version {
        case .from:
            return "1.0.0"
        case .branch:
            return "main"
        }
    }

    private func dependencyTypes(for dependency: RemoteDependency, component: Component) -> [PackageTargetType] {
        component.modules.keys.sorted().reduce(into: [PackageTargetType](), { partialResult, moduleType in
            switch moduleType {
            case .contract:
                partialResult.append(PackageTargetType(name: "Contract", isTests: false))
            case .implementation:
                partialResult.append(PackageTargetType(name: "Implementation", isTests: false))
                partialResult.append(PackageTargetType(name: "Tests", isTests: true))
            case .mock:
                partialResult.append(PackageTargetType(name: "Mock", isTests: false))
            }
        })
    }

    private func enabledDependencyTypes(for dependency: RemoteDependency) -> [PackageTargetType] {
        dependency.targetTypes
    }

    private func componentResourcesValueBinding(component: Component) -> Binding<[DynamicTextFieldList<TargetResources.ResourcesType,
                                                                                  PackageTargetType>.ValueContainer]> {
        Binding(get: {
            component.resources.map { resource -> DynamicTextFieldList<TargetResources.ResourcesType,
                                                                       PackageTargetType>.ValueContainer in

                let targetTypes = resource.targets.map { target -> PackageTargetType in
                    switch target {
                    case .contract:
                        return .init(name: "Contract", isTests: false)
                    case .implementation:
                        return .init(name: "Implementation", isTests: false)
                    case .tests:
                        return .init(name: "Implementation", isTests: true)
                    case .mock:
                        return .init(name: "Mock", isTests: false)
                    }
                }

                return .init(id: resource.id,
                             value: resource.folderName,
                             menuOption: resource.type,
                             targetTypes: targetTypes)
            }
        }, set: { store.updateResource($0.map {
            let targets = $0.targetTypes.compactMap { packageTargetType -> TargetType? in
                switch (packageTargetType.name, packageTargetType.isTests) {
                case ("Contract", false):
                    return TargetType.contract
                case ("Implementation", false):
                    return TargetType.implementation
                case ("Implementation", true):
                    return TargetType.tests
                case ("Mock", false):
                    return TargetType.mock
                default:
                    return nil
                }

            }
            return ComponentResources(id: $0.id, folderName: $0.value, type: $0.menuOption, targets: targets) }, forComponentWithName: component.name)
        })
    }

    private func allTargetTypes(forComponent component: Component) -> [IdentifiableWithSubtype<PackageTargetType>] {
        configurationTargetTypes().filter { target in
            component.modules.keys.contains(where: { $0.rawValue.lowercased() == target.value.name.lowercased() })
        }
    }

    private func allDependencyTypes(dependency: RemoteDependency, component: Component) -> [IdentifiableWithSubtype<PackageTargetType>] {
        configurationTargetTypes().filter { allType in
            dependencyTypes(for: dependency, component: component).contains(where: { allType.value.id == $0.id })
        }
    }

    private func configurationTargetTypes() -> [IdentifiableWithSubtype<PackageTargetType>] {
        store.document.wrappedValue.projectConfiguration.packageConfigurations.map { packageConfiguration in
            IdentifiableWithSubtype(title: packageConfiguration.name,
                                    subtitle: packageConfiguration.hasTests ? "Tests" : nil,
                                    value: PackageTargetType(name: packageConfiguration.name, isTests: false),
                                    subValue: packageConfiguration.hasTests ? PackageTargetType(name: packageConfiguration.name, isTests: true) : nil)
        }
    }
}
