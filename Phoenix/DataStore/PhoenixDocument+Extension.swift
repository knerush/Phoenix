import Component
import Foundation
import PhoenixDocument
import SwiftPackage

extension PhoenixDocument {

    func getFamily(withName name: String) -> Family? {
        families.first(where: { $0.family.name == name })?.family
    }

    var componentsFamilies: [ComponentsFamily] { families }
    private var allNames: [Name] { componentsFamilies.flatMap { $0.components }.map(\.name) }

    func title(for name: Name) -> String {
        let family = family(for: name)
        return family?.ignoreSuffix == true ? name.given : name.given + name.family
    }

    func nameExists(name: Name) -> Bool {
        allNames.contains(name)
    }

    mutating func component(withName name: Name, containsDependencyWithName dependencyName: Name) -> Bool {
        var value: Bool = false
        getComponent(withName: name) { component in
            value = component.localDependencies.contains { $0.name == dependencyName }
        }
        return value
    }
    
    mutating func updateDefaultdependencyForComponent(withName name: Name, packageType: PackageTargetType, value: String?) {
        getComponent(withName: name) { component in
            component.defaultDependencies[packageType] = value
        }
    }

    func family(for name: Name) -> Family? {
        families.first(where: { name.family == $0.family.name })?.family
    }
    
    mutating func updateDefaultdependencyForFamily(named name: String, packageType: PackageTargetType, value: String?) {
        getFamily(withName: name) { family in
            family.defaultDependencies[packageType] = value
        }
    }

    // MARK: - Private
    private mutating func getComponent(withName name: Name, _ completion: (inout Component) -> Void) {
        guard
            let familyIndex = families.firstIndex(where: { $0.components.contains(where: { $0.name == name }) }),
            let componentIndex = families[familyIndex].components.firstIndex(where: { $0.name == name })
        else { return }
        completion(&families[familyIndex].components[componentIndex])
    }

    private mutating func getFamily(withName name: String, _ completion: (inout Family) -> Void) {
        guard
            let familyIndex = families.firstIndex(where: { $0.family.name == name })
        else { return }
        completion(&families[familyIndex].family)
    }

    private mutating func get(remoteDependency: RemoteDependency, componentWithName name: Name, _ completion: (inout RemoteDependency) -> Void) {
        getComponent(withName: name) { component in
            var dependencies = component.dependencies
            guard
                let index = dependencies.firstIndex(where: { $0 == .remote(remoteDependency) }),
                case var .remote(temp) = dependencies.remove(at: index)
            else { return }
            completion(&temp)
            dependencies.append(.remote(temp))
            dependencies.sort()
            component.dependencies = dependencies
        }
    }

    private mutating func get(dependency: ComponentDependency, componentWithName name: Name, _ completion: (inout ComponentDependency) -> Void) {
        getComponent(withName: name) { component in
            var dependencies = component.dependencies
            guard
                let index = dependencies.firstIndex(where: { $0 == .local(dependency) }),
                case var .local(temp) = dependencies.remove(at: index)
            else { return }
            completion(&temp)
            dependencies.append(.local(temp))
            dependencies.sort()
            component.dependencies = dependencies
        }
    }

    // MARK: - Document modifiers
    func getComponent(withName name: Name) -> Component? {
        guard
            let component = families.flatMap(\.components).first(where: { $0.name == name })
        else { return nil }
        return component
    }


