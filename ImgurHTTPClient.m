//  ImgurHTTPClient.m
//  ImgurHTTPClient
//
//  Public domain. https://github.com/nolanw/ImgurHTTPClient

#import "ImgurHTTPClient.h"
#import <AFHTTPSessionManager.h>

@implementation ImgurHTTPClient
{
    AFHTTPSessionManager *_HTTPSession;
}

- (id)initWithClientID:(NSString *)clientID
{
    if ((self = [super init])) {
        _clientID = clientID;
        _HTTPSession = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.imgur.com/3/"]
                                                sessionConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        [self updateDefaultHeaders];
    }
    return self;
}

- (id)init
{
    // Check both the main bundle and this class's bundle for the client ID. This can help when running tests or doing other things when the app isn't the main bundle.
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *clientID = [mainBundle objectForInfoDictionaryKey:ImgurHTTPClientIDKey];
    if (!clientID) {
        NSBundle *thisBundle = [NSBundle bundleForClass:[ImgurHTTPClient class]];
        clientID = [thisBundle objectForInfoDictionaryKey:ImgurHTTPClientIDKey];
    }

    return [self initWithClientID:clientID];
}

- (void)setClientID:(NSString *)clientID
{
    _clientID = [clientID copy];
    [self updateDefaultHeaders];
}

- (void)updateDefaultHeaders
{
    [_HTTPSession.requestSerializer setValue:[NSString stringWithFormat:@"Client-ID %@", self.clientID]
                          forHTTPHeaderField:@"Authorization"];
}

+ (instancetype)client
{
    static ImgurHTTPClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [self new];
    });
    return client;
}

- (NSURLSessionDataTask *)uploadImageData:(NSData *)data
                             withFilename:(NSString *)filename
                                    title:(NSString *)title
                        completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    if (filename) {
        parameters[@"filename"] = filename;
    }
    if (title) {
        parameters[@"title"] = title;
    }
    return [self resumedUploadTaskWithParameters:parameters bodyBlock:^(id <AFMultipartFormData> formData) {
        [formData appendPartWithFormData:data name:@"image"];
    } completionHandler:completionHandler];
}

- (NSURLSessionDataTask *)uploadImageFile:(NSURL *)fileURL
                                withTitle:(NSString *)title
                        completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    if (title) {
        parameters[@"title"] = title;
    }
    return [self resumedUploadTaskWithParameters:parameters bodyBlock:^(id <AFMultipartFormData> formData) {
        NSError *error;
        BOOL ok = [formData appendPartWithFileURL:fileURL name:@"image" error:&error];
        if (!ok) {
            if (completionHandler) {
                error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain
                                            code:ImgurHTTPClientInvalidImage
                                        userInfo:@{ NSLocalizedDescriptionKey: @"The image file would not upload",
                                                    NSUnderlyingErrorKey: error }];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(nil, error);
                });
            }
        }
    } completionHandler:completionHandler];
}

- (NSURLSessionDataTask *)resumedUploadTaskWithParameters:(NSDictionary *)parameters
                                                bodyBlock:(void (^)(id <AFMultipartFormData> formData))bodyBlock
                                        completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    return [_HTTPSession POST:@"image.json"
                   parameters:parameters
    constructingBodyWithBlock:bodyBlock
                      success:^(NSURLSessionDataTask *task, NSDictionary *responseObject)
    {
        if (!completionHandler) return;
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            NSError *error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain
                                                 code:ImgurHTTPClientUnreadableResponseError
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Imgur did not respond as expected",
                                                         ImgurHTTPClientDeveloperDescriptionKey: @"response JSON was not a dictionary" }];
            completionHandler(nil, error);
            return;
        }
        
        NSDictionary *data = responseObject[@"data"];
        if (![data isKindOfClass:[NSDictionary class]]) {
            NSError *error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain
                                                 code:ImgurHTTPClientUnreadableResponseError
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Imgur did not respond as expected",
                                                         ImgurHTTPClientDeveloperDescriptionKey: @"response JSON for 'data' key was not a dictionary" }];
            completionHandler(nil, error);
            return;
        }
        
        NSURL *URL;
        NSString *link = data[@"link"];
        if ([link isKindOfClass:[NSString class]]) {
            URL = [NSURL URLWithString:link];
        }
        if (!URL) {
            NSError *error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain
                                                 code:ImgurHTTPClientUnreadableResponseError
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Unexpected response link",
                                                         ImgurHTTPClientDeveloperDescriptionKey: @"response JSON for ['data']['link'] did not represent a URL" }];
            completionHandler(nil, error);
        }
        
        completionHandler(URL, nil);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        if (!completionHandler) return;
        
        // https://api.imgur.com/errorhandling
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        switch (response.statusCode) {
            case 400:
                error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain
                                            code:ImgurHTTPClientInvalidImage
                                        userInfo:@{ NSLocalizedDescriptionKey: @"The image was rejected by Imgur",
                                                    ImgurHTTPClientDeveloperDescriptionKey: @"see valid image types at https://imgur.com/faq#types" }];
                break;
                
            case 403:
                error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain
                                            code:ImgurHTTPClientInvalidClientIDError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"This application is not yet configured to upload images to Imgur",
                                                    ImgurHTTPClientDeveloperDescriptionKey: @"missing or invalid client ID" }];
                break;
                
            case 429:
                error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain
                                            code:ImgurHTTPClientRateLimitExceededError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Too many images were uploaded recently" }];
                break;
                
            case 500:
                error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain
                                            code:ImgurHTTPClientAPIUnexplainedError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Imgur is having problems" }];
                break;
                
            default:
                error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain
                                            code:ImgurHTTPClientUnknownError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"An unknown error occurred",
                                                    NSUnderlyingErrorKey: error }];
                break;
        }
        
        completionHandler(nil, error);
    }];
}

@end

NSString * const ImgurHTTPClientIDKey = @"ImgurHTTPClientID";

NSString * const ImgurHTTPClientErrorDomain = @"ImgurHTTPClientError";

NSString * const ImgurHTTPClientDeveloperDescriptionKey = @"ImgurHTTPClient Developer Description";
