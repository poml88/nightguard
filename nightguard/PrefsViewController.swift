//
//  ViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import UIKit
import Eureka
import WidgetKit

class PrefsViewController: CustomFormViewController {
    
    private var nightscoutURLRow: URLRow!
    private var nightscoutURLRule = RuleValidNightscoutURL()
    
    lazy var uriPickerView: UIPickerView = {
        let pickerView = UIPickerView()
        pickerView.delegate = self
        return pickerView
    }()
    
    var hostUriTextField: UITextField {
        return nightscoutURLRow.cell.textField
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        showBookmarksButtonOnKeyboardIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func constructForm() {
        
        nightscoutURLRow = URLRow() { row in
                row.title = NSLocalizedString("URL", comment: "Title for URL")
                row.placeholder = "http://night.fritz.box"
                row.placeholderColor = UIColor.gray
                row.value = URL(string: UserDefaultsRepository.baseUri.value)
                row.add(rule: nightscoutURLRule)
                row.validationOptions = .validatesOnDemand
            }.onChange { [weak self] row in
                guard let urlString = row.value?.absoluteString, !urlString.isEmpty else { return }
                if let updatedUrlString = self?.addProtocolPartIfMissing(urlString), let updatedUrl = URL(string: updatedUrlString) {
                    row.value = updatedUrl
                    row.updateCell()
                }
            }.onCellHighlightChanged { [weak self] (cell, row) in
                if row.isHighlighted == false {
                    
                    // editing finished
//                    guard row.validate().isEmpty else { return }
                    guard let value = row.value else { return }
                    self?.nightscoutURLChanged(value)
                }
            }
            .onRowValidationChanged { cell, row in
                
                guard let rowIndex = row.indexPath?.row else {
                    return
                }
                guard let section = row.section else {
                    return
                }
                while section.count > rowIndex + 1 && row.section?[rowIndex  + 1] is LabelRow {
                    section.remove(at: rowIndex + 1)
                }
                if !row.isValid {
                    for (index, validationMsg) in row.validationErrors.map({ $0.msg }).enumerated() {
                        let labelRow = LabelRow() {
                            let title = "❌ \(validationMsg)"
                            $0.title = title
                            $0.cellUpdate { cell, _ in
                                cell.textLabel?.textColor = UIColor.nightguardRed()
                            }
                            $0.cellSetup { cell, row in
                                cell.textLabel?.numberOfLines = 0
                            }
                            let rows = CGFloat(title.count / 50) + 1 // we condiser 80 characters are on a line
                            $0.cell.height = { 30 * rows }
                        }
                        let insertionRow = row.indexPath!.row + index + 1
                        row.section?.insert(labelRow, at: insertionRow)
                    }
                }
        }
        
        
        form +++ Section(header: "NIGHTSCOUT", footer: NSLocalizedString("Enter the URI to your Nightscout Server here. E.g. 'https://nightscout?token=mytoken'. For the 'Care' actions to work you generally need to provide the security token here!", comment: "Footer for URL"))
            <<< nightscoutURLRow
            
            +++ Section(header: nil, footer: NSLocalizedString("If enabled, you will override your Units-Setting of your nightscout backend. Usually you can disable this. Nightguard will determine the correct Units on its own.", comment: "Footer for ManuallySetUnitsSwitch"))
            <<< SwitchRow("ManuallySetUnitsSwitch") { row in
                    row.title = NSLocalizedString("Manually set Units", comment: "Label for Manually set Units")
                    row.value = UserDefaultsRepository.manuallySetUnits.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.manuallySetUnits.value = value
                    // trigger onChange to activate the manually defined unit:
                    let manuallyDefinedUnitRow : PickerInlineRow<Units> =
                        self.form.rowBy(tag: "Units") as! PickerInlineRow<Units>
                    manuallyDefinedUnitRow.value = UserDefaultsRepository.units.value
                    // reload all data in the same way as if a new nightscout URI has been entered:
                    self.nightscoutURLChanged(URL(string: UserDefaultsRepository.baseUri.value)!)
            }
            
            <<< PickerInlineRow<Units>("Units") { row in
                row.hidden = "$ManuallySetUnitsSwitch == false"
                row.title = NSLocalizedString("Use the following Units", comment: "Label for 'Use the following Units'")
                row.options = [Units.mgdl, Units.mmol]
                row.value = UserDefaultsRepository.units.value
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return value.description
                }
            }.onChange { row in
                UserDefaultsRepository.units.value = row.value!
                // reload all data in the same way as if a new nightscout URI has been entered:
                self.nightscoutURLChanged(URL(string: UserDefaultsRepository.baseUri.value)!)
            }
            
            +++ Section(footer: NSLocalizedString("Keeping the screen active is of paramount importance if using the app as a night guard. We suggest leaving it ALWAYS ON.", comment: "Footer for Dim Screen"))
            <<< SwitchRow("KeepScreenActive") { row in
                row.title = NSLocalizedString("Keep the Screen Active", comment: "Label for Keep the Screen Active")
                row.value = SharedUserDefaultsRepository.screenlockSwitchState.value
                }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    
                    if value {
                        SharedUserDefaultsRepository.screenlockSwitchState.value = value
                    } else {
                        self?.showYesNoAlert(
                            title: NSLocalizedString("ARE YOU SURE?", comment: "Title for confirmation"),
                            message: NSLocalizedString("Keep this switch ON to disable the screenlock and prevent the app to get stopped!", comment: "Message for confirmation"),
                            yesHandler: {
                                SharedUserDefaultsRepository.screenlockSwitchState.value = value
                            },
                            noHandler: {
                                row.value = true
                                row.updateCell()
                        })
                    }
            }
            
