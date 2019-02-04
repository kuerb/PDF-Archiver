//
//  WindowController.swift
//  Archiver
//
//  Created by Julian Kahnert on 05.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {
    var dataModelInstance = DataModel()
    
    override func windowDidLoad() {
        super.windowDidLoad()

        // restore the window position, e.g. https://stackoverflow.com/a/49205940
        self.windowFrameAutosaveName = "MainWindowPosition"
    }

    @IBAction func browseFile(sender: AnyObject) {
        let openPanel = getOpenPanel("Choose an observed folder")
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            guard response == NSApplication.ModalResponse.OK else { return }
            self.dataModelInstance.prefs.observedPath = openPanel.url!
            self.dataModelInstance.addUntaggedDocuments(paths: openPanel.urls)
        }
    }
}
