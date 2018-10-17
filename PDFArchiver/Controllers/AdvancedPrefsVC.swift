//
//  AdvancedPrefsVC.swift
//  PDFArchiver
//
//  Created on 04.10.18.
//
//

import Cocoa

class AdvancedPrefsVC: MainPreferencesVC { //Keeping at PreferecesVC won't connect the delegate?!
    //weak var preferencesDelegate: PreferencesDelegate?
    //weak var viewControllerDelegate: ViewControllerDelegate?
    
    @IBOutlet weak var advancedSettingsButton: NSButton!
    
    @IBAction func advancedSettingsClicked(_ sender: NSButton) {
        self.preferencesDelegate?.advancedSettings = sender.state == .on
    }
    
    override func viewDidLoad() {
        //super.viewDidLoad()
        
        // advancedSettings
        self.advancedSettingsButton.state = (self.preferencesDelegate?.advancedSettings ?? false) ? .on : .off
        
    }
    
    
    override func viewWillDisappear() {
        
        //save all settings
        self.preferencesDelegate?.save()
    }
}
