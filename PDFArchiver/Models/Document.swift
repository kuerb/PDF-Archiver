//
//  Document.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 25.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log
import Cocoa

class Document: NSObject, Logging {
    // structure for PDF documents on disk
    var path: URL
    @objc var name: String
    @objc var documentDone: String {
        return self.alreadyRenamed ? "✔️" : ""
    }
    var headerName: String = ""
    @objc var isHeader = false
    @objc var group = 0
    var alreadyRenamed = false
    var date = Date()
    var prefs = Preferences()
    var specification: String? {
        didSet {
            if self.prefs.slugifyNames {
                self.specification = self.specification?.replacingOccurrences(of: "_", with: "-").lowercased()
            }
        }
    }
//    NSImage *machineIcon = [NSImage imageNamed:NSImageNameComputer]
//    [[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(kToolbarApplicationsFolderIcon)]
//    let image = NSWorkspace.shared.icon(forFile: "/tmp/Test.swift")
//    let image  = NSWorkspace.shared.icon(forFileType:NSFileTypeForHFSTypeCode(OSType(kToolbarApplicationsFolderIcon)))
    
    var documentTags = Set<Tag>()
    init(path: URL, availableTags: inout Set<Tag>) {
        self.path = path

        // create a filename and rename the document
        self.name = String(path.lastPathComponent)

        // try to parse the current filename
        let parser = DateParser()
        var rawDate = ""
        if let parsed = parser.parse(self.name) {
            self.date = parsed.date
            rawDate = parsed.rawDate
        }

        // save a first "raw" specification
        self.specification = path.lastPathComponent
            // drop the already parsed date
            .dropFirst(rawDate.count)
            // drop the extension and the last .
            .dropLast(path.pathExtension.count + 1)
            // exclude tags, if they exist
            .components(separatedBy: "__")[0]
            // clean up all "_" - they are for tag use only!
            .replacingOccurrences(of: "_", with: "-")
            // remove a pre or suffix from the string
            .slugifyPreSuffix()

        // parse the specification and override it, if possible
        if var raw = self.name.capturedGroups(withRegex: "--([\\w\\d-]+)__") {
            self.specification = raw[0]
        }

        // parse the tags from finder (not file name)
        var resource : AnyObject?
        do {
            try (self.path as NSURL).getResourceValue(&resource, forKey: URLResourceKey.tagNamesKey)
            var fileTags : [String]
            if resource == nil {
                fileTags = [String]()
            } else {
                fileTags = resource as! [String]
            }
            
            let documentTagNames = fileTags
            
            // get the available tags of the archive
            for documentTagName in documentTagNames {
                if let availableTag = availableTags.filter({$0.name == documentTagName}).first {
                    availableTag.count += 1
                    self.documentTags.insert(availableTag)
                } else {
                    let newTag = Tag(name: documentTagName, count: 1)
                    availableTags.insert(newTag)
                    self.documentTags.insert(newTag)
                }
            }
        } catch let error as NSError {
            os_log("Error while parsing tags: %@", type: .error, error.description)
        }
        
    }
    init(headerName: String, group: NSInteger){
        path = NSURL(string:"")! as URL
        name=headerName
        isHeader=true
        self.group=group
    }
    @discardableResult
    func rename(archivePath: URL, slugify: Bool) -> Bool {
        let foldername: String
        let filename: String
        do {
            (foldername, filename) = try getRenamingPath(slugifyName: slugify)
        } catch {
            return false
        }

        // check, if this path already exists ... create it
        let newFilepath = archivePath
            .appendingPathComponent(foldername)
            .appendingPathComponent(filename)
        let fileManager = FileManager.default
        do {
            let folderPath = newFilepath.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: folderPath.path) {
                try fileManager.createDirectory(at: folderPath, withIntermediateDirectories: true, attributes: nil)
            }

            // test if the document name already exists in archive, otherwise move it
            if fileManager.fileExists(atPath: newFilepath.path),
               self.path != newFilepath {
                os_log("File already exists!", log: self.log, type: .error)
                dialogOK(messageKey: "renaming_failed", infoKey: "file_already_exists", style: .warning)
                return false
            } else {
                try fileManager.moveItem(at: self.path, to: newFilepath)
            }
        } catch let error as NSError {
            os_log("Error while moving file: %@", log: self.log, type: .error, error.description)
            dialogOK(messageKey: "renaming_failed", infoKey: error.localizedDescription, style: .warning)
            return false
        }
        self.name = String(newFilepath.lastPathComponent)
        self.path = newFilepath
        self.alreadyRenamed = true
        self.group = -1 //set -1 as "done"

