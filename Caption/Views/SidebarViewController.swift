//
//  SidebarViewController.swift
//  Quick Caption
//
//  Created by Blue on 3/10/19.
//  Copyright © 2019 Bright. All rights reserved.
//

import Cocoa

class SidebarViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet weak var tableView: NSTableView!
    var episodeProjects: [EpisodeProject] = []
    @IBOutlet var contextMenu: NSMenu!
    @IBOutlet weak var visualEffectsView: NSVisualEffectView!


    @IBAction func duplicateClicked(_ sender: Any) {
    }

    @IBAction func deleteAtIndex(_ sender: Any) {
        if tableView.selectedRow >= 0 {
            deleteHelper(row: tableView.selectedRow)
        }
    }

    func deleteHelper(row: Int) {
        let project = episodeProjects[row]
        if project != nil {
            Helper.displayInteractiveSheet(title: "Delete Project", text: "Are you sure you want to delete this project? This will remove all subtitles associated with the video \(project.videoDescription ?? ""). While the video itself won't be deleted from your disk, the deletion of this project and associated subtitles is not recoverable.\n\nIf you would like to preseve a copy of the associated subtitle, cancel the deletion, and export the subtitle as a SRT or FCPXML tile.", firstButtonText: "Delete Project", secondButtonText: "Cancel") { (result) in
                if result {
                    var newRow = row + 1
                    if newRow > self.episodeProjects.count - 1 {
                        newRow = row - 1
                    }
                    if newRow < 0 || self.episodeProjects.count <= 0 {
                        self.addNewProject()
                        newRow = 0
                    }
                    if let id = project.guidIdentifier {
                        Helper.removeFilesUnderURL(urlPath: "~/Library/Caches/com.dim.Caption/audio_thumbnail/\(id)")
                        Helper.removeFilesUnderURL(urlPath: "~/Library/Caches/com.dim.Caption/video_thumbnail/\(id)")
                    }
                    //        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                    if let index = self.episodeProjects.firstIndex(of: project) {
                        self.episodeProjects.remove(at: index)
                        project.player?.pause()
                        project.player?.replaceCurrentItem(with: nil)
                        project.player = nil
                        AppDelegate.subtitleVC()?.dismantleSubtitleVC()
                        AppDelegate.movieVC()?.dismantleOldMovieVC()
                        AppDelegate.movieVC()?.configurateMovieVC()
                        AppDelegate.subtitleVC()?.configurateSubtitleVC()
                        AppDelegate.fontVC()?.dismantleOldFontVC()
                        AppDelegate.fontVC()?.configurateFontVC()
                    }

                    Helper.context?.delete(project)
                    //        tableView.removeRows(at: IndexSet(integer: row), withAnimation: .slideDown)
                    self.tableView.reloadData()
                    self.updateSelectRow(index: self.tableView.selectedRow)

                }
            }
        }
    }

    @IBAction func deleteClicked(sender: Any) {
        let row = tableView.clickedRow
        deleteHelper(row: row)
    }

    static func removeFilesUnderURL(urlPath: String) {
        let cacheURL = (urlPath as NSString).expandingTildeInPath as String

        guard URL(string: cacheURL) != nil else {return}
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: cacheURL)
        } catch {
            print(error)
        }
    }

    @IBAction func exportFCPXMLClicked(_ sender: Any) {
        let episode = episodeProjects[tableView.clickedRow]
        Saver.saveEpisodeToDisk(episode, type: .fcpXML)
    }

    @IBAction func exportSRTClicked(_ sender: Any) {
        let episode = episodeProjects[tableView.clickedRow]
        Saver.saveEpisodeToDisk(episode, type: .srt)
    }

    @IBAction func exportASSClicked(_ sender: Any) {
        let episode = episodeProjects[tableView.clickedRow]
        Saver.saveEpisodeToDisk(episode, type: .ass)
    }

    @IBAction func exportTXTClicked(_ sender: Any) {
        let episode = episodeProjects[tableView.clickedRow]
        Saver.saveEpisodeToDisk(episode, type: .txt)
    }

    func selectActiveContextMenuRow() {
        if tableView.selectedRow != tableView.clickedRow {
            updateSelectRow(index: tableView.clickedRow)
        }
    }

    @IBAction func showInFinderClicked(_ sender: Any) {
        showEpisodeInFinder(row: tableView.clickedRow)
    }

    func showActiveVideoInFinderClicked(_ sender: Any) {
        showEpisodeInFinder(row: tableView.selectedRow)
    }

    func showEpisodeInFinder(row: Int) {
        let episode = episodeProjects[row]
        if let url = episode.videoURL {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: url)])
        }
    }

    @IBOutlet weak var duplicateClicked: NSMenuItem!
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(OSX 10.14, *) {
            self.visualEffectsView.material = .sidebar
        } else {
//            self.visualEffectsView.state = .inactive
            self.visualEffectsView.material = .light
        }
        fetchDBData()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsEmptySelection = false
        tableView.selectionHighlightStyle = .sourceList
    }

    func fetchDBData() {
        do {
            let fetchRequest: NSFetchRequest<EpisodeProject> = EpisodeProject.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]
            episodeProjects = try Helper.context!.fetch(fetchRequest)
        } catch {
            print("Can't fetch persistence store with: \(error)")
        }
        for episode in episodeProjects {
            if episode.guidIdentifier == nil {
                episode.guidIdentifier = NSUUID().uuidString
            }
            episode.addObserver(self, forKeyPath: "videoURL", options: [.new], context: nil)
            episode.addObserver(self, forKeyPath: "thumbnailURL", options: [.new], context: nil)
            episode.addObserver(self, forKeyPath: "videoDescription", options: [.new], context: nil)
        }
        #if DEBUG
        print("Fetch DB data has succeeded.")
        #endif
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let project = object as? EpisodeProject, let index = episodeProjects.firstIndex(of: project) {
            tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
        }
    }

    var firstLaunch = true

    override func viewDidAppear() {
        if (episodeProjects.count == 0) {
            addNewProject()
        }
        if firstLaunch {
            #if DEBUG
            print("Setting selected row to the first row on launch.")
            #endif
            updateSelectRow(index: 0)
            firstLaunch = false
        }
    }

    func addNewProject() {
        let description = NSEntityDescription.entity(forEntityName: "EpisodeProject", in: Helper.context!)
        let episode = EpisodeProject(entity: description!, insertInto: Helper.context!)
        episode.guidIdentifier = NSUUID().uuidString
        episode.creationDate = NSDate()
        episode.modifiedDate = NSDate()
        episode.styleFontShadow = 1
        episodeProjects.append(episode)
        fetchDBData()
        tableView.insertRows(at: IndexSet(integer: 0), withAnimation: .slideDown)
        tableView.reloadData(forRowIndexes: IndexSet(integer: 0), columnIndexes: IndexSet(integer: 0))
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SidebarEpisodeTableCellView"), owner: self) as? SidebarEpisodeTableCellView {
            let episode = episodeProjects[row]
            view.videoFileNameTextField.stringValue = episode.videoDescription ?? "New Project"
            let formatter = DateFormatter.init()
            formatter.dateFormat = "MMM dd, yyyy"
            if let date = episode.modifiedDate as Date? {
                view.lastModifiedDateTextField.stringValue = formatter.string(from: date)
            }
            if let url = episode.thumbnailURL, let image = NSImage(contentsOf: URL(fileURLWithPath: url)) {
                view.episodePreview?.image = image
            } else {
                view.episodePreview?.image = NSImage(named: "bunny")
            }
            return view
        }
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateSelectRow(index: tableView.selectedRow)
    }

    func updateSelectRow(index: Int) {
        Helper.appWindow().makeKeyAndOrderFront(self)
        #if DEBUG
        print("The state of various VCs: \(String(describing: AppDelegate.movieVC())), \(String(describing: AppDelegate.subtitleVC())), \(String(describing: AppDelegate.fontVC()))")
        #endif

        if (AppDelegate.movieVC() == nil || AppDelegate.subtitleVC() == nil || AppDelegate.fontVC() == nil) {
            Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { (timer) in
                #if DEBUG
                print("We're giving loading the row a second try after the timer.")
                self.updateSelectRow(index: index)
                #endif
            }
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)

        if index < 0 {
            return
        }
        for project in episodeProjects {
            if let player = project.player {
                player.pause()
            }
        }
//        AppDelegate.rebuildMovieAndSubVC()
        AppDelegate.subtitleVC()?.dismantleSubtitleVC()
        let project = episodeProjects[index]
//        print("Loading project: \(project)")
        AppDelegate.movieVC()?.dismantleOldMovieVC()
        AppDelegate.movieVC()?.episode = project
        AppDelegate.movieVC()?.configurateMovieVC()
        episodeProjects.swapAt(index, 0)
        tableView.moveRow(at: index, to: 0)
//        tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
//        tableView.reloadData(forRowIndexes: IndexSet(integer: 0), columnIndexes: IndexSet(integer: 0))
        tableView.reloadData(forRowIndexes: IndexSet(integersIn: 0..<episodeProjects.count), columnIndexes: IndexSet(integer: 0))

        AppDelegate.subtitleVC()?.episode = project
        AppDelegate.subtitleVC()?.configurateSubtitleVC()
        AppDelegate.fontVC()?.dismantleOldFontVC()
        AppDelegate.fontVC()?.episode = project
        AppDelegate.fontVC()?.configurateFontVC()
        #if DEBUG
        print("Selected: \(project)")
        #endif
    }

    func sortLocalArrayCache() {
        episodeProjects.sort { (ep1, ep2) -> Bool in
            if let m1 = ep1.modifiedDate, let m2 = ep2.modifiedDate {
                return m1.compare(m2 as Date) == ComparisonResult.orderedDescending
            }
            return false
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if row < 0 {
            return false
        }
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return episodeProjects.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 66
    }

    
    
}
