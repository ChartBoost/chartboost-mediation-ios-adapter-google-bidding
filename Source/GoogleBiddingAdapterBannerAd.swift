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
    
    // The GoogleBidding Ad Object
    var ad: GADBannerView?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        loadCompletion = completion

        // Banner ads auto-show after loading, so we must have a ViewController
        guard viewController != nil else {
            let error = error(.noViewController)
            log(.loadFailed(error))
            completion(.failure(error))
            return
        }
        // Check for valid adm
        guard request.adm != nil, request.adm != "" else {
            let error = error(.noBidPayload)
            log(.loadFailed(error))
            completion(.failure(error))
            return
        }
        
        let gbRequest = generateRequest()
        gbRequest.adString = request.adm

        let placementID = request.partnerPlacement

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let bannerView = GADBannerView(adSize: self.gadAdSizeFrom(cgSize: self.request.size))
            bannerView.adUnitID = placementID
            bannerView.isAutoloadEnabled = false
            bannerView.delegate = self
            bannerView.rootViewController = viewController
            self.ad = bannerView
            self.ad?.load(gbRequest)
        }
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
        switch (size.width, size.height) {
        case (320, 50):
            return GADAdSizeBanner
        case (300, 250):
            return GADAdSizeMediumRectangle
        case (728, 90):
            return GADAdSizeLeaderboard
        default:
            return GADAdSizeInvalid
        }
    }
}

extension GoogleBiddingAdapterBannerAd: GADBannerViewDelegate {

    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        log(.loadSucceeded)
        self.inlineView = bannerView
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        let error = self.error(.loadFailure)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
        self.delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
        self.delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
}