            <<< PushRow<Int>() { row in
                row.title = NSLocalizedString("Dim Screen When Idle", comment: "Label for Dim screen when idle")
                row.hidden = "$KeepScreenActive == false"
                row.options = [0, 1, 2, 3, 4, 5, 10, 15]
                row.displayValueFor = { option in
                    switch option {
                    case 0: return NSLocalizedString("Never", comment: "Option")
                    case 1: return NSLocalizedString("1 Minute", comment: "Option")
                    default: return "\(option!) " + NSLocalizedString("Minutes", comment: "Option")
                    }
                }
                row.value = UserDefaultsRepository.dimScreenWhenIdle.value
                row.selectorTitle = NSLocalizedString("Dim Screen When Idle", comment: "Label for Dim screen when idle")
                }.onPresent { form, selector in
                    selector.customize(header: "", footer: NSLocalizedString("Reduce screen brightness after detecting user inactivity for more than selected time period.", comment: "Footer for Reduce screen brightness"))
                }.onChange { row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.dimScreenWhenIdle.value = value
                    row.reload()
            }
            
            +++ Section()
            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Show Statistics", comment: "Label for Show statistics")
                row.value = UserDefaultsRepository.showStats.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.showStats.value = value
            }

            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Show Care/Loop Data", comment: "Label for Show Care/Loop Data")
                row.value = UserDefaultsRepository.showCareAndLoopData.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.showCareAndLoopData.value = value
            }
            
            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Show Yesterdays BGs", comment: "Label for Show Yesterdays BG values in chart")
                row.value = UserDefaultsRepository.showYesterdaysBgs.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.showYesterdaysBgs.value = value
            }
        
            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Check BG every minute", comment: "Label for Check BG every minute")
                row.value = UserDefaultsRepository.checkBGEveryMinute.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.checkBGEveryMinute.value = value
            }
        
            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Show BG on App Badge", comment: "Label for Show BG on Badge")
                row.value = SharedUserDefaultsRepository.showBGOnAppBadge.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    SharedUserDefaultsRepository.showBGOnAppBadge.value = value
            }
        
            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Synchronize with Apple Health", comment: "Label for Apple Health synchronization")
                row.value = AppleHealthService.singleton.isAuthorized()
            }.onChange { row in
                if (AppleHealthService.singleton.isAuthorized()) {
                    let title:String = NSLocalizedString("Synchronize with Apple Health", comment: "Label for Apple Health synchronization")
                    let message: String = NSLocalizedString("Revoke access in Apple Health", comment: "Label for Apple Health access revocation")
                    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    
                    self.present(alert, animated: true, completion: nil)
                    Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false, block: { _ in alert.dismiss(animated: true, completion: nil)} )

                    row.value = true
                } else {
                    AppleHealthService.singleton.requestAuthorization()
                }
            }
            
            <<< LabelRow() { row in
                row.title = NSLocalizedString("Version", comment: "Label for Version")
                
                let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
                let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
                row.value = "V\(versionNumber).\(buildNumber)"
        }
    }
    
    private func nightscoutURLChanged(_ url: URL) {
        
        UserDefaultsRepository.baseUri.value = url.absoluteString
        
        NightscoutCacheService.singleton.resetCache()
        NightscoutDataRepository.singleton.storeTodaysBgData([])
        NightscoutDataRepository.singleton.storeYesterdaysBgData([])
        NightscoutDataRepository.singleton.storeCurrentNightscoutData(NightscoutData())
        
        retrieveAndStoreNightscoutUnits { [weak self] error in
            
            // keep the error message
            self?.nightscoutURLRule.nightscoutError = error
            
            self?.nightscoutURLRow.cleanValidationErrors()
            self?.nightscoutURLRow.validate()
            self?.nightscoutURLRow.updateCell()
            
            if error == nil {
                
                // add host URI only if status request was successful
                self?.addUriEntryToPickerView(hostUri: url.absoluteString)
            }
        }
    }
    
    // adds 'https://' if a '/' but no 'http'-part is found in the uri.
    private func addProtocolPartIfMissing(_ uri : String) -> String? {
        
        if (uri.contains("/") || uri.contains(".") || uri.contains(":"))
            && !uri.contains("http") {
            
            return "https://" + uri
        }
        
        return nil
    }
    
    private func retrieveAndStoreNightscoutUnits(completion: @escaping (Error?) -> Void) {
        
        if UserDefaultsRepository.manuallySetUnits.value {
            // if the user decided to manually set the display units, we don't have to determine
            // them here. So just back off:
            completion(nil)
            return
        }
        
        NightscoutService.singleton.readStatus { (result: NightscoutRequestResult<Units>) in
            
            switch result {
            case .data(let units):
                UserDefaultsRepository.units.value = units
                completion(nil)
                
            case .error(let error):
                completion(error)
            }
        }
    }
    
    private func showBookmarksButtonOnKeyboardIfNeeded() {
        
        guard UserDefaultsRepository.nightscoutUris.value.count > 1 else {
            return
        }
        
        let bookmarkToolbar = UIToolbar(frame:CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 30))
        bookmarkToolbar.barStyle = UIBarStyle.black
        bookmarkToolbar.isTranslucent = true
        bookmarkToolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(toggleKeyboardAndBookmarks))
        ]
        bookmarkToolbar.sizeToFit()
        hostUriTextField.inputAccessoryView = bookmarkToolbar
    }
    
    @objc func toggleKeyboardAndBookmarks() {
        
        if hostUriTextField.inputView != nil {
            hostUriTextField.inputView = nil
        } else {
            hostUriTextField.inputView = uriPickerView
        }
        
        hostUriTextField.reloadInputViews()
        
        // select current URI
        if let index = UserDefaultsRepository.nightscoutUris.value.firstIndex(of: UserDefaultsRepository.baseUri.value) {
            uriPickerView.selectRow(index, inComponent: 0, animated: false)
        }
    }
    
    private func addUriEntryToPickerView(hostUri : String) {
        
        if hostUri == "" {
            // ignore empty values => don't add them to the history of Uris
            return
        }
        
        var nightscoutUris = UserDefaultsRepository.nightscoutUris.value
        if !nightscoutUris.contains(hostUri) {
            nightscoutUris.insert(hostUri, at: 0)
            nightscoutUris = limitAmountOfUrisToFive(nightscoutUris: nightscoutUris)
            UserDefaultsRepository.nightscoutUris.value = nightscoutUris
            uriPickerView.reloadAllComponents()
            
            showBookmarksButtonOnKeyboardIfNeeded()
        }
    }
    
    private func limitAmountOfUrisToFive(nightscoutUris : [String]) -> [String] {
        var uris = nightscoutUris
        while uris.count > 5 {
            uris.removeLast()
        }
        return uris
    }    
}

