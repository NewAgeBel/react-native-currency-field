#
# Be sure to run `pod lib lint RNCurrencyField.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

require 'json'
package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
    s.name             = "react-native-currency-field"
    s.version          = package['version']
    s.summary          = package['description']
    s.description      = package['description']
    s.homepage         = package['homepage']
    s.license          = package['license']
    s.author           = package['author']
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.source           = { :git => 'https://github.com/newagebel/react-native-currency-field.git', :tag => s.version.to_s }
    s.platform      = :ios, "10.0"
    s.source_files  = "ios/**/*.{h,m,swift}"
    s.requires_arc  = true
    s.swift_version = "5.0"
    s.dependency 'React-Core'
    s.dependency 'React-RCTText'
  end
