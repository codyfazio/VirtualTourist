//
//  Pin.swift
//  VirtualTourist
//
//  Created by Cody Fazio on 6/15/15.
//  Copyright (c) 2015 Cody Fazio. All rights reserved.
//

import Foundation
import CoreData
import MapKit

@objc(Pin)

class Pin : NSManagedObject, MKAnnotation {
    
    // Used to get info from Flickr response to create our Photo objects
    struct Keys {
        
        static let Name = "name"
        static let Latitude = "latitude"
        static let Longitude = "longitude"
    }
    
    // Managed variables that work in conjuction with our Data Model attributes
    @NSManaged var name : String
    @NSManaged var latitude : NSNumber
    @NSManaged var longitude : NSNumber
    @NSManaged var totalPages : NSNumber?
    @NSManaged var currentPage : NSNumber?
    @NSManaged var photos : [Photo]?
    
    // Standard init when using Core Data
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    // Photo object init with support for our managedObjectContext
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    
        name = dictionary[Keys.Name] as! String
        latitude = dictionary[Keys.Latitude] as! Double
        longitude = dictionary[Keys.Longitude] as! Double
    }
    
    // Computed property for storing a mapView snapshot of the pin
    var backgroundImageForPhotoCollection : UIImage?{
        
        get {return ImageCache.Caches.imageCache.imageWithIdentifier(name)}
        set {ImageCache.Caches.imageCache.storeImage(newValue, withIdentifier: name) }
    }

    // Computed property that returns a coordinate from two string values
    var coordinate: CLLocationCoordinate2D {
        get {return CLLocationCoordinate2D(latitude: latitude as Double , longitude: longitude as Double) }
        set {self.latitude = newValue.latitude
             self.longitude = newValue.longitude }
        }
    
    

    // Annotation title and subtitle
    var title : String? {
        return name
    }
    var subtitle : String? {
        return ""
    }
}



