//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Cody Fazio on 6/16/15.
//  Copyright (c) 2015 Cody Fazio. All rights reserved.
//

import Foundation
import UIKit


class FlickrClient: NSObject {
    
    // Create variables
    var session : NSURLSession
    var totalPages : Int?
    
    // Create reference to a sharedContext for dealing with Core Data managed objects
    lazy var sharedContext = {
        CoreDataStackManager.sharedInstance().managedObjectContext!
        }()
    
    
    // Create a shared session to use when making calls
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    // Get the number of pages of results for our Flickr search location
    func getPaginationFromFlickr(latitude: String, longitude: String, completionHandler: (success: Bool, result : Int?, errorString: String?) -> Void) {
        
        // Compile necessary info, create our url, and create the request
        var methodParameters = buildMethod(latitude, longitude: longitude)
        let urlString = FlickrConstants.Search.BASE_URL + escapedParameters(methodParameters)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        // Handle the outcome of the task. If there is an error, display relevant information to the user (Flickr is not responding, no network connection, etc). If success, pass the data to be parsed. If that succeeds, do checks to get back the totalPages.
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if downloadError != nil {
                print(downloadError!.description)
            } else {
                self.parseJSONWithCompletionHandler(data!) { (parsedData, parsedError) in
                    if parsedError != nil {
        
                        completionHandler(success:false, result: nil, errorString: parsedError?.localizedDescription)
                        
                    } else {
                        if let photosDictionary = parsedData.valueForKey("photos") as? [String: AnyObject] {
                            if let totalPages = photosDictionary["pages"] as? Int {
                                
                                completionHandler(success: true, result: totalPages, errorString: nil)
                            }
                        }
                    }
                }
            }
        }
        task.resume()
    }
    
    // Use the page number to refine our Flickr search and get back the number of photos we need
    func getPhotosFromFlickrWithPageNumber(latitude: String, longitude: String, pageNumber:Int, completionHandler: (success: Bool, result : [[String:AnyObject]]?, errorString: String?) -> Void) {
        
        var methodParametersWithPage = buildMethod(latitude, longitude: longitude)
        methodParametersWithPage[FlickrConstants.ArgumentKeys.PAGE_NUMBER] = pageNumber
        methodParametersWithPage[FlickrConstants.ArgumentKeys.PHOTOS_PER_PAGE] = FlickrConstants.Search.PHOTOS_PER_PAGE
        let urlString = FlickrConstants.Search.BASE_URL + escapedParameters(methodParametersWithPage)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if downloadError != nil {
                //TODO: Error Handling in Error.swift
            } else {
                self.parseJSONWithCompletionHandler(data!) { (parsedData, parsedError) in
                    if parsedError != nil {
                        //TODO Error Handling in Error.swift
                        completionHandler(success:false, result : nil, errorString: parsedError?.localizedDescription)
                        
                    } else {
                        if let photosDictionary = parsedData.valueForKey("photos") as? [String: AnyObject] {
                            if let photosArray = photosDictionary["photo"] as? [[String: AnyObject]] {
                                completionHandler(success: true, result: photosArray, errorString: nil)
                                
                            }else {
                                completionHandler(success: false, result: nil, errorString: "Could not create photosArray")
                            }
                        }
                    }
                }
            }
        }
        task.resume()
    }
      // Build the method we will use in our Flickr seach
    func buildMethod(latitude: String?, longitude: String?) -> [String: AnyObject]{
        
        let methodArguments = [
            FlickrConstants.ArgumentKeys.METHOD_NAME : FlickrConstants.Search.METHOD_NAME,
            FlickrConstants.ArgumentKeys.API_KEY : FlickrConstants.Search.API_KEY,
            FlickrConstants.ArgumentKeys.SAFE_SEARCH : FlickrConstants.Search.SAFE_SEARCH,
            FlickrConstants.ArgumentKeys.EXTRAS : FlickrConstants.Search.EXTRAS,
            FlickrConstants.ArgumentKeys.DATA_FORMAT : FlickrConstants.Search.DATA_FORMAT,
            FlickrConstants.ArgumentKeys.NO_JSON_CALLBACK : FlickrConstants.Search.NO_JSON_CALLBACK,
            FlickrConstants.ArgumentKeys.RADIUS_UNITS : FlickrConstants.Search.RADIUS_UNITS,
            FlickrConstants.ArgumentKeys.RADIUS : FlickrConstants.Search.RADIUS,
            FlickrConstants.ArgumentKeys.LATITUDE : latitude!,
            FlickrConstants.ArgumentKeys.LONGITUDE : longitude!
            ]
        return methodArguments as! [String : AnyObject]
    }
    
    //Read data returned from network into a usable form
    func parseJSONWithCompletionHandler(data: NSData, completionHandler: (result: AnyObject!, error: NSError?) -> Void) {
        
        var parsingError: NSError? = nil
        let parsedResult: AnyObject?
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
        } catch let error {
            parsingError = error as! NSError
            parsedResult = nil
        }
        if let error = parsingError {
            completionHandler(result: nil, error: error)
        } else {
            completionHandler(result: parsedResult, error: nil)
        }
    }
    
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        for (key, value) in parameters {
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
        }
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    // Create global instance of FlickrClient to use throughout Virtual Tourist
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }

}