extension PrefsViewController: UIPickerViewDelegate {
    
    @objc func numberOfComponentsInPickerView(_ pickerView: UIPickerView) -> Int {
        return 1
    }
    
    @objc func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return UserDefaultsRepository.nightscoutUris.value.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return UserDefaultsRepository.nightscoutUris.value[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        let stringURL = UserDefaultsRepository.nightscoutUris.value[row]
        if let url = URL(string: stringURL) {
            nightscoutURLRow.value = url
            nightscoutURLRow.updateCell()
        }

        self.view.endEditing(true)
    }
}


// Nightscout URL validation rule
fileprivate class RuleValidNightscoutURL: RuleType {
    
    var id: String?
    var validationError: ValidationError
    
    var nightscoutError: Error? {
        didSet {
            validationError = ValidationError(msg: nightscoutError?.localizedDescription ?? "")
        }
    }
    
    //    private let ruleURL = RuleURL()
    
    init() {
        validationError = ValidationError(msg: "")
    }
    
    func isValid(value: URL?) -> ValidationError? {
        
        // NOTE: commented out RuleURL because it has a bug (regexp doesn't allow url port definition)
        //        if let urlError = ruleURL.isValid(value: value) {
        //            return urlError
        //        }
        
        if let _ = self.nightscoutError {
            return validationError
        } else {
            return nil
        }
    }
}