        do {
            var tags = [String]()
            for tag in self.documentTags {
                tags += [tag.name]
            }

            // set file tags [https://stackoverflow.com/a/47340666]
            try (newFilepath as NSURL).setResourceValue(tags, forKey: URLResourceKey.tagNamesKey)
        } catch let error as NSError {
            os_log("Could not set file: %@", log: self.log, type: .error, error.description)
        }
        return true
    }

    internal func getRenamingPath(slugifyName: Bool) throws -> (foldername: String, filename: String) {
        // reload Preferences
        prefs=Preferences()
        let addTagsToFileName=(self.prefs.namingScheme?.range(of: "{TAGS}") != nil) ? true : false;
        // create a filename and rename the document
        guard  !addTagsToFileName || self.documentTags.count > 0 else {
            dialogOK(messageKey: "renaming_failed", infoKey: "check_document_tags", style: .warning)
            throw DocumentError.tags
        }
        guard var specification = self.specification,
              specification != "" else {
            dialogOK(messageKey: "renaming_failed", infoKey: "check_document_description", style: .warning)
            throw DocumentError.description
        }

        // get formatted date
        let dateFormatter = DateFormatter()
            // this feels overwhelming
        dateFormatter.dateFormat = "yyyy"
        let dateYYYY = dateFormatter.string(from: self.date)
        dateFormatter.dateFormat = "yy"
        let dateYY = dateFormatter.string(from: self.date)
        dateFormatter.dateFormat = "MM"
        let dateMM = dateFormatter.string(from: self.date)
        dateFormatter.dateFormat = "dd"
        let dateDD = dateFormatter.string(from: self.date)
        // get description
        if slugifyName {
            specification = specification.slugify()
        }

        // reload preferences
        prefs = Preferences()
        
        // get tags
        var tagStr = ""
        for tag in Array(self.documentTags).sorted(by: { $0.name < $1.name }) {
            tagStr += "\(tag.name)"
            if let tagDelim=self.prefs.tagDelimiter {
                tagStr += tagDelim
            }
        }
        tagStr = String(tagStr.dropLast(1))

        // create new filepath
        var filename = self.prefs.namingScheme! + ".pdf"
        os_log("Naming Scheme is: %@", log: self.log, type: .info, filename)
        
        // replace template tokens // there has to be a better way
        filename = filename.replacingOccurrences(of: "{YYYY}", with: dateYYYY)
        filename = filename.replacingOccurrences(of: "{YY}", with: dateYY)
        filename = filename.replacingOccurrences(of: "{MM}", with: dateMM)
        filename = filename.replacingOccurrences(of: "{DD}", with: dateDD)
        filename = filename.replacingOccurrences(of: "{DESCR}", with: specification)
        filename = filename.replacingOccurrences(of: "{TAGS}", with: tagStr)
        // if {TAGS(*)}
        
        os_log("Filename preview: %@", log: self.log, type: .info, filename)
        
        
        var foldername = dateYYYY
        
        //switch up folder name if tags contain Rechnung //use Mail-like rules in the future
        if prefs.advancedSettings && Array(self.documentTags).contains(where: {$0.name.lowercased()=="rechnung"}){ //Check tags
            
            foldername = "Rechnungen" //input additional folder
            
            if Array(self.documentTags).contains(where: {$0.name.lowercased()=="steuer"}){
                foldername += "/Steuerjahr "+dateYYYY
            }else{
                foldername += "/Andere"
            }
            
        }
        //END FORCED SWITCH OF RECHNUNGEN
        
        return (foldername, filename)
    }

    // MARK: - Other Stuff
    override var description: String {
        return "<Document \(self.name)>"
    }
}

enum DocumentError: Error {
    case description
    case tags
}
