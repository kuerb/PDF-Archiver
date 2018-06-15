//
//  FileHandling.swift
//  Archiver
//
//  Created by Julian Kahnert on 29.12.17.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Quartz
import os.log

func getOpenPanel(_ title: String) -> NSOpenPanel {
    let openPanel = NSOpenPanel()
    openPanel.title = title
    openPanel.showsResizeIndicator = false
    openPanel.showsHiddenFiles = false
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.canCreateDirectories = true
    return openPanel
}

func convertToPDF(_ inPath: URL) -> URL {
    // ATTENTION: this function needs access to the filesystem security scope

    // Create an empty PDF document
    let pdfDocument = PDFDocument()

    // Create a PDF page instance from the image
    let image = NSImage(byReferencing: inPath)
    let pdfPage = PDFPage(image: image)

    // Insert the PDF page into your document
    pdfDocument.insert(pdfPage!, at: 0)

    // get the output path and save the pdf document
    var outPath = inPath
    outPath.deletePathExtension()
    outPath = outPath.appendingPathExtension("pdf")
    pdfDocument.write(to: outPath)

    // trash old pdf
    let fileManager = FileManager.default
    do {
        try fileManager.trashItem(at: inPath, resultingItemURL: nil)
    } catch let error {
        let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "convertToPDF")
        os_log("Can not trash file: %@", log: log, type: .debug, error.localizedDescription)
    }

    return outPath
}

func getAllFiles(_ url: URL) -> [URL] {
    var files = [URL]()

    if url.hasDirectoryPath {
        // folder found
        let enumerator = FileManager.default.enumerator(atPath: url.path)!
        for element in enumerator {
            if let filename = element as? String {
                let completeDocumentPath = URL(fileURLWithPath: url.path).appendingPathComponent(filename)
                files.append(completeDocumentPath)
            }
        }

    } else if url.isFileURL {
        // pdf file found
        files.append(url)
    }

    return files
}

func getPDFs(url: URL) -> [URL] {
    // get all files in folder
    let files = getAllFiles(url)

    var pdfURLs = [URL]()
    for file in files {
        if file.pathExtension == "pdf" {
            // add PDF
            pdfURLs.append(file)

        } else if let fileTypeIdentifier = file.typeIdentifier,
            NSImage.imageTypes.contains(fileTypeIdentifier) {
            // convert picture/supported file to PDF
            let pdfURL = convertToPDF(file)
            pdfURLs.append(pdfURL)

        } else {
            // skip the unsupported filetype
            continue
        }
    }

    return files
}