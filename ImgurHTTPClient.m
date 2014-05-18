//  ImgurHTTPClient.m
//  ImgurHTTPClient
//
//  Public domain. https://github.com/nolanw/ImgurHTTPClient

#import "ImgurHTTPClient.h"

@interface ImgurHTTPClient ()

@property (strong, nonatomic) NSURLSession *URLSession;

@end

@implementation ImgurHTTPClient
{
    NSURLSession *_URLSession;
}

- (id)initWithClientID:(NSString *)clientID
{
    if ((self = [super init])) {
        _clientID = clientID;
    }
    return self;
}

- (id)init
{
    return [self initWithClientID:nil];
}

- (void)setClientID:(NSString *)clientID
{
    NSString *oldClientID = _clientID;
    _clientID = [clientID copy];
    if (!(oldClientID == clientID || [oldClientID isEqualToString:clientID])) {
        _URLSession = nil;
    }
}

+ (instancetype)client
{
    static ImgurHTTPClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // Check both the main bundle and this class's bundle for the client ID. This can help run tests or other times when the app isn't the main bundle.
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *clientID = [mainBundle objectForInfoDictionaryKey:ImgurHTTPClientIDKey];
        if (!clientID) {
            NSBundle *thisBundle = [NSBundle bundleForClass:[ImgurHTTPClient class]];
            clientID = [thisBundle objectForInfoDictionaryKey:ImgurHTTPClientIDKey];
        }
        
        client = [[self alloc] initWithClientID:clientID];
    });
    return client;
}

- (NSURLSession *)URLSession
{
    if (_URLSession) return _URLSession;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.HTTPAdditionalHeaders = @{ @"Authorization": [NSString stringWithFormat:@"Client-ID %@", self.clientID] };
    _URLSession = [NSURLSession sessionWithConfiguration:configuration];
    return _URLSession;
}

- (NSProgress *)uploadImageData:(NSData *)data
                   withFilename:(NSString *)filename
                          title:(NSString *)title
              completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.imgur.com/3/image.json"]];
    request.HTTPMethod = @"POST";
    NSURLSessionUploadTask *task = [self.URLSession uploadTaskWithRequest:request fromData:data completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        if (!completionHandler) return;
        
        if (error) {
            // TODO wrap in our error
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
            });
            return;
        }
        
        NSDictionary *responseInfo = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
        if (!responseInfo) {
            // TODO wrap in our error
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
            });
            return;
        }
        if (![responseInfo isKindOfClass:[NSDictionary class]]) {
            // TODO clarify error
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, [NSError errorWithDomain:ImgurHTTPClientErrorDomain code:ImgurHTTPClientUnknownError userInfo:nil]);
            });
            return;
        }
        
        NSInteger HTTPStatusCode = ((NSHTTPURLResponse *)response).statusCode;
        if (HTTPStatusCode != 200) {
            if (HTTPStatusCode == 403) {
                NSString *description = @"Invalid client ID";
                error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain code:ImgurHTTPClientInvalidClientIDError userInfo:@{ NSLocalizedDescriptionKey: description }];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(nil, error);
                });
            }
            
            // TODO handle other expected errors
            
            else {
                NSString *description = [NSString stringWithFormat:@"Unexpected HTTP status code: %ld", (long)HTTPStatusCode];
                error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain code:ImgurHTTPClientUnknownError userInfo:@{ NSLocalizedDescriptionKey: description }];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(nil, error);
                });
            }
            return;
        }
        
        NSDictionary *data = responseInfo[@"data"];
        if (![data isKindOfClass:[NSDictionary class]]) {
            NSString *description = @"Unexpected response data";
            error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain code:ImgurHTTPClientUnknownError userInfo:@{ NSLocalizedDescriptionKey: description }];
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
            });
            return;
        }
        
        NSString *link = data[@"link"];
        if (![link isKindOfClass:[NSString class]]) {
            NSString *description = @"Unexpected response link";
            error = [NSError errorWithDomain:ImgurHTTPClientErrorDomain code:ImgurHTTPClientUnknownError userInfo:@{ NSLocalizedDescriptionKey: description }];
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
            });
        }
        
        NSURL *URL = [NSURL URLWithString:link];
        
        progress.completedUnitCount = 1;
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(URL, nil);
        });
    }];
    
    progress.cancellationHandler = ^{
        [task cancel];
    };
    
    [task resume];
    return progress;
}

- (NSProgress *)uploadImageFile:(NSURL *)fileURL withTitle:(NSString *)title completionHandler:(void (^)(NSURL *imgurURL, NSError *error))completionHandler
{
    return nil;
}

@end

NSString * const ImgurHTTPClientIDKey = @"ImgurHTTPClientID";

NSString * const ImgurHTTPClientErrorDomain = @"ImgurHTTPClientError";