    mutating func addNewComponent(withName name: Name, template: Component? = nil) throws {
        if name.given.isEmpty {
            throw NSError(domain: "Given name cannot be empty", code: 500)
        } else if name.family.isEmpty {
            throw NSError(domain: "Component must be part of a family", code: 501)
        } else if nameExists(name: name) {
            throw NSError(domain: "Name already in use", code: 502)
        }

        var componentsFamily: ComponentsFamily = self
            .families
            .first(where: { componentsFamily in
                name.family == componentsFamily.family.name
            }) ?? ComponentsFamily(family: Family(name: name.family, ignoreSuffix: false, folder: nil), components: [])
        guard componentsFamily.components.contains(where: { $0.name == name }) == false else { return }

        var array = componentsFamily.components

        let moduleTypes: [String: LibraryType] = projectConfiguration.packageConfigurations
            .reduce(into: [String: LibraryType](), { partialResult, packageConfiguration in
                partialResult[packageConfiguration.name] = .undefined
            })

        let newComponent = Component(name: name,
                                     iOSVersion: template?.iOSVersion,
                                     macOSVersion: template?.macOSVersion,
                                     modules: template?.modules ?? moduleTypes,
                                     dependencies: template?.dependencies ?? [],
                                     resources: template?.resources ?? [],
                                     defaultDependencies: [:])
        array.append(newComponent)
        array.sort(by: { $0.name.full < $1.name.full })

        componentsFamily.components = array

        if let familyIndex = families.firstIndex(where: { $0.family.name == name.family }) {
            families[familyIndex].components = array
        } else {
            var familiesArray = families
            familiesArray.append(componentsFamily)
            familiesArray.sort(by: { $0.family.name < $1.family.name })
            families = familiesArray
        }
    }

    mutating func updateFamily(withName name: String, ignoresSuffix: Bool) {
        getFamily(withName: name) { $0.ignoreSuffix = ignoresSuffix }
    }

    mutating func updateFamily(withName name: String, folder: String?) {
        getFamily(withName: name) { $0.folder = folder?.isEmpty == true ? nil : folder }
    }
    
    mutating func updateFamilyRule(withName name: String, otherFamilyName: String, enabled: Bool) {
        getFamily(withName: name) { family in
            if enabled {
                family.excludedFamilies.removeAll(where: { otherFamilyName == $0 })
            } else if !family.excludedFamilies.contains(otherFamilyName) {
                family.excludedFamilies.append(otherFamilyName)
                family.excludedFamilies.sort()
            }
        }
    }
    
    mutating func addDependencyToComponent(withName name: Name, dependencyName: Name) {
        var defaultDependencies: [PackageTargetType: String] = getComponent(withName: dependencyName)?.defaultDependencies ?? [:]
        if defaultDependencies.isEmpty {
            defaultDependencies = getFamily(withName: dependencyName.family)?.defaultDependencies ?? [:]
        }
        if defaultDependencies.isEmpty {
            defaultDependencies = projectConfiguration.defaultDependencies
        }

        var targetTypes: [PackageTargetType: String] = [:]
        getComponent(withName: dependencyName) { dependencyComponent in
            if !defaultDependencies.values.contains(where: { dependencyComponent.modules[$0] == nil }) {
                targetTypes = defaultDependencies.filter{ element in
                    dependencyComponent.modules.contains { (key, _) in
                        key == element.value
                    }
                }
            }
        }
        getComponent(withName: name) { component in
            targetTypes = targetTypes.filter { (key, _) in component.modules.contains(where: { $0.key == key.name }) }
            var dependencies = component.dependencies
            dependencies.append(.local(ComponentDependency(name: dependencyName, targetTypes: targetTypes)))
            dependencies.sort()
            component.dependencies = dependencies
        }
    }

    mutating func addRemoteDependencyToComponent(withName name: Name, dependency: RemoteDependency) {
        getComponent(withName: name) {
            var dependencies = $0.dependencies
            dependencies.append(.remote(dependency))
            dependencies.sort()
            $0.dependencies = dependencies
        }
    }

    mutating func setIOSVersionForComponent(withName name: Name, iOSVersion: IOSVersion) {
        getComponent(withName: name) { $0.iOSVersion = iOSVersion }
    }

    mutating func removeIOSVersionForComponent(withName name: Name) {
        getComponent(withName: name) { $0.iOSVersion = nil }
    }

    mutating func setMacOSVersionForComponent(withName name: Name, macOSVersion: MacOSVersion) {
        getComponent(withName: name) { $0.macOSVersion = macOSVersion }
    }

