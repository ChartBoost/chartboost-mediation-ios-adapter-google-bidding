//
// GoogleBiddingAdapterInterstitialAd.swift
// GoogleBiddingAdapter
//
// Created by Alex Rice on 10/03/22
//

import Foundation
import GoogleMobileAds
import HeliumSdk

class GoogleBiddingAdapterBannerAd: GoogleBiddingAdapterAd, PartnerAd {
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        loadCompletion = completion

        // Banner ads auto-show after loading, so we must have a ViewController
        guard viewController != nil else {
            let error = error(.showFailureViewControllerNotFound)
            log(.loadFailed(error))
            completion(.failure(error))
            return
        }
        // Check for valid adm
        guard request.adm != nil, request.adm != "" else {
            let error = error(.loadFailureInvalidAdMarkup)
            log(.loadFailed(error))
            completion(.failure(error))
            return
        }
        
        // Create banner
        let bannerView = GADBannerView(adSize: gadAdSizeFrom(cgSize: request.size))
        bannerView.adUnitID = request.partnerPlacement
        bannerView.isAutoloadEnabled = false
        bannerView.delegate = self
        bannerView.rootViewController = viewController
        inlineView = bannerView
        
        // Load banner
        let gbRequest = generateRequest()
        bannerView.load(gbRequest)
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        // no-op
    }
    
    private func gadAdSizeFrom(cgSize: CGSize?) -> GADAdSize {
        guard let size = cgSize else { return GADAdSizeInvalid }

        switch size.height {
        case 50..<90:
            return GADAdSizeBanner
        case 90..<250:
            return GADAdSizeLeaderboard
        case 250...:
            return GADAdSizeMediumRectangle
        default:
            return GADAdSizeBanner
        }
    }
}

extension GoogleBiddingAdapterBannerAd: GADBannerViewDelegate {

    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        let error = self.error(.loadFailureException, error: error)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
}
