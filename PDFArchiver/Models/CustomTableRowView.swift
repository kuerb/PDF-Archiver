//
//  CustomTableRowView.swift
//  PDFArchiver
//
//  Created by on 18.10.18.
//
//

import Cocoa

class CustomTableRowView: NSTableRowView {
    override var isEmphasized: Bool {
        set {}
        get {
            return false;
        }
    }
}

//
class CustomScroller: NSScroller   {

    override func draw(_ dirtyRect: NSRect) {
       // the only line is required
        drawKnob()
    }
}
