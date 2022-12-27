//
// GoogleBiddingAdapter.swift
// GoogleBiddingAdapter
//
// Created by Alex Rice on 10/03/22
//

import Foundation
import GoogleMobileAds
import HeliumSdk

// Magic Strings that shouldn't be changed because they're defined by Google, not Helium.
enum GoogleStrings {
    static let ccpaKey = "gap_rdp"
    static let gadClassName = "GADMobileAds"
    static let nonPersonalizedAdsKey = "npa"
    static let isHybridKey = "is_hybrid_setup"
    static let queryType = "requester_type_2"
    static let queryTypeKey = "query_info_type"
    static let reqIdKey = "placement_request_id"
}

final class GoogleBiddingAdapter: PartnerAdapter {
    
    /// The version of the partner SDK.
    lazy var partnerSDKVersion = getGADVersionString()

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Helium SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Helium major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    var adapterVersion = "4.\(getGADVersionString()).0"
    
    /// The partner's unique identifier.
    var partnerIdentifier = "google_googlebidding"
    
    /// The human-friendly partner name.
    var partnerDisplayName = "Google bidding"
    
    /// Parameters that should be included in all ad requests
    let sharedExtras = GADExtras()

    /// The designated initializer for the adapter.
    /// Helium SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Helium SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {
        // no-op
    }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        
        // Parameters that need to be on every Google bidding request
        sharedExtras.additionalParameters = [GoogleStrings.queryTypeKey: GoogleStrings.queryType]
        
        // Disable Google mediation since Helium is the mediator
        GADMobileAds.sharedInstance().disableMediationInitialization()

        // Exit early if GoogleMobileAds SDK has already been initalized
        let statuses = GADMobileAds.sharedInstance().initializationStatus
        guard let status = statuses.adapterStatusesByClassName[GoogleStrings.gadClassName],
                  status.state == GADAdapterInitializationState.notReady else {
            log("Redundant call to initalize GoogleMobileAds was ignored")
            // We should log either success or failure before returning, and this is more like success.
            log(.setUpSucceded)
            completion(nil)
            return
        }
        
        GADMobileAds.sharedInstance().start { initStatus in
            let statuses = initStatus.adapterStatusesByClassName
            if statuses[GoogleStrings.gadClassName]?.state == .ready {
                self.log(.setUpSucceded)
                completion(nil)
            } else {
                let error = self.error(.initializationFailurePartnerNotIntegrated,
                                       description: "GoogleBidding adapter status was \(String(describing: statuses[GoogleStrings.gadClassName]?.state))")
                self.log(.setUpFailed(error))
                completion(error)
            }
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String: String]?) -> Void) {
        log(.fetchBidderInfoStarted(request))
        
        let gbRequest = GADRequest()
        gbRequest.requestAgent = "Helium"
        gbRequest.register(sharedExtras)
        
        // Convert from our internal AdFormat type to Google's ad format type
        let gbAdFormat = googleAdFormat(from: request.format)
        
        GADQueryInfo.createQueryInfo(with: gbRequest, adFormat: gbAdFormat) { queryInfo, error in
            if let token = queryInfo?.query {
                self.log(.fetchBidderInfoSucceeded(request))
                completion(["token": token])
            } else {
                let partnerError = self.error(.prebidFailurePartnerNotIntegrated, description: "Token was nil", error: error)
                self.log(.fetchBidderInfoFailed(request, error: partnerError))
                completion(nil)
            }
        }
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        if applies == true && status != .granted {
            // Set "npa" to "1" by merging with the existing extras dictionary if it's non-nil and overwriting the old value if keys collide
            sharedExtras.additionalParameters = (sharedExtras.additionalParameters ?? [:]).merging([GoogleStrings.nonPersonalizedAdsKey:"1"], uniquingKeysWith: { (_, new) in new })
            log(.privacyUpdated(setting: GoogleStrings.nonPersonalizedAdsKey, value: "1"))
        } else {
            // If GDPR doesn't apply or status is '.granted', then remove the "non-personalized ads" flag
            sharedExtras.additionalParameters?[GoogleStrings.nonPersonalizedAdsKey] = nil
            log(.privacyUpdated(setting: GoogleStrings.nonPersonalizedAdsKey, value: nil))
        }
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
        // https://developers.google.com/ad-manager/mobile-ads-sdk/ios/ccpa#rdp_signal_2
        // Invert the boolean, because "has given consent" is the opposite of "needs Restricted Data Processing"
        log(.privacyUpdated(setting: GoogleStrings.ccpaKey, value: !hasGivenConsent))
        UserDefaults.standard.set(!hasGivenConsent, forKey: GoogleStrings.ccpaKey)
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        log(.privacyUpdated(setting: "ChildDirectedTreatment", value: isChildDirected))
        GADMobileAds.sharedInstance().requestConfiguration.tag(forChildDirectedTreatment: isChildDirected)
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Helium SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Helium SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        switch request.format {
        case .banner:
            return GoogleBiddingAdapterBannerAd(adapter: self, request: request, delegate: delegate, extras: sharedExtras)
        case .interstitial:
            return GoogleBiddingAdapterInterstitialAd(adapter: self, request: request, delegate: delegate, extras: sharedExtras)
        case .rewarded:
            return GoogleBiddingAdapterRewardedAd(adapter: self, request: request, delegate: delegate, extras: sharedExtras)
        @unknown default:
            throw error(.loadFailureUnsupportedAdFormat)
        }
    }

    func googleAdFormat(from adFormat: AdFormat) -> GADAdFormat {
        switch adFormat {
        case .banner:
            return GADAdFormat.banner
        case .interstitial:
            return GADAdFormat.interstitial
        case .rewarded:
            return GADAdFormat.rewarded
        @unknown default:
            return GADAdFormat.unknown
        }
    }
}

func getGADVersionString() -> String {
    let gadVersion = GADVersionNumber()
    return "\(gadVersion.majorVersion).\(gadVersion.minorVersion).\(gadVersion.patchVersion)"
}
