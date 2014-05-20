//  ImgurAnonymousAPIClient.h
//
//  Public domain. https://github.com/nolanw/ImgurAnonymousAPIClient

#import <Foundation/Foundation.h>
#import <Availability.h>

/**
 * An ImgurAnonymousAPIClient anonymously uploads images to Imgur.
 *
 * In order to use the ImgurAnonymousAPIClient, you must register your application with the Imgur API. Please go to https://api.imgur.com and register your application, then be sure to specify your client ID when creating an ImgurAnonymousAPIClient (or put it in your Info.plist; see the documentation for ImgurAnonymousAPIClientInfoPlistClientIDKey).
 *
 * Imgur describes at https://imgur.com/faq#types the types of images it will accept.
 *
 * Imgur describes at https://imgur.com/faq#size a maximum file size for uploads. Currently it's 10MB. However, uploaded images are resized to a maximum of 1MB (or 2MB for animated GIFs and APNGs), so aim for that size if you have the choice.
 */
@interface ImgurAnonymousAPIClient : NSObject

/**
 * Designated initializer.
 */
- (id)initWithClientID:(NSString *)clientID;

/**
 * The client ID you received when registering your app with the Imgur API. Setting a new client ID affects all future uploads.
 */
@property (copy, nonatomic) NSString *clientID;

/**
 * Tries to find a client ID in Info.plist under the ImgurAnonymousAPIClientInfoPlistClientIDKey; if unspecified or unwanted, use -initWithClientID: or set a different clientID.
 */
- (id)init;

/**
 * Convenient singleton. Tries to find a client ID in Info.plist under the ImgurAnonymousAPIClientInfoPlistClientIDKey; if unspecified or unwanted, be sure to set a different clientID.
 */
+ (instancetype)client;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

/**
 * Anonymously uploads an image to Imgur, rotating and resizing the image as needed to keep it under the maximum file size.
 *
 * @param image             The image to upload.
 * @param UTI               The desired Uniform Type Identifier for the uploaded image. If nil, a PNG is uploaded.
 * @param filename          An optional filename for the uploaded image. The filename is visible on the Imgur website but does not affect any part of the URL passed to the completionHandler. May be nil.
 * @param title             An optional title for the uploaded image. The title is visible on the Imgur website. May be nil.
 * @param completionHandler A block to call after uploading the image, which returns nothing and takes two parameters: the Imgur URL if the upload succeeded; and an NSError object in the ImgurAnonymousAPIClientErrorDomain describing any failure. The completion handler is always called on the main thread.
 *
 * @return An NSProgress that can be used to cancel, suspend, or monitor the progress of the upload.
 */
- (NSProgress *)uploadImage:(UIImage *)image
                    withUTI:(NSString *)UTI
                   filename:(NSString *)filename
                      title:(NSString *)title
          completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler;

/**
 * Anonymously uploads an image asset to Imgur, rotating and resizing the image as needed to keep it under the maximum file size.
 *
 * @param assetURL          A URL representing an asset in the Assets Library.
 * @param title             An optional title for the uploaded image. The title is visible on the Imgur website but does not affect any part of the URL passed to the completionHandler. May be nil.
 * @param completionHandler A block to call after uploading the image, which returns nothing and takes two parameters: the Imgur URL if the upload succeeded; and an NSError object in the ImgurAnonymousAPIClientErrorDomain describing any failure. The completion handler is always called on the main thread.
 *
 * @return An NSProgress that can be used to cancel, suspend, or monitor the progress of the upload.
 */
- (NSProgress *)uploadAssetWithURL:(NSURL *)assetURL
                             title:(NSString *)title
                 completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler;

#endif

/**
 * Anonymously uploads an image from memory to Imgur.
 *
 * @param data              The image data.
 * @param filename          An optional filename for the uploaded image. The filename is visible on the Imgur website but does not affect any part of the URL passed to the completionHandler. May be nil.
 * @param title             An optional title for the uploaded image. The title is visible on the Imgur website. May be nil.
 * @param completionHandler A block to call after uploading the image data, which returns nothing and takes two parameters: the Imgur URL if the upload succeeded; and an NSError object in the ImgurAnonymousAPIClientErrorDomain describing any failure. The completionHandler is always called on the main thread.
 *
 * @return An NSProgress that can be used to cancel, suspend, or monitor the progress of the upload.
 */
