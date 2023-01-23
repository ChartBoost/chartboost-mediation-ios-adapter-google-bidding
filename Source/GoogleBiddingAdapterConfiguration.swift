// Copyright 2022-2023 Chartboost, Inc.
// 
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

//
//  GoogleBiddingAdapterConfiguration.swift
//  GoogleBiddingAdapter
//
//  Created by Alex Rice on 11/03/22.
//

import Foundation
import GoogleMobileAds

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class GoogleBiddingAdapterConfiguration: NSObject {
    
    /// Google's identifier for your test device can be found in the console output from their SDK
    class func setTestDeviceId(_ id: String?) {
        if let id = id {
            GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [id]
        } else {
            GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = []
        }
        print("Google Bidding SDK test device ID set to \(id ?? "nil")")
    }
}