extension FlickrClient  {
    
    // Called when creating our pin to perform the initial photo search from Flickr. It returns an array of objects which we'll parse though and create our photo objects from. Then we set the photo object's pin, and download the image data from the url we are given using the downloadPhotoImageForPin function. Last, we save our photo object in our shared context.
    func getPhotosForPin(pin : Pin) {
        
        let latitude = pin.latitude.stringValue
        let longitude = pin.longitude.stringValue
        
        if pin.photos != nil {
            
            if pin.photos!.isEmpty {
                
                FlickrClient.sharedInstance().getPaginationFromFlickr(latitude, longitude: longitude) {(success: Bool, totalPages: Int?, errorString: String?) in
                    
                    if success {
                        print("Success getting totalPages")
                        
                        pin.totalPages = totalPages
                        print("Printing the current pin's info: ")
                        print(pin)
                        if totalPages == 0 {
                            return
                        } else  {
                        
                        pin.currentPage == 1
                        FlickrClient.sharedInstance().getPhotosFromFlickrWithPageNumber(latitude, longitude: longitude, pageNumber: totalPages!) {(success: Bool, result : [[String: AnyObject]]?, errorString: String?) in
                            if success {
                                print("Success getting initial photos!")
                                print("Alert user of completion... Maybe change pin color?")
                                
                                
                                let photosDictionaries = result!
                                var photos = photosDictionaries.map() {(dictionary: [String : AnyObject]) -> Photo in
                                    let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                                    photo.pin = pin
                                    self.downloadPhotoImageForPin(photo){success, data, errorString in
                                        if let error = errorString {
                                            print(errorString)
                                        } else {
                                             ImageCache.Caches.imageCache.storeImage(UIImage(data:data!), withIdentifier: photo.lastComponent)
                                        }
                                    }
                                    return photo
                                }
                                CoreDataStackManager.sharedInstance().saveContext()
                            } else {
                                print("Failed getting photos!")
                            }
                        }
                        }
                    }
                    else {
                        print("Failed to get totalPages")
                        print(errorString)
                    }
                }
            } else {
                print("Photos array contains existing photos")
                //Handle existing photos, then call for pagination.
            }
        } else {
            
            FlickrClient.sharedInstance().getPaginationFromFlickr(latitude, longitude: longitude) { (success: Bool, totalPages: Int?, errorString: String?) in
                
                if success {
                    print("Success getting pages!")
                } else {
                    print("Failed to get totalPages")
                    print(errorString)
                }
            }
        }
    }
    
    // Called to download the photo image after we create our photo object
    func downloadPhotoImageForPin(imageForDownload: Photo, completionHandler: (success: Bool, data: NSData?, errorString: String?) -> Void) -> NSURLSessionDataTask {
        
        let session = NSURLSession.sharedSession()
        let url = NSURL(string: imageForDownload.url_m)
        let request = NSURLRequest(URL: url!)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                print("Error downloading image")
                completionHandler(success: false, data: nil, errorString: error.description)
            } else {
                if let data = data {
                    completionHandler(success: true, data: data, errorString: nil)
                                  }
            }
        }
        task.resume()
        return task
    }
    
    
    

    
}

