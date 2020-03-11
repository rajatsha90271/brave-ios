// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import UIKit
import CoreData
import Shared

private let log = Logger.browserLogger

class Playlist {
    static let shared = Playlist()
    private let dbLock = NSRecursiveLock()
    
    func addItem(item: PlaylistInfo) {
        if !self.itemExists(item: item) {
            self.backgroundContext.perform { [weak self] in
                guard let self = self else { return }

                let playlistItem = PlaylistItem(context: self.backgroundContext)
                playlistItem.title = item.title
                playlistItem.pageURL = item.pageURL
                playlistItem.dateAdded = Date()
                playlistItem.blob = Data()
                
                try? self.backgroundContext.save()
            }
        }
    }
    
    func removeItem(item: PlaylistInfo) {
        if !self.itemExists(item: item) {
            self.backgroundContext.perform { [weak self] in
                guard let self = self else { return }
                
                let hash = PlaylistItem(context: self.backgroundContext)
                
            }
        }
    }
    
    func getItems() -> [PlaylistInfo] {
        let request: NSFetchRequest<PlaylistItem> = PlaylistItem.fetchRequest()
        return (try? self.mainContext.fetch(request))?.map({
            return PlaylistInfo(title: $0.title, mediaSource: $0.pageURL)
        }) ?? []
    }
    
    func itemExists(item: PlaylistInfo) -> Bool {
        let request: NSFetchRequest<PlaylistItem> = PlaylistItem.fetchRequest()
        request.predicate = NSPredicate(format: "pageURL == %@", item.pageURL)
        return ((try? self.mainContext.count(for: request)) ?? 0) > 0
    }
    
    func getPlaylistCount() -> Int {
        let request: NSFetchRequest<PlaylistItem> = PlaylistItem.fetchRequest()
        return (try? self.mainContext.count(for: request)) ?? 0
    }
    
    
    private init() {
        self.mainContext.reset()
    }
    
    private lazy var persistentContainer: NSPersistentContainer = {
        return self.create()
    }()
    
    private lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    
    private lazy var mainContext: NSManagedObjectContext = {
        let context = persistentContainer.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    private func save() {
        saveContext(mainContext)
    }
    
    private func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                log.error("Error Saving Context: \(error)")
            }
        }
    }
    
    // MARK: - CoreData Stack
    
    private lazy var cachedPersistentContainer = {
        return NSPersistentContainer(name: "Playlist")
    }()
    
    private func create() -> NSPersistentContainer {
        dbLock.lock(); defer { dbLock.unlock() }
        
        cachedPersistentContainer.loadPersistentStores(completionHandler: { [weak self] (storeDescription, error) in
            guard let self = self else { return }
            
            if error != nil {
                self.destroy()
                
                self.cachedPersistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
                    if let error = error as NSError? {
                        fatalError("Playlist Load persistent store error: \(error)")
                    }
                })
            }
        })
        return cachedPersistentContainer
    }
    
    private func destroy() {
        dbLock.lock(); defer { dbLock.unlock() }
        
        cachedPersistentContainer.persistentStoreDescriptions.forEach({
            try? cachedPersistentContainer.persistentStoreCoordinator.destroyPersistentStore(at: $0.url!, ofType: NSSQLiteStoreType, options: nil)
        })
    }
}
