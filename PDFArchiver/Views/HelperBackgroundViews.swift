//
//  MainView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.09.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa
import Quartz.PDFKit.PDFView
import Foundation

class BackgroundView: NSView {

    override func layout() {
        super.layout()

        // set background color of the view
        self.wantsLayer = Constants.Layout.wantsLayer
        self.layer?.cornerRadius = Constants.Layout.cornerRadius
        if self.identifier?.rawValue == "MainViewBackground" || self.identifier?.rawValue == "OnboardingBackgroundView" {
            self.layer?.backgroundColor = CGColor.init(red: 239/255, green: 239/255, blue: 239/255, alpha: 1)
        } else if self.identifier?.rawValue == "CustomViewBackground" {
            self.layer?.backgroundColor = NSColor(named: "CustomViewBackground")!.withAlphaComponent(0.1).cgColor
        }
    }
}

class PDFContentView: PDFView {

    override func layout() {
        super.layout()

        // set background color of the view
        self.backgroundColor = NSColor.underPageBackgroundColor
        self.layer?.cornerRadius = Constants.Layout.cornerRadius
        
    
    }
    
    
}
