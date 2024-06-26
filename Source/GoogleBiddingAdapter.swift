// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import GoogleMobileAds

// Magic Strings that shouldn't be changed because they're defined by Google, not Chartboost Mediation.
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
    var partnerSDKVersion: String {
        let versionNumber = GADMobileAds.sharedInstance().versionNumber
        return "\(versionNumber.majorVersion).\(versionNumber.minorVersion).\(versionNumber.patchVersion)"
    }
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.11.6.0.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "google_googlebidding"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Google bidding"
    
    /// Parameters that should be included in all ad requests
    let sharedExtras = GADExtras()

    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
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
        
        // Disable Google mediation since Chartboost Mediation is the mediator
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
                let error = self.error(.initializationFailureUnknown,
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
        gbRequest.requestAgent = "Chartboost"
        gbRequest.register(sharedExtras)
        
        // Convert from our internal AdFormat type to Google's ad format type
        guard let gbAdFormat = googleAdFormat(from: request.format) else {
            let error = error(.prebidFailureUnknown, description: "Failed to map ad format \(request.format) to GADAdFormat")
            log(.fetchBidderInfoFailed(request, error: error))
            completion(nil)
            return
        }

        GADQueryInfo.createQueryInfo(with: gbRequest, adFormat: gbAdFormat) { queryInfo, error in
            if let token = queryInfo?.query {
                self.log(.fetchBidderInfoSucceeded(request))
                completion(["token": token])
            } else {
                let partnerError = self.error(.prebidFailureUnknown, description: "Token was nil", error: error)
                self.log(.fetchBidderInfoFailed(request, error: partnerError))
                completion(nil)
            }
        }
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        // The "npa" parameter is an internal AdMob feature not publicly documented, and is subject to change.
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
        // See https://developers.google.com/admob/ios/privacy/ccpa
        // Invert the boolean, because "has given consent" is the opposite of "needs Restricted Data Processing"
        log(.privacyUpdated(setting: GoogleStrings.ccpaKey, value: !hasGivenConsent))
        UserDefaults.standard.set(!hasGivenConsent, forKey: GoogleStrings.ccpaKey)
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        // See https://developers.google.com/admob/ios/api/reference/Classes/GADRequestConfiguration#-tagforchilddirectedtreatment:
        log(.privacyUpdated(setting: "ChildDirectedTreatment", value: isChildDirected))
        GADMobileAds.sharedInstance().requestConfiguration.tagForChildDirectedTreatment = NSNumber(booleanLiteral: isChildDirected)
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        // This partner supports multiple loads for the same partner placement.
        switch request.format {
        case .banner:
            return GoogleBiddingAdapterBannerAd(adapter: self, request: request, delegate: delegate, extras: sharedExtras)
        case .interstitial:
            return GoogleBiddingAdapterInterstitialAd(adapter: self, request: request, delegate: delegate, extras: sharedExtras)
        case .rewarded:
            return GoogleBiddingAdapterRewardedAd(adapter: self, request: request, delegate: delegate, extras: sharedExtras)
        default:
            // Not using the `.rewardedInterstitial` or `.adaptive_banner` cases directly to maintain backward compatibility with Chartboost Mediation 4.0
            if request.format.rawValue == "rewarded_interstitial" {
                return GoogleBiddingAdapterRewardedInterstitialAd(adapter: self, request: request, delegate: delegate, extras: sharedExtras)
            } else if request.format.rawValue == "adaptive_banner" {
                return GoogleBiddingAdapterBannerAd(adapter: self, request: request, delegate: delegate, extras: sharedExtras)
            } else {
                throw error(.loadFailureUnsupportedAdFormat)
            }
        }
    }
    
    /// Maps a partner load error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a load completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapLoadError(_ error: Error) -> ChartboostMediationError.Code? {
        guard (error as NSError).domain == GADErrorDomain,
              let code = GADErrorCode(rawValue: (error as NSError).code) else {
            return nil
        }
        switch code {
        case .invalidRequest:
            return .loadFailureInvalidAdRequest
        case .noFill:
            return .loadFailureNoFill
        case .networkError:
            return .loadFailureNetworkingError
        case .serverError:
            return .loadFailureServerError
        case .osVersionTooLow:
            return .loadFailureOSVersionNotSupported
        case .timeout:
            return .loadFailureTimeout
        case .mediationDataError:
            return .loadFailureUnknown
        case .mediationAdapterError:
            return .loadFailureUnknown
        case .mediationInvalidAdSize:
            return .loadFailureInvalidBannerSize
        case .internalError:
            return .loadFailureUnknown
        case .invalidArgument:
            return .loadFailureUnknown
        case .receivedInvalidResponse:
            return .loadFailureInvalidBidResponse
        case .mediationNoFill:
            return .loadFailureNoFill
        case .adAlreadyUsed:
            return .loadFailureLoadInProgress
        case .applicationIdentifierMissing:
            return .loadFailureInvalidCredentials
        @unknown default:
            return nil
        }
    }
    
    /// Maps a partner show error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a show completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapShowError(_ error: Error) -> ChartboostMediationError.Code? {
        guard (error as NSError).domain == GADErrorDomain,
              let code = GADPresentationErrorCode(rawValue: (error as NSError).code) else {
            return nil
        }
        switch code {
        case .codeAdNotReady:
            return .showFailureAdNotReady
        case .codeAdTooLarge:
            return .showFailureUnsupportedAdSize
        case .codeInternal:
            return .showFailureUnknown
        case .codeAdAlreadyUsed:
            return .showFailureUnknown
        case .notMainThread:
            return .showFailureException
        case .mediation:
            return .showFailureUnknown
        @unknown default:
            return nil
        }
    }
    
    func googleAdFormat(from adFormat: AdFormat) -> GADAdFormat? {
        switch adFormat {
        case .banner:
            return GADAdFormat.banner
        case .interstitial:
            return GADAdFormat.interstitial
        case .rewarded:
            return GADAdFormat.rewarded
        default:
            // Not using the `.rewardedInterstitial` or `.adaptive_banner` cases directly to maintain backward compatibility with Chartboost Mediation 4.0
            if adFormat.rawValue == "rewarded_interstitial" {
                return GADAdFormat.rewardedInterstitial
            } else if adFormat.rawValue == "adaptive_banner" {
                return GADAdFormat.banner
            } else {
                return nil
            }
        }
    }
}
