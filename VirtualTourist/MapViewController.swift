//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Cody Fazio on 6/9/15.
//  Copyright (c) 2015 Cody Fazio. All rights reserved.
//

import UIKit
import CoreData
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
    
    // Create storyboard reference to our mapview
    @IBOutlet weak var mapView: MKMapView!
    
    // Create global variables
    var imageForPhotoCollectionBackground : UIImage?
    var currentPin : Pin!
   
    // Create reference to a sharedContext for dealing with Core Data managed objects
    lazy var sharedContext = {
        CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
    
    func applicationDirectoryPath() -> String {
        return NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).last! 
    }
    
    // VIEW LIFECYCLE
    override func viewDidLoad() {
        super.viewDidLoad()
    
        //Set the mapView delegate to self
        mapView.delegate = self
    
        //Set up gesture recognizer for long presses
        handleLongPress()
        
        //Set fetchResultsController delegate to self so we can monitor changes
        fetchedResultsController.delegate = self
        
        do {
            //Get data from CoreData relating to our Pin entity
            try fetchedResultsController.performFetch()
        } catch _ {
        }
        
        // Gets the last viewed mapRegion from NSUserDefaults and sets the map to those specs
        restoreMapRegion()
        
        let path = applicationDirectoryPath()
        print(path)
    
    }
    
    // VIEW LIFECYCLE
    override func viewWillAppear(animated: Bool) {
                // Removes all annotations from the map and repopulates with
        refreshAnnotations()
        
        // Hide navigation bar
        self.navigationController?.navigationBarHidden = true
        self.navigationController?.toolbarHidden = true 
    }
    
    // Build our fetchedResultsController with appropriate entity and context
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        return fetchedResultsController
    }()
    
    // Sets up our mapView for handling long presses
    func handleLongPress() {
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: "createPin:")
        longPressRecognizer.delegate = self
        longPressRecognizer.numberOfTapsRequired = 0
        longPressRecognizer.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPressRecognizer)
    }
    
    // Got some awesome help here getting the location back from the touch and dropping the pin
    // http://stackoverflow.com/questions/3959994/how-to-add-a-push-pin-to-a-mkmapviewios-when-touching/29466391#29466391
    
    // When a long press is detected, createPin is called to get the pin's location on the screen, get the appropriate map coordinates from the point, reverse geocode the coordinates to find the name (or address) that coresponds to the coordinates, creates a new pin object from the information, begans the initial photo fetch, and saves it all in our context
    func createPin (recognizer : UIGestureRecognizer) {
        if recognizer.state != .Began {return}
        let pressLocation = recognizer.locationInView(self.mapView)
        let pressLocationCoordinate = mapView.convertPoint(pressLocation, toCoordinateFromView: mapView)
        
        let latitude = pressLocationCoordinate.latitude
        let longitude = pressLocationCoordinate.longitude
        let coordinates = CLLocation(latitude: latitude, longitude: longitude)
        print(coordinates)
        
        var name = ""
        var geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(coordinates, completionHandler: {(placemarks, error) -> Void in
            let placeArray = placemarks! as [CLPlacemark]
            
            var placeMark: CLPlacemark!
            placeMark = placeArray[0]
            print(placeMark)
            name = placeMark.addressDictionary!["Name"] as! String
            if let dictionary = self.createDictionaryForPin(pressLocationCoordinate, name: name) {
                let newPin = Pin(dictionary: dictionary, context: self.sharedContext)
                FlickrClient.sharedInstance().getPhotosForPin(newPin)
                CoreDataStackManager.sharedInstance().saveContext()
                }
            })
        }
    
    // Creates a dictionary to pass when creating our pin instance
    func createDictionaryForPin(coordinate: CLLocationCoordinate2D, name : String) -> [String : AnyObject]? {
        
        let dictionary : [String : AnyObject] = [
            "latitude" : coordinate.latitude,
            "longitude" : coordinate.longitude,
            "name" : name
        ]
        return dictionary
    }
    

    // MAPKIT FUNCTIONS
    
    // Monitors the mapView. When the region changes, the new information is saved to NSUserDefaults
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        let mapRegion = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]

        NSUserDefaults.standardUserDefaults().setObject(mapRegion, forKey: "mapRegion")
        

    }
    
    // Sets up a custom view for pin annotations
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView! {
        
        if let annotation = annotation as? Pin {
            let identifier = "pin"
            var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? MKPinAnnotationView
            
            if pinView == nil {
                pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                pinView!.canShowCallout = true
                pinView!.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
                pinView!.animatesDrop = true
                
                
            }
            else {
                pinView!.annotation = annotation
            }
            return pinView
        }
        return nil
    }
    
    
    // This was adapted from the MapKit example on Udacity
    // This delegate method is implemented to respond to taps. It calls takeMapSnapshot to take a screenshot of the current mapView, then storeImage from ImageCache to save the image to disk and in cache, and then presents the photoCollectionView through its navigation controller.
    
    func mapView(mapView: MKMapView, annotationView: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        currentPin = annotationView.annotation as! Pin
        if currentPin.totalPages == 0 {
            let alertView = UIAlertController(title: "No images found.", message: "Please try another location!", preferredStyle: .Alert)
            alertView.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
            self.presentViewController(alertView, animated: true, completion: nil)

        } else  {
        takeMapSnapshot(currentPin) {(success, image, errorString) in
            
            if success {
                
                ImageCache.sharedInstance().storeImage(image, withIdentifier: self.currentPin.name)
                if control == annotationView.rightCalloutAccessoryView {
                    dispatch_async(dispatch_get_main_queue(),{
                        
                        let controller = self.storyboard!.instantiateViewControllerWithIdentifier("PhotoViewController") as! PhotoViewController
                        controller.pin = self.currentPin
                        self.navigationController!.pushViewController(controller, animated: true)
                    })
                }
            } else {
                print(errorString)
            }
        }
        }
    }
    
    // Hopefully I don't get dinged for it, but after some thought I decide to just
    // show a screenshot of my mapview behind the photoCollectionView. I found a create
    // article about MKMapSnapshotter here that really helped! http://awesomism.co.uk/using-mkmapsnapshotter-with-mkpolygon-and-swift/
    
    func takeMapSnapshot(pin: Pin, completionHandler: (success: Bool, image : UIImage?, errorString: String?) -> Void) {
        
        var image : UIImage?
        var snapshotterOptions = MKMapSnapshotOptions()
        snapshotterOptions.region = mapView.region
        snapshotterOptions.scale = UIScreen.mainScreen().scale
        snapshotterOptions.size = mapView.frame.size
        
        var snapshotter = MKMapSnapshotter(options: snapshotterOptions)
        snapshotter.startWithCompletionHandler() {snapshot, error in
            
            if (error != nil) {
                completionHandler(success: false, image : nil , errorString: error!.localizedDescription)
            } else {
                
                image = snapshot!.image
                completionHandler(success: true, image: image! , errorString: nil)
            }
        }
    }

    // Checks to see if we have saved data to NSUserDefaults. If so, it sets our map region to its last known state.
    func restoreMapRegion() {
        if let regionDictionary = NSUserDefaults.standardUserDefaults().objectForKey("mapRegion") as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2DMake(latitude, longitude)
            
            let latitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let longitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpanMake(latitudeDelta, longitudeDelta)
            
            mapView.setRegion(MKCoordinateRegionMake(center,span), animated: true)
            }
        }
    class func sharedInstance() -> MapViewController {
        struct Singleton {
            static var sharedInstance = MapViewController()
        }
        return Singleton.sharedInstance
        }
    }

    //MapKit related fetchedResultsController functions
    extension MapViewController :  NSFetchedResultsControllerDelegate {
        
       
        func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
            let pin = anObject as! Pin
            
            switch(type) {
            case NSFetchedResultsChangeType.Insert:
                // Create Annotation
                mapView.addAnnotation(pin)
                
            case NSFetchedResultsChangeType.Delete:
                // Delete Annotation
                mapView.removeAnnotation(pin)
                
            case NSFetchedResultsChangeType.Update:
                
                print("Still need to hande update case in FetchedResultsChangeType switch")
                //Do something here to update our annotation!!!!
                
                
            case NSFetchedResultsChangeType.Move:
                break
                
            default:
                break
            }

        }
        
        
        // Called to clean up the map, it removes all annotations and repopulates the map with those saved to our context
        func refreshAnnotations() {
            let annotations = mapView.annotations
            mapView.removeAnnotations(annotations)
            mapView.addAnnotations(fetchedResultsController.fetchedObjects as! [MKAnnotation])
        }
}
       