// Copyright 2022-2025 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import GoogleMobileAds

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class GoogleBiddingAdapterConfiguration: NSObject, PartnerAdapterConfiguration {
    /// The version of the partner SDK.
    @objc public static var partnerSDKVersion: String {
        let versionNumber = GADMobileAds.sharedInstance().versionNumber
        return "\(versionNumber.majorVersion).\(versionNumber.minorVersion).\(versionNumber.patchVersion)"
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the 
    /// last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.
    /// <Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    @objc public static let adapterVersion = "5.11.13.0.1"

    /// The partner's unique identifier.
    @objc public static let partnerID = "google_googlebidding"

    /// The human-friendly partner name.
    @objc public static let partnerDisplayName = "Google bidding"

    /// Google's identifier for your test device can be found in the console output from their SDK
    @objc public static var testDeviceIdentifiers: [String]? {
        get {
            GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers
        }
        set {
            GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = newValue
            log("Test device IDs set tot \(newValue?.description ?? "nil")")
        }
    }
}
