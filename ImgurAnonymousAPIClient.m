//  ImgurAnonymousAPIClient.m
//
//  Public domain. https://github.com/nolanw/ImgurAnonymousAPIClient

#import "ImgurAnonymousAPIClient.h"
#import <ImageIO/ImageIO.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    #import <AssetsLibrary/AssetsLibrary.h>
    #import <MobileCoreServices/MobileCoreServices.h>
#else
    #import <CoreServices/CoreServices.h>
#endif

#ifdef COCOAPODS
    #import <AFNetworking/AFNetworking.h>
#else
    #import "AFNetworking.h"
#endif

/**
 * An ImgurAnonymousAPIResponseSerializer serializes an Imgur API response into an NSURL pointing to the uploaded image and returns an error in the ImgurAnonymousAPIClientErrorDomain.
 */
@interface ImgurAnonymousAPIResponseSerializer : AFJSONResponseSerializer

@end

/**
 * An ImgurAssetInputStream streams a representation of an ALAsset.
 */
@interface ImgurAssetInputStream : NSInputStream

/**
 * Designated initializer.
 *
 * @param assetURL A URL representing an asset in the Assets Library.
 * @param UTI      The UTI of the representation to stream, or nil to use the default representation.
 */
- (id)initWithAssetURL:(NSURL *)assetURL representationUTI:(NSString *)UTI;

@property (readonly, strong, nonatomic) NSURL *assetURL;

@property (readonly, copy, nonatomic) NSString *representationUTI;

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
        _session.responseSerializer = [ImgurAnonymousAPIResponseSerializer serializer];
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
    NSString *MIMEType = MIMETypeForImageWithData(data);
    if (!filename) filename = DefaultFilenameForMIMEType(MIMEType);
    NSURLSessionUploadTask *task = [self resumedUploadTaskWithTitle:title bodyBlock:^(id <AFMultipartFormData> formData) {
        [formData appendPartWithFileData:data name:@"image" fileName:filename mimeType:MIMEType];
    } completionHandler:completionHandler];
    return [_session uploadProgressForTask:task];
}

- (NSProgress *)uploadImageFile:(NSURL *)fileURL
                      withTitle:(NSString *)title
              completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    // There does not seem to be a way to tell AFNetworking why the request failed to build (or even that it failed at all), so we save that error here and wrap the provided completion handler.
    __block NSError *requestError;
    __block NSURLSessionUploadTask *task = [self resumedUploadTaskWithTitle:title bodyBlock:^(id <AFMultipartFormData> formData) {
        NSError *error;
        BOOL ok = [formData appendPartWithFileURL:fileURL name:@"image" error:&error];
        if (!ok) {
            requestError = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                               code:ImgurAnonymousAPIClientMissingImageError
                                           userInfo:@{ NSLocalizedDescriptionKey: @"The image file could not be read",
                                                       NSUnderlyingErrorKey: error }];
            [task cancel];
        }
    } completionHandler:^(NSURL *imgurURL, NSError *error) {
        if (completionHandler) completionHandler(imgurURL, requestError ?: error);
    }];
    return [_session uploadProgressForTask:task];
}

- (NSProgress *)uploadStreamedImage:(NSInputStream *)stream
                             length:(int64_t)length
                            withUTI:(NSString *)UTI
                           filename:(NSString *)filename
                              title:(NSString *)title
                  completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    if (!filename) filename = DefaultFilenameForUTI(UTI);
    NSString *MIMEType = MIMETypeForUTI(UTI);
    NSURLSessionUploadTask *task = [self resumedUploadTaskWithTitle:title bodyBlock:^(id <AFMultipartFormData> formData) {
        [formData appendPartWithInputStream:stream name:@"image" fileName:filename length:length mimeType:MIMEType];
    } completionHandler:completionHandler];
    return [_session uploadProgressForTask:task];
}

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

