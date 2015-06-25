//
//  FlickrConstants.swift
//  VirtualTourist
//
//  Created by Cody Fazio on 6/16/15.
//  Copyright (c) 2015 Cody Fazio. All rights reserved.
//

import Foundation
class FlickrConstants {
    
    struct Search {
        static let BASE_URL : String = "https://api.flickr.com/services/rest/"
        static let METHOD_NAME : String = "flickr.photos.search"
        static let API_KEY : String = "a547a964035cf177c980b27927cf8b65"
        
        static let EXTRAS  = "url_m"
        static let SAFE_SEARCH  = "1"
        static let DATA_FORMAT = "json"
        static let NO_JSON_CALLBACK  = "1"
        static let PHOTOS_PER_PAGE  = "100"
        static let RADIUS  = 1.0
        static let RADIUS_UNITS = "km"
        
        
    }
    
    struct ArgumentKeys {
        static let METHOD_NAME = "method"
        static let API_KEY = "api_key"
        static let SAFE_SEARCH = "safe_search"
        static let EXTRAS = "extras"
        static let DATA_FORMAT = "format"
        static let NO_JSON_CALLBACK = "nojsoncallback"
        static let PAGE_NUMBER = "page"
        static let PHOTOS_PER_PAGE = "per_page"
        static let RADIUS_UNITS = "radius_units"
        static let RADIUS = "radius"
        static let LATITUDE = "lat"
        static let LONGITUDE  = "lon"

    }
    
}
