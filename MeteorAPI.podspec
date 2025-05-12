Pod::Spec.new do |spec|
  spec.name         = "MeteorAPI"
  spec.version      = "1.0.0"
  spec.summary      = "A Swift library for making API requests"
  spec.description  = "MeteorAPI is a Swift library that provides a simple and elegant way to make API requests."
  spec.homepage     = "https://github.com/Jason-Stan-Lee/MeteorAPI"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Jason-Stan-Lee" => "your.email@example.com" }
  spec.source       = { :git => "https://github.com/Jason-Stan-Lee/MeteorAPI.git", :tag => "#{spec.version}" }
  
  spec.ios.deployment_target = "13.0"
  spec.osx.deployment_target = "10.15"
  spec.tvos.deployment_target = "13.0"
  spec.watchos.deployment_target = "6.0"
  
  spec.swift_version = "5.7"
  
  spec.source_files = [
    "Sources/MeteorAPI/**/*.swift",
    "Sources/MeteorAPIConcurrencySupport/**/*.swift"
  ]
  spec.dependency "Alamofire", "~> 5.4.0"
  
  spec.test_spec "Tests" do |test_spec|
    test_spec.source_files = "Tests/MeteorAPITests/**/*.swift"
    test_spec.resources = "Tests/MeteorAPITests/Fixture"
    test_spec.dependency "Mocker", "~> 2.3.0"
  end
end 