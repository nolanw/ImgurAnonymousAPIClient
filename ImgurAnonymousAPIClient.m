//  ImgurAnonymousAPIClient.m
//
//  Public domain. https://github.com/nolanw/ImgurAnonymousAPIClient

#import "ImgurAnonymousAPIClient.h"
#import <ImageIO/ImageIO.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    #import <MobileCoreServices/MobileCoreServices.h>
#else
    #import <CoreServices/CoreServices.h>
#endif

#ifdef COCOAPODS
    #import <AFNetworking/AFNetworking.h>
#else
    #import "AFNetworking.h"
#endif

@interface ImgurAnonymousAPIClient () <NSURLSessionTaskDelegate>

@end

@implementation ImgurAnonymousAPIClient
{
    AFHTTPSessionManager *_session;
}

- (id)initWithClientID:(NSString *)clientID
{
    if ((self = [super init])) {
        _clientID = clientID;
        _session = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        [self updateDefaultHTTPHeaders];
    }
    return self;
}

- (void)setClientID:(NSString *)clientID
{
    _clientID = [clientID copy];
    [self updateDefaultHTTPHeaders];
}

- (id)init
{
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *clientID = [mainBundle objectForInfoDictionaryKey:ImgurAnonymousAPIClientInfoPlistClientIDKey];
    return [self initWithClientID:clientID];
}

+ (instancetype)client
{
    static ImgurAnonymousAPIClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [self new];
    });
    return client;
}

- (void)updateDefaultHTTPHeaders
{
    [_session.requestSerializer setValue:[NSString stringWithFormat:@"Client-ID %@", self.clientID]
                      forHTTPHeaderField:@"Authorization"];
}

- (NSProgress *)uploadImageData:(NSData *)data
                   withFilename:(NSString *)filename
                          title:(NSString *)title
              completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    parameters[@"type"] = @"file";
    if (title) parameters[@"title"] = title;
    NSString *MIMEType = MIMETypeForImageWithData(data);
    if (!filename) filename = DefaultFilenameForMIMEType(MIMEType);
    NSURLRequest *request = [_session.requestSerializer multipartFormRequestWithMethod:@"POST"
                                                                             URLString:@"https://api.imgur.com/3/image.json"
                                                                            parameters:parameters
                                                             constructingBodyWithBlock:^(id <AFMultipartFormData> formData)
    {
        [formData appendPartWithFileData:data name:@"image" fileName:filename mimeType:MIMEType];
    } error:nil];
    
    NSProgress *progress;
    NSURLSessionUploadTask *task = [_session uploadTaskWithStreamedRequest:request
                                                                  progress:&progress
                                                         completionHandler:^(NSURLResponse *response, id responseObject, NSError *error)
    {
        if (!completionHandler) return;
        
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
            completionHandler(nil, error);
            return;
        }
        
        if (error) {
            // Status codes are described at https://api.imgur.com/errorhandling
            switch (((NSHTTPURLResponse *)response).statusCode) {
                case 400:
                    error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                                code:ImgurAnonymousAPIInvalidImageError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"The image was rejected by Imgur",
                                                        ImgurAnonymousAPIClientDeveloperDescriptionKey: @"see valid image types at https://imgur.com/faq#types" }];
                    break;
                    
                case 403:
                    error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                                code:ImgurAnonymousAPIInvalidClientIDError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"This application is not yet configured to upload images to Imgur",
                                                        ImgurAnonymousAPIClientDeveloperDescriptionKey: @"missing or invalid client ID" }];
                    break;
                    
                case 429:
                    error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                                code:ImgurAnonymousAPIRateLimitExceededError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Too many images were uploaded recently" }];
                    break;
                    
                case 500:
                    error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                                code:ImgurAnonymousAPIUnexplainedError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Imgur is having problems" }];
                    break;
                    
                default:
                    error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                                code:ImgurAnonymousAPIClientUnknownError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"An unknown error occurred",
                                                        NSUnderlyingErrorKey: error }];
                    break;
            }
            completionHandler(nil, error);
            return;
        }
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            NSError *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                                 code:ImgurAnonymousAPIUnreadableResponseError
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Imgur did not respond as expected",
                                                         ImgurAnonymousAPIClientDeveloperDescriptionKey: @"response JSON was not a dictionary" }];
            completionHandler(nil, error);
            return;
        }
        
        NSDictionary *data = responseObject[@"data"];
        if (![data isKindOfClass:[NSDictionary class]]) {
            NSError *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                                 code:ImgurAnonymousAPIUnreadableResponseError
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Imgur did not respond as expected",
                                                         ImgurAnonymousAPIClientDeveloperDescriptionKey: @"response JSON for 'data' key was not a dictionary" }];
            completionHandler(nil, error);
            return;
        }
        
        NSURL *URL;
        NSString *link = data[@"link"];
        if ([link isKindOfClass:[NSString class]]) {
            URL = [NSURL URLWithString:link];
        }
        if (!URL) {
            NSError *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                                 code:ImgurAnonymousAPIUnreadableResponseError
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Unexpected response link",
                                                         ImgurAnonymousAPIClientDeveloperDescriptionKey: @"response JSON for ['data']['link'] did not represent a URL" }];
            completionHandler(nil, error);
            return;
        }
        
        completionHandler(URL, nil);
    }];
    [task resume];
    return progress;
}

CF_RETURNS_RETAINED static NSString * MIMETypeForImageWithData(NSData *data)
{
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, nil);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(CGImageSourceGetType(imageSource), kUTTagClassMIMEType);
    CFRelease(imageSource);
    return (__bridge NSString *)MIMEType;
}

static NSString * DefaultFilenameForMIMEType(NSString *MIMEType)
{
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)MIMEType, nil);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassFilenameExtension);
    CFRelease(UTI);
    return [NSString stringWithFormat:@"image.%@", extension];
}

- (NSProgress *)uploadImageFile:(NSURL *)fileURL
                      withTitle:(NSString *)title
              completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    // TODO write out the request body and do it
    return nil;
}

- (NSProgress *)uploadStreamedImage:(NSInputStream *)stream
                       withFilename:(NSString *)filename
                              title:(NSString *)title
                  completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    // TODO write out the request body and do it
    return nil;
}

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

- (NSProgress *)uploadImage:(UIImage *)image
                    withUTI:(NSString *)UTI
                   filename:(NSString *)filename
                      title:(NSString *)title
          completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    // TODO rotate the image if needed, resize it down to below 10MB if needed, then upload as usual.
    return nil;
}

- (NSProgress *)uploadAssetWithURL:(NSURL *)assetURL
                             title:(NSString *)title
                 completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    // TODO if it's oriented up and less than 10MB, just upload it. Otherwise go through -uploadImage:withUTI:filename:title:completionHandler:.
    return nil;
}

#endif

@end

NSString * const ImgurAnonymousAPIClientInfoPlistClientIDKey = @"ImgurAnonymousAPIClientID";

NSString * const ImgurAnonymousAPIClientErrorDomain = @"ImgurAnonymousAPIClientError";

NSString * const ImgurAnonymousAPIClientDeveloperDescriptionKey = @"ImgurAnonymousAPIClient Developer Description";
