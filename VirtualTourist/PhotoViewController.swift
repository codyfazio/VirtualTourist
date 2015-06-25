//
//  PhotoViewController.swift
//  VirtualTourist
//
//  Created by Cody Fazio on 6/16/15.
//  Copyright (c) 2015 Cody Fazio. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class PhotoViewController : UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    // Create storyboard references
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var photoCollectionView: UICollectionView!
    @IBOutlet weak var barButtonNewCollection: UIBarButtonItem!
  
    // The selected indexes array keeps all of the indexPaths for cells that are "selected". The array is used inside cellForItemAtIndexPath to lower the alpha of selected cells.  You can see how the array works by searchign through the code for 'selectedIndexes'
    var selectedIndexes = [NSIndexPath]()
    
    // Keep the changes. We will keep track of insertions, deletions, and updates.
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    // Create reference to selected pin
    var pin : Pin!
    
    
    // VIEW LIFECYCLE
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set ourselves as delegate and datasource of photoCollectionView and load the collection
        photoCollectionView.delegate = self
        photoCollectionView.dataSource = self
        self.photoCollectionView.reloadData()
       
        // Set ourselves as the delegate for the fetchResultsController and get our initial data from CoreData
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
        
        // Show navigation bar
        self.navigationController?.navigationBarHidden = false
        self.navigationController?.navigationBar.translucent = false
        self.navigationController?.toolbarHidden = false
        updateNewCollectionButton()
        }
    
    override func viewWillAppear(animated: Bool) {
        
        backgroundImageView.image = pin.backgroundImageForPhotoCollection
        if pin.photos!.isEmpty {
            barButtonNewCollection.enabled = false
            getMorePhotos(){success, errorString in
                if success {
                self.barButtonNewCollection.enabled = true
                } else {
                    println(errorString)
                }
            }
        } else {
            self.barButtonNewCollection.enabled = true
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Lay out the collection view so that cells take up 1/3 of the width,
        // with no space in between.
        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let width = floor(self.photoCollectionView.frame.size.width/3)
        layout.itemSize = CGSize(width: width, height: width)
        photoCollectionView.collectionViewLayout = layout
    }
    
    @IBAction func newCollectionButtonPressed(sender: UIBarButtonItem) {
        
        if selectedIndexes.isEmpty {
            deleteAllPhotos()
            barButtonNewCollection.enabled = false 
            getMorePhotos(){success, errorString in
                if success {
                    self.barButtonNewCollection.enabled = true
                } else {
                    println(errorString)
                }
            }

            
        } else {
           deleteSelectedPhotos()
        }
    }
    
    func getMorePhotos(completionHander:(success:Bool, errorString: String?) -> Void) {
        
        var totalPages = Int(pin.totalPages!)
        var currentPage = Int(pin.currentPage!)
        
        if (totalPages > currentPage) {
            pin.currentPage = currentPage + 1
        }
        else if (pin.totalPages == pin.currentPage) {
            pin.currentPage = 1
        }
        FlickrClient.sharedInstance().getPhotosFromFlickrWithPageNumber(pin.latitude.description, longitude: pin.longitude.description, pageNumber: pin.currentPage as! Int) {success, result, errorString in
            
            if success {
                let photosDictionaries = result!
                var photos = photosDictionaries.map() {(dictionary: [String : AnyObject]) -> Photo in
                    var photo = Photo(dictionary: dictionary, context: self.sharedContext)
                    photo.pin = self.pin
                    return photo
                }
                completionHander(success: true, errorString: nil)
            } else {
               completionHander(success: false, errorString: errorString)
            }
        }
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    func updateNewCollectionButton() {
        if selectedIndexes.count > 0 {
            barButtonNewCollection.title = "Remove Selected Photos"
        } else {
            barButtonNewCollection.title = "New Collection"
        }
    }
    
    func deleteAllPhotos() {
        for photo in fetchedResultsController.fetchedObjects as! [Photo] {
            sharedContext.deleteObject(photo)
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
    
    func deleteSelectedPhotos() {
        var photosToDelete = [Photo]()
        
        for indexPath in selectedIndexes {
            photosToDelete.append(fetchedResultsController.objectAtIndexPath(indexPath) as! Photo)
        }
        
        for photo in photosToDelete {
            sharedContext.deleteObject(photo)
        }
        
        selectedIndexes = [NSIndexPath]()
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    // COLLECTION VIEW FUNCTIONS
    
    // Get the number of sections for the collection from fetchedResultsController
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    // Get the number of cells from fetchedResultsController
     func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        // println("Number of cells: \(sectionInfo.numberOfObjects)")
        return sectionInfo.numberOfObjects
    }
    
    // Get the data for each individual cell, configure the cell and display it
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("photoCollectionCell", forIndexPath: indexPath) as! PhotoCollectionCell
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        let cell = photoCollectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionCell
        
        // Whenever a photo is tapped we will toggle its presence in the selectedIndexes array
        if let index = find(selectedIndexes, indexPath) {
            selectedIndexes.removeAtIndex(index)
        } else {
            selectedIndexes.append(indexPath)
        }
        
        // Then reconfigure the cell
        configureCell(cell, atIndexPath: indexPath)
        // Update the bottom button
        updateNewCollectionButton()

    }
    
    // Get a photo object and set up the cell
    func configureCell(cell: PhotoCollectionCell, atIndexPath indexPath: NSIndexPath) {
        
        var imageForCell = UIImage(named: "NoImage")
    
        cell.photoImageView.image = nil
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        let pin = photo.pin! as Pin
       
        if photo.url_m == "" {
            println("URL for photoImage is nil or an empty string")
        } else if photo.photoImage != nil {
                imageForCell = photo.photoImage
        }
        else {
            cell.activityIndicator.startAnimating()
          let task = FlickrClient.sharedInstance().downloadPhotoImageForPin(photo){success, data, errorString in
                
                if success {
                    
                    let image = UIImage(data: data!)
                    photo.photoImage = image
                    CoreDataStackManager.sharedInstance().saveContext() 
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.activityIndicator.stopAnimating()
                        cell.photoImageView.image = image
                    }
                } else {
                    println(errorString)
                }
            }
        }
        
        if let index = find(selectedIndexes, indexPath) {
            cell.photoImageView.alpha = 0.3
        } else {
            cell.photoImageView.alpha = 1.0
        }
        
        cell.photoImageView.image = imageForCell
    }

    // Create a reference to the shared context
    lazy var sharedContext = {
        CoreDataStackManager.sharedInstance().managedObjectContext!
        }()
    
    // Create an instance of fetchedResultsController to get data from our Photo entity
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        //Create the fetch request
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        //Add a sort descriptor
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        // Fetch only photos from the selected pin
        let predicate = NSPredicate(format: "pin == %@", self.pin)
        fetchRequest.predicate = predicate
        
        //Create the Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        //Return the fetched results controller
        return fetchedResultsController
        
        }()
    
    // Create global instance of PhotoViewController to use throughout Virtual Tourist
    class func sharedInstance() -> PhotoViewController {
        
        struct Singleton {
            static var sharedInstance = PhotoViewController()
        }
        return Singleton.sharedInstance
    }
}

//CollectionView related fetchedResultsController functions
extension PhotoViewController : NSFetchedResultsControllerDelegate {
    
    
    // Prepare to make all changes necessary to view
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
      
        
        // We are about to handle some new changes. Start out with empty arrays for each change type
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    
    // Haven't found a use or need for this function yet, but put it in for convenience
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        
    }
    
    // Make changes to individual objects
    func controller(controller: NSFetchedResultsController, didChangeObject photoObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        let photo = photoObject as! Photo
        
        switch(type) {
        case NSFetchedResultsChangeType.Insert:
            println("didChangeObject for changeType.Insert")
            insertedIndexPaths.append(newIndexPath!)
            break
        case NSFetchedResultsChangeType.Delete:
            println("didChangeObject for changeType.Delete")
            deletedIndexPaths.append(indexPath!)
            break
        case NSFetchedResultsChangeType.Update:
            println("didChangeObject for changeType.Insert")
            break
        default:
            break
            
        }
    }
    
    // Update the view to reflect all changes
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        photoCollectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                self.photoCollectionView.insertItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.photoCollectionView.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.photoCollectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            }, completion: nil)
        
            updateNewCollectionButton() 
    }

}




