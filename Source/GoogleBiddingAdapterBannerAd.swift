// Copyright 2022-2025 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import GoogleMobileAds

class GoogleBiddingAdapterBannerAd: GoogleBiddingAdapterAd, PartnerBannerAd {
    /// The partner banner ad view to display.
    var view: UIView?

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)
        loadCompletion = completion

        // Banner ads auto-show after loading, so we must have a ViewController
        guard viewController != nil else {
            let error = error(.showFailureViewControllerNotFound)
            log(.loadFailed(error))
            completion(error)
            return
        }
        // Check for valid adm
        guard let adm = request.adm, !adm.isEmpty else {
            let error = error(.loadFailureInvalidAdMarkup)
            log(.loadFailed(error))
            completion(error)
            return
        }

        // Create banner
        guard
            let requestedSize = request.bannerSize,
            let gadSize = requestedSize.gadAdSize
        else {
            // Fail if we cannot fit a fixed size banner in the requested size.
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            completion(error)
            return
        }

        let bannerView = GADBannerView(adSize: gadSize)
        bannerView.adUnitID = request.partnerPlacement
        bannerView.isAutoloadEnabled = false
        bannerView.delegate = self
        bannerView.rootViewController = viewController
        view = bannerView

        // Load banner
        let gbRequest = generateRequest()
        bannerView.load(gbRequest)
    }
}

extension GoogleBiddingAdapterBannerAd: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        log(.loadSucceeded)
        // From https://developers.google.com/admob/ios/api/reference/Functions:
        // "The exact size of the ad returned is passed through the banner’s ad size delegate and
        // is indicated by the banner’s intrinsicContentSize."
        size = PartnerBannerSize(
            size: bannerView.intrinsicContentSize,
            type: GADAdSizeIsFluid(bannerView.adSize) ? .adaptive : .fixed
        )
        loadCompletion?(nil) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        log(.loadFailed(error))
        loadCompletion?(error) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }

    func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }
}

extension BannerSize {
    fileprivate var gadAdSize: GADAdSize? {
        if self.type == .adaptive {
            return GADInlineAdaptiveBannerAdSizeWithWidthAndMaxHeight(self.size.width, self.size.height)
        }
        switch self {
        case .standard:
            return GADAdSizeBanner
        case .medium:
            return GADAdSizeMediumRectangle
        case .leaderboard:
            return GADAdSizeLeaderboard
        default:
            return nil
        }
    }
}
