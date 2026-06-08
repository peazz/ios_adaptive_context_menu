Pod::Spec.new do |s|
  s.name             = 'ios_adaptive_context_menu'
  s.version          = '0.1.0'
  s.summary          = 'iOS native context menu on single tap for Flutter.'
  s.description      = <<-DESC
An iOS Flutter plugin that shows a native context menu on single tap.
  DESC
  s.homepage         = 'https://pub.dev/packages/ios_adaptive_context_menu'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = 'ios_adaptive_context_menu contributors'
  s.source           = { :path => '.' }
  s.source_files = 'ios_adaptive_context_menu/Sources/ios_adaptive_context_menu/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
