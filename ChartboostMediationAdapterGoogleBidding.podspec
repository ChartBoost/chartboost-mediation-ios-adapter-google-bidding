Pod::Spec.new do |spec|
  spec.name        = 'ChartboostMediationAdapterGoogleBidding'
  spec.version     = '4.11.1.0.0'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.homepage    = 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-google-bidding'
  spec.authors     = { 'Chartboost' => 'https://www.chartboost.com/' }
  spec.summary     = 'Chartboost Mediation iOS SDK Google Bidding adapter.'
  spec.description = 'Google Bidding Adapters for mediating through Chartboost Mediation. Supported ad formats: Banner, Interstitial, and Rewarded.'

  # Source
  spec.module_name  = 'ChartboostMediationAdapterGoogleBidding'
  spec.source       = { :git => 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-google-bidding.git', :tag => spec.version }
  spec.source_files = 'Source/**/*.{swift}'
  spec.resource_bundles = { 'ChartboostMediationAdapterGoogleBidding' => ['PrivacyInfo.xcprivacy'] }

  # Minimum supported versions
  spec.swift_version         = '5.0'
  spec.ios.deployment_target = '12.0'

  # System frameworks used
  spec.ios.frameworks = ['Foundation', 'UIKit']
  
  # This adapter is compatible with all Chartboost Mediation 4.X versions of the SDK.
  spec.dependency 'ChartboostMediationSDK', '~> 4.0'

  # Partner network SDK and version that this adapter is certified to work with.
  spec.dependency 'Google-Mobile-Ads-SDK', '~> 11.1.0'

  # The partner network SDK is a static framework which requires the static_framework option.
  spec.static_framework = true

end