- (NSProgress *)uploadImage:(UIImage *)image
                    withUTI:(NSString *)UTI
                   filename:(NSString *)filename
                      title:(NSString *)title
          completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        CGSize targetSize = image.size;
        
        // If we aim for too large an image right off the bat we'll just crash under memory pressure. I picked this size because it doesn't crash my 5th generation iPod touch.
        const CGFloat ArbitraryMaximumPixelCount = ArbitraryMaximumPixelWidthToAvoidRunningOutOfMemoryAndCrashing * ArbitraryMaximumPixelWidthToAvoidRunningOutOfMemoryAndCrashing;
        while (targetSize.width * image.scale * targetSize.height * image.scale > ArbitraryMaximumPixelCount) {
            targetSize.width /= 2;
            targetSize.height /= 2;
        }
        
        NSData *data;
        for (;;) @autoreleasepool {
            if (progress.cancelled) break;
            UIImage *serializableImage = image;
            if (!(image.imageOrientation == UIImageOrientationUp && CGSizeEqualToSize(image.size, targetSize))) {
                UIGraphicsBeginImageContextWithOptions(targetSize, NO, image.scale);
                [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
                serializableImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
            }
            data = [UTI isEqualToString:(id)kUTTypeJPEG] ? UIImageJPEGRepresentation(serializableImage, 0.9) : UIImagePNGRepresentation(serializableImage);
            if (data.length <= TenMegabytes || progress.cancelled) break;
            targetSize.width /= 2;
            targetSize.height /= 2;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (progress.cancelled) {
                if (completionHandler) {
                    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionHandler(nil, error);
                    });
                }
                return;
            }
            progress.completedUnitCount++;
            
            [progress becomeCurrentWithPendingUnitCount:1];
            [self uploadImageData:data withFilename:filename title:title completionHandler:completionHandler];
            [progress resignCurrent];
        });
    });
    return progress;
}

static const CGFloat ArbitraryMaximumPixelWidthToAvoidRunningOutOfMemoryAndCrashing = 5000;

- (NSProgress *)uploadAssetWithURL:(NSURL *)assetURL
                             title:(NSString *)title
                 completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    dispatch_semaphore_t flag = dispatch_semaphore_create(0);
    ALAssetsLibrary *library = [ALAssetsLibrary new];
    __block ALAssetRepresentation *representation;
    __block NSError *underlyingError;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
            representation = asset.defaultRepresentation;
            dispatch_semaphore_signal(flag);
        } failureBlock:^(NSError *error) {
            underlyingError = error;
            dispatch_semaphore_signal(flag);
        }];
    });
    dispatch_semaphore_wait(flag, DISPATCH_TIME_FOREVER);
    
    if (!representation || !UTTypeConformsTo((__bridge CFStringRef)representation.UTI, kUTTypeImage)) {
        NSMutableDictionary *userInfo = [NSMutableDictionary new];
        userInfo[NSLocalizedDescriptionKey] = @"The image could not be found";
        if (underlyingError) userInfo[NSUnderlyingErrorKey] = underlyingError;
        NSError *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain code:ImgurAnonymousAPIClientMissingImageError userInfo:userInfo];
        if (completionHandler) completionHandler(nil, error);
        return nil;
    }
    
    // GIFs and sufficiently-small files that don't need rotation can be uploaded directly.
    if ([representation.UTI isEqualToString:(id)kUTTypeGIF] || (representation.orientation == ALAssetOrientationUp && representation.size <= TenMegabytes)) {
        NSURLSessionUploadTask *task = [self resumedUploadTaskWithTitle:title bodyBlock:^(id <AFMultipartFormData> formData) {
            ImgurAssetInputStream *stream = [[ImgurAssetInputStream alloc] initWithAssetURL:assetURL representationUTI:representation.UTI];
            NSString *MIMEType = MIMETypeForUTI(representation.UTI);
            [formData appendPartWithInputStream:stream name:@"image" fileName:representation.filename length:representation.size mimeType:MIMEType];
        } completionHandler:completionHandler];
        return [_session uploadProgressForTask:task];
    }
    
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        // Start with a smaller image directly from the asset. Does not require loading the whole image into memory.
        // http://mindsea.com/2012/12/18/downscaling-huge-alassets-without-fear-of-sigkill
        CGDataProviderDirectCallbacks callbacks = {
            .getBytesAtPosition = getAssetBytesCallback,
            .releaseInfo = releaseAssetCallback,
        };
        CGDataProviderRef provider = CGDataProviderCreateDirect((void *)CFBridgingRetain(representation), representation.size, &callbacks);
        CGImageSourceRef imageSource = CGImageSourceCreateWithDataProvider(provider, nil);
        NSDictionary *options = @{ (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                                   (id)kCGImageSourceThumbnailMaxPixelSize: @(ArbitraryMaximumPixelWidthToAvoidRunningOutOfMemoryAndCrashing),
                                   (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES };
        CGImageRef thumbnailImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
        CFRelease(imageSource);
        CFRelease(provider);
        
        UIImage *image;
        if (thumbnailImage) {
            image = [UIImage imageWithCGImage:thumbnailImage];
            CFRelease(thumbnailImage);
        } else {
            image = [UIImage imageWithCGImage:representation.fullResolutionImage scale:representation.scale orientation:(UIImageOrientation)representation.orientation];
        }
        
        progress.completedUnitCount++;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [progress becomeCurrentWithPendingUnitCount:1];
            [self uploadImage:image withUTI:representation.UTI filename:representation.filename title:title completionHandler:completionHandler];
            [progress resignCurrent];
        });
    });
    return progress;
}

