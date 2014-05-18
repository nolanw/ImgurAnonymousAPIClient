Pod::Spec.new do |s|
  s.name = "ImgurHTTPClient"
  s.version = "0.1"
  s.license = "Public domain"
  s.summary = "An anonymous Imgur image uploader"
  s.homepage = "https://github.com/nolanw/ImgurHTTPClient"
  s.author = "Nolan Waite"
  s.source = {:git => "git://github.com/nolanw/ImgurHTTPClient.git", :tag => "v0.1"}
  s.source_files = "ImgurHTTPClient.[hm]"
  s.requires_arc = true
  s.dependency 'AFNetworking/NSURLSession', '~> 2.0'
  
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.9'
end