- (NSProgress *)uploadImageData:(NSData *)data
                   withFilename:(NSString *)filename
                          title:(NSString *)title
              completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler;

/**
 * Anonymously uploads an image from a file to Imgur.
 *
 * @param fileURL           The URL of the image file to upload.
 * @param title             An optional title for the uploaded image. The title is visible on the Imgur website. May be nil.
 * @param completionHandler A block to call after uploading the image data, which returns nothing and takes two parameters: the Imgur URL if the upload succeeded; and an NSError object in the ImgurAnonymousAPIClientErrorDomain describing any failure. The completion handler is always called on the main thread.
 *
 * @return The resumed NSURLSessionDataTask which can be cancelled or suspended as needed.
 */
- (NSProgress *)uploadImageFile:(NSURL *)fileURL
                      withTitle:(NSString *)title
              completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler;

/**
 * Anonymously uploads an image from a stream to Imgur.
 *
 * @param stream            A stream that provides the image data.
 * @param filename          An optional filename for the uploaded image. The filename is visible on the Imgur website but does not affect any part of the URL passed to the completionHandler. May be nil.
 * @param title             An optional title for the uploaded image. The title is visible on the Imgur website. May be nil.
 * @param completionHandler A block to call after uploading the image, which returns nothing and takes two parameters: the Imgur URL if the upload succeeded; and an NSError object in the ImgurAnonymousAPIClientErrorDomain describing any failure. The completion handler is always called on the main thread.
 *
 * @return An NSProgress that can be used to cancel, suspend, or monitor the progress of the upload.
 */
- (NSProgress *)uploadStreamedImage:(NSInputStream *)stream
                       withFilename:(NSString *)filename
                              title:(NSString *)title
                  completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler;

@end

/**
 * Equal to "ImgurAnonymousAPIClientID". If you add a value for the key to your Info.plist, it will be used as the default client ID for new clients (including the convenient singleton).
 */
extern NSString * const ImgurAnonymousAPIClientInfoPlistClientIDKey;

/**
 * All errors in the ImgurAnonymousAPIClientErrorDomain have one of the error codes below set as their code, and have the ImgurAnonymousAPIClientDeveloperDescriptionKey in their userInfo dictionaries.
 */
extern NSString * const ImgurAnonymousAPIClientErrorDomain;

enum {
    
    /**
     * An error without a specific code. The error's userInfo may have an elucidating value for NSUnderlyingErrorKey.
     */
    ImgurAnonymousAPIClientUnknownError = 0,
    
    // Errors during preprocessing.
    
    /**
     * The image could not be found; for example, the file could not be read, or the asset described did not have an image representation.
     */
    ImgurAnonymousAPIClientMissingImageError = 1,
    
    // Errors returned by the Imgur API.
    
    /**
     * The uploaded image was corrupt or unacceptable. Please see https://imgur.com/faq#types for the list of acceptable image types. If you have data of an unknown format, consider using ImageIO to determine the image type and/or convert to an acceptable image type.
     */
    ImgurAnonymousAPIInvalidImageError = 400,
    
    /**
     * Authentication failed with the Imgur service. Check your client ID.
     */
    ImgurAnonymousAPIInvalidClientIDError = 403,
    
    /**
     * You've hit the limits for the application or the source IP address.
     */
    ImgurAnonymousAPIRateLimitExceededError = 429,
    
    /**
     * An unexplained error from the Imgur API.
     */
    ImgurAnonymousAPIUnexplainedError = 500,
    
    /**
     * The Imgur API response was unreadable.
     */
    ImgurAnonymousAPIUnreadableResponseError = -1,
};

/**
 * The corresponding value is a string describing what went wrong to someone who understands the source code. It is not meant for presentation.
 */
extern NSString * const ImgurAnonymousAPIClientDeveloperDescriptionKey;