static size_t getAssetBytesCallback(void *info, void *buffer, off_t position, size_t count)
{
    ALAssetRepresentation *representation = (__bridge ALAssetRepresentation *)info;
    return [representation getBytes:buffer fromOffset:position length:count error:nil];
}

static void releaseAssetCallback(void *info)
{
    CFRelease(info);
}

static const long long TenMegabytes = 10485760;

#endif

static NSString * MIMETypeForImageWithData(NSData *data)
{
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, nil);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(CGImageSourceGetType(imageSource), kUTTagClassMIMEType);
    CFRelease(imageSource);
    return CFBridgingRelease(MIMEType);
}

static NSString * MIMETypeForUTI(NSString *UTI)
{
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
    return CFBridgingRelease(MIMEType);
}

static NSString * DefaultFilenameForUTI(NSString *UTI)
{
    NSString *extension = CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassFilenameExtension));
    return [NSString stringWithFormat:@"image.%@", extension];

}

static NSString * DefaultFilenameForMIMEType(NSString *MIMEType)
{
    NSString *UTI = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)MIMEType, nil));
    return DefaultFilenameForUTI(UTI);
}

- (NSURLSessionUploadTask *)resumedUploadTaskWithTitle:(NSString *)title
                                             bodyBlock:(void (^)(id <AFMultipartFormData>))bodyBlock
                                     completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    parameters[@"type"] = @"file";
    if (title) parameters[@"title"] = title;
    NSURLRequest *request = [_session.requestSerializer multipartFormRequestWithMethod:@"POST"
                                                                             URLString:@"https://api.imgur.com/3/image.json"
                                                                            parameters:parameters
                                                             constructingBodyWithBlock:bodyBlock
                                                                                 error:nil];
    NSURLSessionUploadTask *task = [_session uploadTaskWithStreamedRequest:request
                                                                  progress:nil
                                                         completionHandler:^(NSURLResponse *response, NSURL *imgurURL, NSError *error)
    {
        if (completionHandler) completionHandler(imgurURL, error);
    }];
    [task resume];
    return task;
}

@end

@implementation ImgurAnonymousAPIResponseSerializer

