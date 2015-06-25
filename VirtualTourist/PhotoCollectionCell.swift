//
//  PhotoCollectionCell.swift
//  VirtualTourist
//
//  Created by Cody Fazio on 6/16/15.
//  Copyright (c) 2015 Cody Fazio. All rights reserved.
//

import UIKit

class PhotoCollectionCell: UICollectionViewCell {
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var taskToCancelifCellIsReused: NSURLSessionTask? {
        
        didSet {
            if let taskToCancel = oldValue {
                taskToCancel.cancel()
            }
        }
    }

    
}

