# ImgurHTTPClient

An anonymous Imgur image uploader.

ImgurHTTPClient requires AFNetworking 2.0 or higher and requires iOS 7.0 or OS X 10.9.

## Usage

```objc
// Put your client ID in Info.plist first! Then…
NSData *imageData = UIImagePNGRepresentation(someImage);
[[ImgurHTTPClient client] uploadImageData:imageData withFilename:nil title:nil completionHandler:^(NSURL *imgurURL, NSError *error) {
    // imgurURL is ready for you!
}];
```

The client is contained within the `ImgurHTTPClient.h` and `ImgurHTTPClient.m` files. Simply copy those two files into your project.

If you use CocoaPods, you can instead add `pod 'ImgurHTTPClient'` to your `Podfile`.

Once you're all set, you need an Imgur API client ID. This is a requirement for using the Imgur API, which is what ImgurHTTPClient uses. Be sure to [register your application][register] and get the client ID.

You have two options for specifying your client ID. Either create a client and give it the client ID:

```objc
ImgurHTTPClient *client = [[ImgurHTTPClient alloc] initWithClientID:@"YOURIDHERE"];
```

Or put it in your `Info.plist` for the key `ImgurHTTPClientID` then leave it out when creating a client:

```objc
ImgurHTTPClient *client = [ImgurHTTPClient new]; // Uses client ID from Info.plist
```

Note that the `-uploadImage…` methods return an `NSURLSessionDataTask` which you can use to cancel or suspend the upload:

```objc
NSURLSessionDataTask *task = [[ImgurHTTPClient client] uploadImage…
// Later…
[task cancel];
```

[register]: https://api.imgur.com

## Example

There's a functional (i.e. aesthetically displeasing and not very usable) example app for iOS in the [Test App][] folder. It demonstrates how to upload an image from the photo library and how to cancel an upload in progress.

[Test App]: Test%20App

## Why

Uploading to Imgur is handy, but handling all the possible errors is a huge pain. ImgurHTTPClient wraps it all up.