- (BOOL)validateResponse:(NSHTTPURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error
{
    NSError *superError;
    if ([super validateResponse:response data:data error:&superError]) return YES;
    if (!error) return NO;
    
    // Status codes are described at https://api.imgur.com/errorhandling
    if ([superError.domain isEqualToString:ImgurAnonymousAPIClientErrorDomain]) {
        *error = superError;
    } else if (response.statusCode == 400) {
        *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                     code:ImgurAnonymousAPIInvalidImageError
                                 userInfo:@{ NSLocalizedDescriptionKey: @"The image was rejected by Imgur",
                                             ImgurAnonymousAPIClientDeveloperDescriptionKey: @"see valid image types at https://imgur.com/faq#types" }];
    } else if (response.statusCode == 403) {
        *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                     code:ImgurAnonymousAPIInvalidClientIDError
                                 userInfo:@{ NSLocalizedDescriptionKey: @"This application is not yet configured to upload images to Imgur",
                                             ImgurAnonymousAPIClientDeveloperDescriptionKey: @"missing or invalid client ID" }];
    } else if (response.statusCode == 429) {
        *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                     code:ImgurAnonymousAPIRateLimitExceededError
                                 userInfo:@{ NSLocalizedDescriptionKey: @"Too many images were uploaded recently" }];
    } else if (response.statusCode == 500) {
        *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                     code:ImgurAnonymousAPIUnexplainedError
                                 userInfo:@{ NSLocalizedDescriptionKey: @"Imgur is having problems" }];
    } else {
        *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                     code:ImgurAnonymousAPIClientUnknownError
                                 userInfo:@{ NSLocalizedDescriptionKey: @"An unknown error occurred",
                                             NSUnderlyingErrorKey: superError }];
    }
    return NO;
}

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error
{
    NSDictionary *responseObject = [super responseObjectForResponse:response data:data error:error];
    if (!responseObject) return nil;
    
    if (![responseObject isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                         code:ImgurAnonymousAPIUnreadableResponseError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Imgur did not respond as expected",
                                                 ImgurAnonymousAPIClientDeveloperDescriptionKey: @"response JSON was not a dictionary" }];
        }
        return nil;
    }
    
    responseObject = responseObject[@"data"];
    if (![responseObject isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                         code:ImgurAnonymousAPIUnreadableResponseError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Imgur did not respond as expected",
                                                 ImgurAnonymousAPIClientDeveloperDescriptionKey: @"response JSON for 'data' key was not a dictionary" }];
        }
        return nil;
    }
    
    NSURL *URL;
    NSString *link = responseObject[@"link"];
    if ([link isKindOfClass:[NSString class]]) {
        URL = [NSURL URLWithString:link];
    }
    if (!URL) {
        NSString *imgurError = responseObject[@"error"];
        if (![imgurError isKindOfClass:[NSString class]]) imgurError = nil;
        if (error) {
            *error = [NSError errorWithDomain:ImgurAnonymousAPIClientErrorDomain
                                         code:ImgurAnonymousAPIUnreadableResponseError
                                     userInfo:@{ NSLocalizedDescriptionKey: imgurError ?: @"Unexpected response from Imgur",
                                                 ImgurAnonymousAPIClientDeveloperDescriptionKey: @"response JSON for ['data']['link'] did not represent a URL" }];
        }
        return nil;
    }
    
    return URL;
}

@end

@interface ImgurAssetInputStream ()

@property (assign, nonatomic) NSStreamStatus streamStatus;
@property (strong, nonatomic) NSError *streamError;

@end

@implementation ImgurAssetInputStream
{
    ALAssetsLibrary *_library;
    ALAssetRepresentation *_assetRepresentation;
    NSUInteger _readIndex;
}

- (id)initWithAssetURL:(NSURL *)assetURL representationUTI:(NSString *)UTI
{
    if ((self = [super init])) {
        _assetURL = assetURL;
        _representationUTI = UTI;
    }
    return self;
}

- (void)open
{
    self.streamStatus = NSStreamStatusOpening;
    dispatch_semaphore_t flag = dispatch_semaphore_create(0);
    _library = [ALAssetsLibrary new];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_library assetForURL:self.assetURL resultBlock:^(ALAsset *asset) {
            _assetRepresentation = self.representationUTI ? [asset representationForUTI:self.representationUTI] : asset.defaultRepresentation;
            self.streamStatus = NSStreamStatusOpen;
            dispatch_semaphore_signal(flag);
        } failureBlock:^(NSError *error) {
            self.streamStatus = NSStreamStatusError;
            self.streamError = error;
            dispatch_semaphore_signal(flag);
        }];
    });
    dispatch_semaphore_wait(flag, DISPATCH_TIME_FOREVER);
}

- (void)close
{
    _library = nil;
    _assetRepresentation = nil;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length
{
    NSError *error;
    NSUInteger read = [_assetRepresentation getBytes:buffer fromOffset:_readIndex length:length error:&error];
    if (read == 0) {
        self.streamError = error;
        self.streamStatus = error ? NSStreamStatusError : NSStreamStatusAtEnd;
    }
    _readIndex += read;
    return read;
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)length
{
    return NO;
}

- (BOOL)hasBytesAvailable
{
    return _readIndex < (NSUInteger)_assetRepresentation.size;
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{}

- (id)propertyForKey:(NSString *)key
{
    return nil;
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key
{
    return NO;
}

@end

NSString * const ImgurAnonymousAPIClientInfoPlistClientIDKey = @"ImgurAnonymousAPIClientID";

NSString * const ImgurAnonymousAPIClientErrorDomain = @"ImgurAnonymousAPIClientError";

NSString * const ImgurAnonymousAPIClientDeveloperDescriptionKey = @"ImgurAnonymousAPIClient Developer Description";
