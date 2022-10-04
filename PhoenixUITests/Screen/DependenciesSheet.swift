import AccessibilityIdentifiers
import XCTest

class DependenciesSheet: Screen {
    var filter: XCUIElement {
        Screen.app.textFields[AccessibilityIdentifiers.DependenciesSheet.filter.identifier]
    }
    
    func component(named: String) -> XCUIElement {
        Screen.app.buttons[AccessibilityIdentifiers.DependenciesSheet.component(named: named).identifier]
    }
    
    @discardableResult
    func filter(text: String) -> DependenciesSheet {
        filter.click()
        filter.typeText(text)
        return self
    }
    
    @discardableResult
    func tapEnter() -> DependenciesSheet {
        filter.typeKey(.enter, modifierFlags: [])
        return self
    }
    
    @discardableResult
    func filterAndEnter(named: String) -> Screen {
        return self
            .filter(text: named)
            .tapEnter()
    }
    
    @discardableResult
    func clickComponent(named: String) -> Screen {
        component(named: named).click()
        return self
    }
}
