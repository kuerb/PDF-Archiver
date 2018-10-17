//
//  Preferences.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import os.log

protocol PreferencesDelegate: class {
    var archivePath: URL? { get set }
    var observedPath: URL? { get set }
    var namingScheme: String? { get set }
    var tagDelimiter: String? { get set }
    var archiveModificationDate: Date? { get set }

    var slugifyNames: Bool { get set }
    var lowercaseTags: Bool { get set }
    var useiCloudDrive: Bool { get set }
    var iCloudDrivePath: URL? {get}
    var analyseAllFolders: Bool { get set }
    var convertPictures: Bool { get set }
    var advancedSettings: Bool { get set }
    
    func accessSecurityScope(closure: () -> Void)
    func save()
}

class Preferences: PreferencesDelegate, Logging {
    fileprivate var _archivePath: URL?
    fileprivate var _observedPath: URL?
    private(set) var iCloudDrivePath = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    weak var dataModelTagsDelegate: DataModelTagsDelegate?
    weak var archiveDelegate: ArchiveDelegate?
    var namingScheme: String?
    var tagDelimiter: String?
    var archiveModificationDate: Date?
    var slugifyNames: Bool = true
    var lowercaseTags: Bool = true
    var advancedSettings: Bool = false
    var useiCloudDrive: Bool = false {
        didSet {

            if let iCloudDrivePath = self.iCloudDrivePath,
                self.useiCloudDrive {
                // move archive files
                self.accessSecurityScope {
                    self.archiveDelegate?.moveArchivedDocuments(from: self._archivePath!, to: iCloudDrivePath)
                }

                // create icloud container
                if !FileManager.default.fileExists(atPath: iCloudDrivePath.path) {
                    do {
                        try FileManager.default.createDirectory(at: iCloudDrivePath, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        print(error.localizedDescription)
                    }
                }

                // save the icloud drive container path as the archive
                self.archivePath = iCloudDrivePath
            }

            // update documents
            self.archiveDelegate?.updateDocumentsAndTags()
        }
    }
    var analyseAllFolders: Bool = false {
        didSet {
            self.archiveDelegate?.updateDocumentsAndTags()
        }
    }
    var convertPictures: Bool = false {
        didSet {
            if let observedPath = self.observedPath {
                self.dataModelTagsDelegate?.addUntaggedDocuments(paths: [observedPath])
            }
        }
    }
    var observedPath: URL? {
        // ATTENTION: only set observed path, after an OpenPanel dialog
        get {
            return self._observedPath
        }
        set {
            guard let newValue = newValue else { return }
            // save the security scope bookmark [https://stackoverflow.com/a/35863729]
            do {
                let bookmark = try newValue.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "observedPathWithSecurityScope")
            } catch let error as NSError {
                os_log("Observed path bookmark Write Fails: %@", log: self.log, type: .error, error.description)
            }
            self._observedPath = newValue

            // update the untagged documents
            self.dataModelTagsDelegate?.addUntaggedDocuments(paths: [newValue])
        }
    }
    var archivePath: URL? {
        // ATTENTION: only set archive path, after an OpenPanel dialog
        get {
            return self.useiCloudDrive ? self.iCloudDrivePath : self._archivePath
        }
        set {
            guard let newValue = newValue else { return }

            // move archive files
            if let iCloudDrivePath = self.iCloudDrivePath {
                self.accessSecurityScope {
                    self.archiveDelegate?.moveArchivedDocuments(from: iCloudDrivePath, to: newValue)
                }
            }

            // save the security scope bookmark [https://stackoverflow.com/a/35863729]
            do {
                let bookmark = try newValue.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "securityScopeBookmark")
            } catch let error as NSError {
                os_log("Bookmark Write Fails: %@", log: self.log, type: .error, error.description)
            }
            self._archivePath = newValue

            // update the tags in archive
            DispatchQueue.global().async {
                self.archiveDelegate?.updateDocumentsAndTags()
            }
        }
    }
    

    init() {
        // load preferences - didSet methods will not be called in init
        self.load()
    }

    func save() {
        // there is no need to save the archive/observed path here - see the setter of the variable

        // save the last tags (with count > 0)
        var tags: [String: Int] = [:]
        for tag in self.dataModelTagsDelegate?.getTagList() ?? Set<Tag>() {
            tags[tag.name] = tag.count
        }
        for (name, count) in tags where count < 1 {
            tags.removeValue(forKey: name)
        }
        UserDefaults.standard.set(tags, forKey: "tags")

        // save the namingScheme string
        UserDefaults.standard.set(self.namingScheme, forKey: "namingScheme")
        
        // save the tagDelimiter string
        UserDefaults.standard.set(self.tagDelimiter, forKey: "tagDelimiter")
        
        // save the slugifyNames flag
        UserDefaults.standard.set(!(self.slugifyNames), forKey: "noSlugify")
        
        // save the lowercaseTags flag
        UserDefaults.standard.set(self.lowercaseTags, forKey: "lowercaseTags")

        // save the analyseOnlyLatestFolders flag
        UserDefaults.standard.set(self.analyseAllFolders, forKey: "analyseOnlyLatestFolders")

        // save the convertPictures flag
        UserDefaults.standard.set(self.convertPictures, forKey: "convertPictures")

        // save the archive modification date
        if let date = self.archiveModificationDate {
            UserDefaults.standard.set(date, forKey: "archiveModificationDate")
        }

        // save the useiCloudDrive flag
        UserDefaults.standard.set(self.useiCloudDrive, forKey: "useiCloudDrive")
        
        // save the AdvancedSettings flag
        UserDefaults.standard.set(self.advancedSettings, forKey: "advancedSettings")
    }

    func load() {
        // load the archive path via the security scope bookmark [https://stackoverflow.com/a/35863729]
        self._archivePath = self.getBookmarkSecurityScope(scopeBookmarkName: "securityScopeBookmark")

        // load the observed path via the security scope bookmark [https://stackoverflow.com/a/35863729]
        self._observedPath = self.getBookmarkSecurityScope(scopeBookmarkName: "observedPathWithSecurityScope")

        // load archive tags
        guard let tagsDict = (UserDefaults.standard.dictionary(forKey: "tags") ?? [:]) as? [String: Int] else { return }
        var newTagList = Set<Tag>()
        for (name, count) in tagsDict {
            newTagList.insert(Tag(name: name, count: count))
        }
        self.dataModelTagsDelegate?.setTagList(tagList: newTagList)

        // load the namingScheme string
        self.namingScheme = UserDefaults.standard.string(forKey: "namingScheme")
        
        // load the tagDelimiter string
        self.tagDelimiter = UserDefaults.standard.string(forKey: "tagDelimiter")
        
        // load the noSlugify flag
        self.slugifyNames = !(UserDefaults.standard.bool(forKey: "noSlugify"))
        
        // load the lowercaseTags flag
        self.lowercaseTags = UserDefaults.standard.bool(forKey: "lowercaseTags")

        // load the analyseOnlyLatestFolders flag
        self.analyseAllFolders = UserDefaults.standard.bool(forKey: "analyseOnlyLatestFolders")

        // load the convertPictures flag
        self.convertPictures = UserDefaults.standard.bool(forKey: "convertPictures")

        // load the archive modification date
        if let date = UserDefaults.standard.object(forKey: "archiveModificationDate") as? Date {
            self.archiveModificationDate = date
        }

        // load the useiCloudDrive flag
        self.useiCloudDrive = UserDefaults.standard.bool(forKey: "useiCloudDrive")
        
        
        // load the AdvancedSettings flag
        self.advancedSettings = UserDefaults.standard.bool(forKey: "advancedSettings")
    }

    func accessSecurityScope(closure: () -> Void) {
        // start accessing the file system
        if !(self._observedPath?.startAccessingSecurityScopedResource() ?? false) {
            os_log("Accessing Security Scoped Resource of the observed path failed.", log: self.log, type: .fault)
        }
        if !(self._archivePath?.startAccessingSecurityScopedResource() ?? false) {
            os_log("Accessing Security Scoped Resource of the archive path failed.", log: self.log, type: .fault)
        }

        // run the used code
        closure()

        // stop accessing the file system
        self._archivePath?.stopAccessingSecurityScopedResource()
        self._observedPath?.stopAccessingSecurityScopedResource()
    }

    // MARK: private functions

    fileprivate func getBookmarkSecurityScope(scopeBookmarkName: String) -> URL? {
        // load the archive path via the security scope bookmark [https://stackoverflow.com/a/35863729]
        if let bookmarkData = UserDefaults.standard.object(forKey: scopeBookmarkName) as? Data {
            do {
                var staleBookmarkData = false
                let bookmarkPath = try URL.init(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
                if staleBookmarkData {
                    os_log("Stale bookmark data!", log: self.log, type: .fault)
                }
                return bookmarkPath
            } catch let error as NSError {
                os_log("Bookmark Access failed: %@", log: self.log, type: .error, error.description)
            }
        }
        return nil
    }

    fileprivate func archiveModified() -> Bool {
        if let archivePath = self.archivePath,
           let archiveModificationDate = self.archiveModificationDate {
            let fileManager = FileManager.default
            var newArchiveModificationDate: Date?
            do {
                // get the attributes of the current archive folder
                let attributes = try fileManager.attributesOfItem(atPath: archivePath.path)
                newArchiveModificationDate = attributes[FileAttributeKey.modificationDate] as? Date
            } catch let error {
                os_log("Folder not found: %@ \nUpdate tags anyway.", log: self.log, type: .debug, error.localizedDescription)
            }

            // compare dates here
            if let newArchiveModificationDate = newArchiveModificationDate,
                archiveModificationDate == newArchiveModificationDate {
                os_log("No changes in archive folder, skipping tag update.", log: self.log, type: .debug)
                return false

            } else {
                os_log("Changes in archive folder detected, update tags.", log: self.log, type: .debug)
                return true
            }
        }

        os_log("Archive path (%@) or modification date (%@) not found!", log: self.log, type: .debug, self.archivePath?.description ?? "", self.archiveModificationDate?.description ?? "")
        return true
    }
}
