#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'foundation_models_llm'
  s.version          = '0.0.1'
  s.summary          = "Reaches Apple's on-device foundation model from Flutter."
  s.description      = <<-DESC
Exposes the on-device foundation model's availability and its
schema-constrained generation to Dart. One source set serves iOS and macOS.
                       DESC
  s.homepage         = 'https://github.com/endo5501/NovelViewer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'NovelViewer' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'foundation_models_llm/Sources/foundation_models_llm/**/*.swift'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'

  # Deliberately the application's own targets, not the model framework's. The
  # framework arrived in 26; raising these would stop the app launching on
  # everything older, for a provider that is one of three. The Swift is guarded
  # by an availability check instead.
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  # Weak so the app still loads on an operating system that predates the
  # framework. The Swift never touches it outside an availability check.
  s.weak_frameworks = 'FoundationModels'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
