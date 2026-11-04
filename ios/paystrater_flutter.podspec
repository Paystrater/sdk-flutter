Pod::Spec.new do |s|
  s.name             = 'paystrater_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Paystrater checkout for Flutter: opens the Paystrater app, wallets and the share sheet.'
  s.homepage         = 'https://docs.paystrater.com/docs/sdks/flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = 'Paystrater'
  s.source           = { :path => '.' }
  s.source_files     = 'paystrater_flutter/Sources/paystrater_flutter/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
end
