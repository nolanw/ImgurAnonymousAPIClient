//  ImgurHTTPClient.h
//  ImgurHTTPClient
//
//  Public domain. https://github.com/nolanw/ImgurHTTPClient

#import <Foundation/Foundation.h>

/**
 * An ImgurHTTPClient anonymously uploads images to Imgur.
 *
 * In order to use the ImgurHTTPClient, you must register your application with the Imgur API. Please go to https://api.imgur.com and register your application, then be sure to specify your client ID when creating an ImgurHTTPClient (or put it in your Info.plist; see the +client method documentation).
 */
@interface ImgurHTTPClient : NSObject

/**
 * Designated initializer.
 */
- (id)initWithClientID:(NSString *)clientID;

/**
 * The client ID you received when registering your app with the Imgur API. Setting a new client ID affects all future uploads.
 */
@property (copy, nonatomic) NSString *clientID;

/**
 * Convenient singleton. Tries to find client ID in Info.plist under the ImgurHTTPClientIDKey; if unspecified or unwanted, be sure to set a different client ID.
 */
+ (instancetype)client;

/**
 * Anonymously uploads an image from memory to Imgur.
 *
 * @param data              The image data. Acceptable image types are listed at https://imgur.com/faq#types
 * @param filename          An optional filename for the uploaded image. The filename is visible on the Imgur website but does not affect any part of the URL passed to the completionHandler. May be nil.
 * @param title             An optional title for the uploaded image. The title is visible on the Imgur website. May be nil.
 * @param completionHandler A block to call after uploading the image data, which returns nothing and takes two parameters: the Imgur URL if the upload succeeded; and an NSError object in the ImgurHTTPClientErrorDomain describing any failure. The completionHandler is always called on the main thread.
 *
 * @return An NSProgress object that can be used to cancel the upload.
 */
- (NSProgress *)uploadImageData:(NSData *)data
                   withFilename:(NSString *)filename
                          title:(NSString *)title
              completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler;

/**
 * Anonymously uploads an image from a file to Imgur.
 *
 * @param fileURL           The URL of the image file to upload. Acceptable image types are listed at https://imgur.com/faq#types
 * @param title             An optional title for the uploaded image. The title is visible on the Imgur website. May be nil.
 * @param completionHandler A block to call after uploading the image data, which returns nothing and takes two parameters: the Imgur URL if the upload succeeded; and an NSError object in the ImgurHTTPClientErrorDomain describing any failure. The completion handler is always called on the main thread.
 *
 * @return An NSProgress object that can be used to cancel the upload.
 */
- (NSProgress *)uploadImageFile:(NSURL *)fileURL
                      withTitle:(NSString *)title
              completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler;

@end

/**
 * Equal to @"ImgurHTTPClientID". If you add a value for the key to your Info.plist, it will be used by the convenient singleton.
 */
extern NSString * const ImgurHTTPClientIDKey;

/**
 * All errors in the ImgurHTTPClientErrorDomain have one of the ImgurHTTPClientErrorCodes set as their code.
 */
extern NSString * const ImgurHTTPClientErrorDomain;

typedef NS_ENUM(NSInteger, ImgurHTTPClientErrorCodes) {
    
    /**
     * An unexpected error with the Imgur service.
     */
    ImgurHTTPClientUnknownError = 500,
    
    /**
     * The uploaded image was corrupt or unacceptable. Please see https://imgur.com/faq#types for the list of acceptable image types. If you have data of an unknown format, consider using ImageIO to determine the image type and/or convert to an acceptable image type.
     */
    ImgurHTTPClientInvalidImage = 400,
    
    /**
     * Authentication failed with the Imgur service. Check your client ID.
     */
    ImgurHTTPClientInvalidClientIDError = 403,
    
    /**
     * You've hit the limits for the application or the source IP address.
     */
    ImgurHTTPClientRateLimitExceededError = 429,
};
