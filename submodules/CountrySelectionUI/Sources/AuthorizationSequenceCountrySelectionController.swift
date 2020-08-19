import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import SearchBarNode
import AppBundle
import TelegramCore

private func loadCountryCodes() -> [Country] {
    guard let filePath = getAppBundle().path(forResource: "PhoneCountries", ofType: "txt") else {
        return []
    }
    guard let stringData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        return []
    }
    guard let data = String(data: stringData, encoding: .utf8) else {
        return []
    }
    
    let delimiter = ";"
    let endOfLine = "\n"
    
    var result: [Country] = []
    
    var currentLocation = data.startIndex
    
    let locale = Locale(identifier: "en-US")
    
    while true {
        guard let codeRange = data.range(of: delimiter, options: [], range: currentLocation ..< data.endIndex) else {
            break
        }
        
        let countryCode = String(data[currentLocation ..< codeRange.lowerBound])
        
        guard let idRange = data.range(of: delimiter, options: [], range: codeRange.upperBound ..< data.endIndex) else {
            break
        }
        
        let countryId = String(data[codeRange.upperBound ..< idRange.lowerBound])
        
        let maybeNameRange = data.range(of: endOfLine, options: [], range: idRange.upperBound ..< data.endIndex)
        
        let countryName = locale.localizedString(forIdentifier: countryId) ?? ""
        if let countryCodeInt = Int(countryCode) {
            result.append(Country(code: countryId, defaultName: countryName, name: countryName, countryCodes: [Country.CountryCode(code: countryCode, prefixes: [], patterns: [])]))
        }
        
        if let maybeNameRange = maybeNameRange {
            currentLocation = maybeNameRange.upperBound
        } else {
            break
        }
    }
    
    return result
}

private var countryCodes: [Country] = loadCountryCodes()

public func loadServerCountryCodes(network: Network) {
    let _ = (getCountriesList(network: network, langCode: "")
    |> deliverOnMainQueue).start(next: { countries in
        countryCodes = countries
    })
}

private final class AuthorizationSequenceCountrySelectionNavigationContentNode: NavigationBarContentNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let cancel: () -> Void
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String) -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, cancel: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.cancel = cancel
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme), strings: strings, fieldStyle: .modern)
        let placeholderText = strings.Common_Search
        let searchBarFont = Font.regular(17.0)
        
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            //self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.queryUpdated?(query)
        }
    }
    
    func setQueryUpdated(_ f: @escaping (String) -> Void) {
        self.queryUpdated = f
    }
    
    override var nominalHeight: CGFloat {
        return 54.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - self.nominalHeight), size: CGSize(width: size.width, height: 54.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}

public final class AuthorizationSequenceCountrySelectionController: ViewController {
    public static func lookupCountryNameById(_ id: String, strings: PresentationStrings) -> String? {
        for country in countryCodes {
            if id == country.code {
                let locale = localeWithStrings(strings)
                if let countryName = locale.localizedString(forRegionCode: id) {
                    return countryName
                } else {
                    return nil
                }
            }
        }
        return nil
    }
    
    public static func lookupCountryIdByCode(_ code: Int) -> String? {
        for country in countryCodes {
            for countryCode in country.countryCodes {
                if countryCode.code == "\(code)" {
                    return country.code
                }
            }
        }
        return nil
    }
    
    public static func lookupPatternByCode(_ code: Int) -> String? {
        for country in countryCodes {
            for countryCode in country.countryCodes {
                if countryCode.code == "\(code)" {
                    return countryCode.patterns.first
                }
            }
        }
        return nil
    }
    
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let displayCodes: Bool
    
    private var navigationContentNode: AuthorizationSequenceCountrySelectionNavigationContentNode?
    
    private var controllerNode: AuthorizationSequenceCountrySelectionControllerNode {
        return self.displayNode as! AuthorizationSequenceCountrySelectionControllerNode
    }
    
    public var completeWithCountryCode: ((Int, String) -> Void)?
    public var dismissed: (() -> Void)?
    
    public init(strings: PresentationStrings, theme: PresentationTheme, displayCodes: Bool = true) {
        self.theme = theme
        self.strings = strings
        self.displayCodes = displayCodes
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.navigationPresentation = .modal
        
        self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
        
        let navigationContentNode = AuthorizationSequenceCountrySelectionNavigationContentNode(theme: theme, strings: strings, cancel: { [weak self] in
            self?.dismissed?()
            self?.dismiss()
        })
        self.navigationContentNode = navigationContentNode
        navigationContentNode.setQueryUpdated { [weak self] query in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            strongSelf.controllerNode.updateSearchQuery(query)
        }
        self.navigationBar?.setContentNode(navigationContentNode, animated: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceCountrySelectionControllerNode(theme: self.theme, strings: self.strings, displayCodes: self.displayCodes, itemSelected: { [weak self] args in
            let (_, countryId, code) = args
            self?.completeWithCountryCode?(code, countryId)
            self?.dismiss()
        })
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.navigationContentNode?.activate()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func cancelPressed() {
        self.dismissed?()
        self.dismiss(completion: nil)
    }
}