    mutating func removeMacOSVersionForComponent(withName name: Name) {
        getComponent(withName: name) { $0.macOSVersion = nil }
    }

    mutating func addModuleTypeForComponent(withName name: Name, moduleType: String) {
        getComponent(withName: name) {
            var modules = $0.modules
            modules[moduleType] = .undefined
            $0.modules = modules
        }
    }

    mutating func removeModuleTypeForComponent(withName name: Name, moduleType: String) {
        getComponent(withName: name) {
            var modules = $0.modules
            modules.removeValue(forKey: moduleType)
            $0.modules = modules
        }
    }

    mutating func set(forComponentWithName name: Name, libraryType: LibraryType?, forModuleType moduleType: String) {
        getComponent(withName: name) {
            $0.modules[moduleType] = libraryType
        }
    }

    mutating func removeComponent(withName name: Name) {
        guard
            let familyIndex = families.firstIndex(where: { $0.components.contains(where: { $0.name == name }) })
        else { return }
        families[familyIndex].components.removeAll(where: { $0.name == name })
        families.removeAll(where: { $0.components.isEmpty })
    }

    mutating func removeDependencyForComponent(withComponentName name: Name, componentDependency: ComponentDependency) {
        getComponent(withName: name) {
            var dependencies = $0.dependencies
            dependencies.removeAll(where: { $0 == .local(componentDependency) })
            dependencies.sort()
            $0.dependencies = dependencies
        }
    }

    mutating func removeRemoteDependencyForComponent(withComponentName name: Name, dependency: RemoteDependency) {
        getComponent(withName: name) {
            var dependencies = $0.dependencies
            dependencies.removeAll(where: { $0 == .remote(dependency) })
            dependencies.sort()
            $0.dependencies = dependencies
        }
    }

    mutating func updateModuleTypeForDependency(withComponentName name: Name, dependency: ComponentDependency, type: PackageTargetType, value: String?) {
        get(dependency: dependency, componentWithName: name) { dependency in
            if let value = value {
                dependency.targetTypes[type] = value
            } else {
                dependency.targetTypes.removeValue(forKey: type)
            }
        }
    }

    mutating func updateModuleTypeForRemoteDependency(withComponentName name: Name, dependency: RemoteDependency, type: PackageTargetType, value: Bool) {
        get(remoteDependency: dependency, componentWithName: name) { dependency in
            let typeIndex = dependency.targetTypes.firstIndex(of: type)
            if value && typeIndex == nil {
                dependency.targetTypes.append(type)
                dependency.targetTypes.sort()
            } else if !value, let typeIndex = typeIndex {
                dependency.targetTypes.remove(at: typeIndex)
            }
        }
    }

    mutating func updateVersionForRemoteDependency(withComponentName name: Name, dependency: RemoteDependency, version: ExternalDependencyVersion) {
        get(remoteDependency: dependency, componentWithName: name) { $0.version = version }
    }

    mutating func updateVersionStringValueForRemoteDependency(withComponentName name: Name, dependency: RemoteDependency, stringValue: String) {
        get(remoteDependency: dependency, componentWithName: name) { dependency in
            switch dependency.version {
            case .from:
                dependency.version = .from(version: stringValue)
            case .branch:
                dependency.version = .branch(name: stringValue)
            case .exact:
                dependency.version = .exact(version: stringValue)
            }
        }
    }

    mutating func updateResource(_ resources: [ComponentResources], forComponentWithName name: Name) {
        getComponent(withName: name) { $0.resources = resources }
    }

    mutating func addResource(_ folderName: String, forComponentWithName name: Name) {
        getComponent(withName: name) { $0.resources.append(.init(folderName: folderName,
                                                                 type: .process,
                                                                 targets: [])) }
    }

    mutating func removeResource(withId id: String, forComponentWithName name: Name) {
        getComponent(withName: name) { $0.resources.removeAll(where: { $0.id == id }) }
    }
}