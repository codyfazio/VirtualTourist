//
//  Photo.swift
//  VirtualTourist
//
//  Created by Cody Fazio on 6/15/15.
//  Copyright (c) 2015 Cody Fazio. All rights reserved.
//

import Foundation
import CoreData
import UIKit

@objc(Photo)

class Photo : NSManagedObject {
    
    // Used to get info from Flickr response to create our Photo objects
    struct Keys {
        
        static let URL = "url_m"
        static let ID = "id"
        static let Title = "title"
    }
    
    // Managed variables that work in conjuction with our Data Model attributes
    @NSManaged var url_m : String
    @NSManaged var id : String
    @NSManaged var title : String
    @NSManaged var pin : Pin?
    @NSManaged var downloadedPhoto : UIImage?
    
    // Standard init when using Core Data
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context : NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    // Photo object init with support for our managedObjectContext
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        url_m = dictionary[Keys.URL] as! String
        id = dictionary[Keys.ID] as! String
        title = dictionary[Keys.Title] as! String
    
    }
    
    // Computed property that stores our retrieved image in cache and on disk
    var photoImage: UIImage? {
        
        get {return ImageCache.Caches.imageCache.imageWithIdentifier(url_m.lastPathComponent)}
        set {ImageCache.Caches.imageCache.storeImage(newValue, withIdentifier: url_m.lastPathComponent) }
    }
    
    
    // I found this lifesaving function in the NSManagedObject documentation. Just what I need to remove the cache! When CoreData signals its about to delete a photo object, it calls prepareForDeletion. Here, we use NSFileManager to check for a cached image. If it exists, we delete it. 
    override func prepareForDeletion() {
        let fileManager = NSFileManager.defaultManager()
        var cachedImagePath = ImageCache.Caches.imageCache.pathForIdentifier(url_m.lastPathComponent)
        
    
        if fileManager.fileExistsAtPath(cachedImagePath) {
            var error: NSError? = nil
            fileManager.removeItemAtPath(cachedImagePath, error: &error)
            if let error = error {
                println("Cached image could not be deleted.")
                println(error)
            }
        }
        
    }
    
}
