Pod::Spec.new do |s|
  s.name = "ImgurAnonymousAPIClient"
  s.version = "0.1"
  s.license = "Public domain"
  s.summary = "An anonymous Imgur image uploader"
  s.homepage = "https://github.com/nolanw/ImgurAnonymousAPIClient"
  s.author = "Nolan Waite"
  s.source = {:git => "git://github.com/nolanw/ImgurAnonymousAPIClient.git", :tag => "v0.1"}
  s.source_files = "ImgurAnonymousAPIClient.[hm]"
  s.requires_arc = true
  
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.9'

  s.dependency 'AFNetworking', '~> 2.0'

  s.frameworks = 'ImageIO'
  s.ios.frameworks = 'AssetLibrary', 'MobileCoreServices'
  s.osx.frameworks = 'CoreServices'
end
