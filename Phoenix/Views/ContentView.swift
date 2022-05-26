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
                        DependencyView<TargetType, ModuleType>(
                            title: store.title(for: dependency.name),
                            onSelection: { viewModel.selectedComponentName = dependency.name },
                            onRemove: { store.removeDependencyForComponent(withComponentName: component.name, componentDependency: dependency) },
                            allTypes: componentTypes(for: dependency, component: component),
                            allSelectionValues: Array(ModuleType.allCases),
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
                            allDependencyTypes: [
                                .init(title: "Contract", subtitle: nil, value: TargetType.contract, subValue: nil),
                                .init(title: "Implementation", subtitle: "Tests", value: TargetType.implementation, subValue: .tests),
                                .init(title: "Mock", subtitle: nil, value: TargetType.mock, subValue: nil),
                            ].filter { allType in
                                dependencyTypes(for: dependency, component: component).contains(where: { allType.value.id == $0.id })
                            },
                            enabledTypes: enabledDependencyTypes(for: dependency),
                            onUpdateDependencyType: { store.updateModuleTypeForRemoteDependency(withComponentName: component.name, dependency: dependency, type: $0, value: $1) },
                            onRemove: { store.removeRemoteDependencyForComponent(withComponentName: component.name, dependency: dependency) }
                        )
                    }
                }
            },
            allLibraryTypes: LibraryType.allCases,
            allModuleTypes: ModuleType.allCases,
            isModuleTypeOn: { component.modules[$0] != nil },
            onModuleTypeSwitchedOn: { store.addModuleTypeForComponent(withName: component.name, moduleType: $0) },
            onModuleTypeSwitchedOff: { store.removeModuleTypeForComponent(withName: component.name, moduleType:$0) },
            moduleTypeTitle: { moduleTypeTitle(for: $0, component: component) },
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

    private func componentTypes(for dependency: ComponentDependency, component: Component) -> [IdentifiableWithSubtypeAndSelection<TargetType, ModuleType>] {
        [
            .init(title: "Contract", subtitle: nil, value: .contract, subValue: nil, selectedValue: dependency.contract, selectedSubValue: nil),
            .init(title: "Implementation", subtitle: "Tests",
                  value: .implementation, subValue: .tests,
                  selectedValue: dependency.implementation, selectedSubValue: dependency.tests),
            .init(title: "Mock", subtitle: nil, value: .mock, subValue: nil, selectedValue: dependency.mock, selectedSubValue: nil),
        ].filter { value in
            component.modules.keys.contains { moduleType in
                switch (moduleType, value.value) {
                case (.contract, .contract),
                    (.implementation, .implementation),
                    (.mock, .mock):
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

    private func dependencyTypes(for dependency: RemoteDependency, component: Component) -> [TargetType] {
        component.modules.keys.sorted().reduce(into: [TargetType](), { partialResult, moduleType in
            switch moduleType {
            case .contract:
                partialResult.append(TargetType.contract)
            case .implementation:
                partialResult.append(TargetType.implementation)
                partialResult.append(TargetType.tests)
            case .mock:
                partialResult.append(TargetType.mock)
            }
        })
    }

    private func enabledDependencyTypes(for dependency: RemoteDependency) -> [TargetType] {
        var types = [TargetType]()
        if dependency.contract {
            types.append(.contract)
        }
        if dependency.implementation {
            types.append(.implementation)
        }
        if dependency.tests {
            types.append(.tests)
        }
        if dependency.mock {
            types.append(.mock)
        }

        return types
    }

    private func componentResourcesValueBinding(component: Component) -> Binding<[DynamicTextFieldList<TargetResources.ResourcesType,
                                                                                  TargetType>.ValueContainer]> {
        Binding(get: {
            component.resources.map { resource -> DynamicTextFieldList<TargetResources.ResourcesType,
                                                                       TargetType>.ValueContainer in
                return .init(id: resource.id,
                             value: resource.folderName,
                             menuOption: resource.type,
                             targetTypes: resource.targets)
            }
        }, set: { store.updateResource($0.map {
            ComponentResources(id: $0.id, folderName: $0.value, type: $0.menuOption, targets: $0.targetTypes) }, forComponentWithName: component.name)
        })
    }

    private func allTargetTypes(forComponent component: Component) -> [IdentifiableWithSubtype<TargetType>] {
        [
            .init(title: "Contract", subtitle: nil, value: .contract, subValue: nil),
            .init(title: "Implementation", subtitle: "Tests",
                  value: .implementation, subValue: .tests),
            .init(title: "Mock", subtitle: nil, value: .mock, subValue: nil)
        ].filter { target in
            component.modules.keys.contains(where: { $0.rawValue == target.value.rawValue })
        }
    }
}
