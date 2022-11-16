//
// GoogleBiddingAdapterRewardedAd.swift
// GoogleBiddingAdapter
//
// Created by Alex Rice on 10/03/22
//

import Foundation
import GoogleMobileAds
import HeliumSdk

final class GoogleBiddingAdapterRewardedAd: GoogleBiddingAdapterAd, PartnerAd {
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }

    // The GoogleBidding Ad Object
    var ad: GADRewardedAd?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)

        // Check for valid adm
        guard request.adm != nil, request.adm != "" else {
            let error = error(.noBidPayload)
            log(.loadFailed(error))
            completion(.failure(error))
            return
        }
        
        let gbRequest = generateRequest()
        GADRewardedAd.load(withAdUnitID:self.request.partnerPlacement,
                                request: gbRequest) { [weak self] ad, error in
            guard let self = self else { return }
            if let error = error {
                self.log(.loadFailed(error))
                completion(.failure(error))
                return
            }
            self.ad = ad
            ad?.fullScreenContentDelegate = self
            self.log(.loadSucceeded)
            completion(.success([:]))
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        
        guard let ad = ad else {
            let error = error(.noAdReadyToShow)
            log(.showFailed(error))
            completion(.failure(error))
            return
        }
        showCompletion = completion
        
        DispatchQueue.main.async {
            ad.present(fromRootViewController: viewController) { [weak self] in
                guard let self = self else { return }
                self.log(.didReward)
                self.delegate?.didReward(self, details: [:]) ?? self.log(.delegateUnavailable)
            }
        }
    }
}

extension GoogleBiddingAdapterRewardedAd: GADFullScreenContentDelegate {
    
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        log(.showFailed(self.error(.showFailure, error: error)))
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    // Google has deprecated adDidPresentFullScreenContent and says to use this delegate method instead
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
}
