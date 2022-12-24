import AppVersionProviderContract
import Component
import DemoAppFeature
import Factory
import PhoenixDocument
import PhoenixViews
import SwiftUI
import SwiftPackage
import AccessibilityIdentifiers

enum ListSelection: String, Hashable, CaseIterable, Identifiable {
    static var allCases: [ListSelection] { [.components, .remote] }
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .components:
            return "1"
        case .remote:
            return "2"
        case .plugins:
            return "3"
        }
    }
    
    case components
    case remote
    case plugins
}

struct ContentView: View {
    var fileURL: URL?
    @Binding var document: PhoenixDocument
    @StateObject var viewModel: ViewModel = .init()
    
    @State private var listSelection: ListSelection = .components
    
    init(fileURL: URL?,
         document: Binding<PhoenixDocument>) {
        self.fileURL = fileURL
        self._document = document
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            splitView(sideView, detail: detailView)
                .alert(item: $viewModel.alertState, content: { alertState in
                    Alert(title: Text("Error"),
                          message: Text(alertState.title),
                          dismissButton: .default(Text("Ok")))
                }).sheet(item: .constant(viewModel.showingNewComponentPopup)) { state in
                    newComponentSheet(state: state)
                }.sheet(item: .constant(viewModel.selectedFamily(document: $document))) { family in
                    FamilySheet(family: family,
                                relationViewData: document.familyRelationViewData(familyName: family.wrappedValue.name),
                                rules: viewModel.allRules(for: family.wrappedValue, document: document),
                                onDismiss: { viewModel.select(familyName: nil) }
                    )
                }.sheet(isPresented: .constant(viewModel.showingConfigurationPopup)) {
                    ConfigurationView(
                        configuration: $document.projectConfiguration,
                        relationViewData: document.projectConfigurationRelationViewData()
                    ) {
                        viewModel.showingConfigurationPopup = false
                    }.frame(minHeight: 800)
                }
                .sheet(item: $viewModel.demoAppFeatureData, content: { data in
                    Container.demoAppFeatureView(data)
                })
                .sheet(isPresented: $viewModel.showingGenerateSheet,
                       onDismiss: viewModel.onDismissGenerateSheet,
                       content: {
                    GenerateSheetView(
                        viewModel: GenerateSheetViewModel(
                            modulesPath: viewModel.modulesFolderURL?.path ?? "path/to/modules",
                            xcodeProjectPath: viewModel.xcodeProjectURL?.path ?? "path/to/Project.xcodeproj",
                            hasModulesPath: viewModel.modulesFolderURL != nil,
                            hasXcodeProjectPath: viewModel.xcodeProjectURL != nil,
                            isSkipXcodeProjectOn: viewModel.skipXcodeProject,
                            onOpenModulesFolder: { viewModel.onOpenModulesFolder(fileURL: fileURL) },
                            onOpenXcodeProject: { viewModel.onOpenXcodeProject(fileURL: fileURL) },
                            onSkipXcodeProject: viewModel.onSkipXcodeProject,
                            onGenerate: { viewModel.onGenerate(document: document, fileURL: fileURL) },
                            onDismiss: viewModel.onDismissGenerateSheet)
                    )
                })
                .popover(item: $viewModel.showingUpdatePopup) { showingUpdatePopup in
                    updateView(appVersionInfo: showingUpdatePopup)
                }
        }
        .onAppear(perform: viewModel.checkForUpdate)
        .toolbar(content: toolbarViews)
        .frame(minWidth: 900)
    }
    
    // MARK: - Views
    @ViewBuilder private func splitView<Sidebar: View, Detail: View>(_ sidebar: () -> Sidebar, detail: () -> Detail) -> some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView(sidebar: sidebar, detail: detailView)
                .navigationSplitViewColumnWidth(min: 750, ideal: 750, max: nil)
        } else {
            HSplitView {
                sidebar()
                detail()
            }
        }
    }
    
    @ViewBuilder private func sideView() -> some View {
        ZStack {
            Button(action: onUpArrow, label: {})
                .opacity(0)
                .keyboardShortcut(.upArrow, modifiers: [])
            Button(action: onDownArrow, label: {})
                .opacity(0)
                .keyboardShortcut(.downArrow, modifiers: [])
            if ListSelection.allCases.count > 1 {
                ForEach(ListSelection.allCases) { selection in
                    Button(action: { listSelection = selection }, label: {})
                        .opacity(0)
                        .keyboardShortcut(selection.keyboardShortcut, modifiers: .command)
                }
            }
            
            VStack {
                if ListSelection.allCases.count > 1 {
                    Picker("", selection: $listSelection) {
                        ForEach(ListSelection.allCases) { selection in
                            Text(selection.title)
                                .tag(selection)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.leading, 8)
                    .padding(.trailing, 16)
                    .foregroundColor(.accentColor)
                }
                
                switch listSelection {
                case .components:
                    componentsList()
                case .remote:
                    remoteComponentsList()
                case .plugins:
                    pluginsList()
                }
                FilterView(text: $viewModel.componentsListFilter.nonOptionalBinding)
            }
        }
        .frame(minWidth: 250)
    }
    
    @ViewBuilder private func componentsList() -> some View {
        VStack(alignment: .leading) {
            Button(action: viewModel.onAddButton) {
                Label("New Component", systemImage: "plus.circle.fill")
            }
            .keyboardShortcut("A", modifiers: [.command, .shift])
            .with(accessibilityIdentifier: ToolbarIdentifiers.newComponentButton)
            .padding(.horizontal)
            ComponentsList(
                sections: viewModel.componentsListSections(document: document),
                onSelect: viewModel.select(componentName:),
                onSelectSection: viewModel.select(familyName:)
            )
        }
    }
    
    @ViewBuilder private func remoteComponentsList() -> some View {
        VStack(alignment: .leading) {
            Button(action: viewModel.onAddRemoteButton) {
                Label("New Remote Dependency", systemImage: "plus.circle.fill")
            }
            .keyboardShortcut("A", modifiers: [.command, .shift])
            .with(accessibilityIdentifier: ToolbarIdentifiers.newRemoteComponentButton)
            .padding(.horizontal)
            RemoteComponentsList(
                rows: viewModel.remoteComponentsListRows(document: document),
                onSelect: viewModel.select(remoteComponentURL:)
            )
        }
    }
    
    @ViewBuilder private func pluginsList() -> some View {
        VStack(alignment: .leading) {
            Button(action: viewModel.onAddButton) {
                Label("New Plugin", systemImage: "plus.circle.fill")
            }
            .keyboardShortcut("A", modifiers: [.command, .shift])
            .with(accessibilityIdentifier: ToolbarIdentifiers.newComponentButton)
            .padding(.horizontal)
            ScrollView {
                
            }
            Spacer()
        }
    }
    
    @ViewBuilder private func detailView() -> some View {
        if let selectedComponentBinding = viewModel.selectedComponent(document: $document) {
            componentView(for: selectedComponentBinding)
                .sheet(isPresented: .constant(viewModel.showingDependencySheet)) {
                    dependencySheet(component: selectedComponentBinding.wrappedValue)
                }
                .sheet(isPresented: .constant(viewModel.showingRemoteDependencySheet)) {
                    remoteDependencySheet(component: selectedComponentBinding.wrappedValue)
                }
        } else if let selectedRemoteComponentBinding = viewModel.selectedRemoteComponent(document: $document) {
            remoteComponentView(for: selectedRemoteComponentBinding)
        } else {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("No Component Selected")
                        .font(.title)
                        .padding()
                    Spacer()
                }
                Spacer()
            }
        }
    }
    
    @ViewBuilder private func componentView(for component: Binding<Component>) -> some View {
        ComponentView(
            component: component,
            relationViewData: document.componentRelationViewData(componentName: component.wrappedValue.name),
            relationViewDataToComponentNamed: { dependencyName, selectedValues in
                document.relationViewData(fromComponentName: component.wrappedValue.name,
                                          toComponentName: dependencyName,
                                          selectedValues: selectedValues)
            },
            titleForComponentNamed: document.title(forComponentNamed:),
            onGenerateDemoAppProject: {
                viewModel.onGenerateDemoProject(for: component.wrappedValue, from: document, fileURL: fileURL)
            },
            onRemove: { document.removeComponent(withName: component.wrappedValue.name) },
            allTargetTypes: allTargetTypes(forComponent: component.wrappedValue),
            allModuleTypes: document.projectConfiguration.packageConfigurations.map(\.name),
            onShowDependencySheet: { viewModel.showingDependencySheet = true },
            onShowRemoteDependencySheet: { viewModel.showingRemoteDependencySheet = true },
            onSelectRemoteURL: viewModel.select(remoteComponentURL:)
        )
    }
    
    @ViewBuilder private func remoteComponentView(for remoteComponent: Binding<RemoteComponent>) -> some View {
        RemoteComponentView(
            remoteComponent: remoteComponent,
            onRemove: { document.removeRemoteComponent(withURL: remoteComponent.wrappedValue.url) }
        )
    }
    
    @ViewBuilder private func newComponentSheet(state: ComponentPopupState) -> some View {
        switch state {
        case .new:
            NewComponentSheet(onSubmit: { name, familyName in
                let name = Name(given: name, family: familyName)
                try document.addNewComponent(withName: name)
                viewModel.select(componentName: name)
                viewModel.showingNewComponentPopup = nil
            }, onDismiss: {
                viewModel.showingNewComponentPopup = nil
            }, familyNameSuggestion: { familyName in
                guard !familyName.isEmpty else { return nil }
                return document.families.first { componentFamily in
                    componentFamily.family.name.hasPrefix(familyName)
                }?.family.name
            })
            
        case .remote:
            NewRemoteComponentSheet { url, version in
                try document.addNewRemoteComponent(withURL: url, version: version)
                viewModel.showingNewComponentPopup = nil
            } onDismiss: {
                viewModel.showingNewComponentPopup = nil
            }
        }
    }
    
    @ViewBuilder private func dependencySheet(component: Component) -> some View {
        let familyName = document.family(named: component.name.family)?.name ?? ""
        let allFamilies = document.families.filter { !$0.family.excludedFamilies.contains(familyName) }
        let allNames = allFamilies.flatMap(\.components).map(\.name)
        let filteredNames = Dictionary(grouping: allNames.filter { name in
            component.name != name && !component.localDependencies.contains { localDependency in
                localDependency.name == name
            }
        }, by: { $0.family })
        let sections = filteredNames.reduce(into: [ComponentDependenciesListSection]()) { partialResult, keyValue in
            partialResult.append(ComponentDependenciesListSection(name: keyValue.key,
                                                                  rows: keyValue.value.map { name in
                ComponentDependenciesListRow(name: document.title(forComponentNamed: name),
                                             onSelect: {
                    document.addDependencyToComponent(withName: component.name, dependencyName: name)
                    viewModel.showingDependencySheet = false
                })
            }))
        }.sorted { lhs, rhs in
            lhs.name < rhs.name
        }
        ComponentDependenciesSheet(
            sections: sections,
            onDismiss: {
                viewModel.showingDependencySheet = false
            }).frame(minHeight: 600)
    }
    
    @ViewBuilder private func remoteDependencySheet(component: Component) -> some View {
        RemoteComponentDependenciesSheet(
            rows: document.remoteComponents.filter { remoteComponent in
                !component.remoteComponentDependencies.contains { remoteComponentDependency in
                    remoteComponent.url == remoteComponentDependency.url
                }
            },
            onSelect: { _ in },
            onDismiss: { viewModel.showingRemoteDependencySheet = false }
        )
    }
    
    @ViewBuilder private func toolbarViews() -> some View {
        toolbarLeadingItems()
        Spacer()
        toolbarTrailingItems()
    }
    
    @ViewBuilder private func toolbarLeadingItems() -> some View {
        if let appUpdateVerdsionInfo = viewModel.appUpdateVersionInfo {
            Button(action: viewModel.onUpdateButton) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.red)
                Text("Update \(appUpdateVerdsionInfo.version) Available")
            }
        }
        
        Button(action: viewModel.onConfigurationButton) {
            Image(systemName: "wrench.and.screwdriver")
            Text("Configuration")
        }
        .keyboardShortcut(",", modifiers: [.command])
        .with(accessibilityIdentifier: ToolbarIdentifiers.configurationButton)
    }
    
    @ViewBuilder private func toolbarTrailingItems() -> some View {
        Button(action: { viewModel.onGenerateSheetButton(fileURL: fileURL) }) {
            Image(systemName: "shippingbox.fill")
            Text("Generate")
        }.keyboardShortcut(.init("R"), modifiers: .command)
        Button(action: { viewModel.onGenerate(document: document, fileURL: fileURL) }) {
            Image(systemName: "play")
        }
        .disabled(viewModel.modulesFolderURL == nil || viewModel.xcodeProjectURL == nil)
        .keyboardShortcut(.init("R"), modifiers: [.command, .shift])
    }
    
    @ViewBuilder private func updateView(appVersionInfo: AppVersionInfo) -> some View {
        VStack(alignment: .leading) {
            Text("Update v\(appVersionInfo.version) is available.")
                .font(.title)
            Text("Release Notes: \(appVersionInfo.releaseNotes)")
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            HStack {
                Link(destination: URL(
                    string: "https://apps.apple.com/us/app/phoenix-app/id1626793172")!
                ) {
                    Text("Update")
                }
                Button("Dismiss") {
                    withAnimation {
                        viewModel.showingUpdatePopup = nil
                    }
                }.buttonStyle(.plain)
            }
        }.padding()
    }
    
    // MARK: - Private
    private func allTargetTypes(forComponent component: Component) -> [IdentifiableWithSubtype<PackageTargetType>] {
        configurationTargetTypes().filter { target in
            component.modules.keys.contains(where: { $0.lowercased() == target.value.name.lowercased() })
        }
    }
    
    private func configurationTargetTypes() -> [IdentifiableWithSubtype<PackageTargetType>] {
        document.projectConfiguration.packageConfigurations.map { packageConfiguration in
            IdentifiableWithSubtype(title: packageConfiguration.name,
                                    subtitle: packageConfiguration.hasTests ? "Tests" : nil,
                                    value: PackageTargetType(name: packageConfiguration.name, isTests: false),
                                    subValue: packageConfiguration.hasTests ? PackageTargetType(name: packageConfiguration.name, isTests: true) : nil)
        }
    }
    
    private func onDownArrow() {
        switch listSelection {
        case .components:
            viewModel.selectNextComponent(names: document.families.flatMap(\.components).map(\.name))
        case .remote:
            viewModel.selectNextRemoteComponent(remoteComponents: document.remoteComponents)
        case .plugins:
            break
        }
    }
    
    private func onUpArrow() {
        switch listSelection {
        case .components:
            viewModel.selectPreviousComponent(names: document.families.flatMap(\.components).map(\.name))
        case .remote:
            viewModel.selectPreviousRemoteComponent(remoteComponents: document.remoteComponents)
        case .plugins:
            break
        }
    }
}
