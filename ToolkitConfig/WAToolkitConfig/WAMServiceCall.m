/*
 * Copyright 2010 Microsoft Corp
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "WAMServiceCall.h"
#import "NSString+URLEncode.h"
#import "WAMultipartMime.h"

@interface NSURLRequest (NSURLRequestWithIgnoreSSL)

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host;

@end

@implementation NSURLRequest (NSURLRequestWithIgnoreSSL)

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host
{
    return YES;
}

@end

@interface WAMServiceRequest : NSObject
{
    @private
    NSURLConnection *_connection;
    NSInteger _statusCode;
    NSMutableData *_data;
    void (^_block)(NSInteger statusCode, NSData *response, NSError *error);
    NSMutableURLRequest *_request;
}

+ (WAMServiceRequest *)serviceRequestWithURL:(NSString *)url httpMethod:(NSString *)httpMethod payload:(NSData *)payload contentType:(NSString *)contentType token:(NSString *)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData *response, NSError *error))block;
+ (WAMServiceRequest *)serviceRequestWithURL:(NSString *)url token:(NSString *)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData *response, NSError *error))block;

- (void)start;

@end

@interface WAMServiceCall ()
{
    @private
    NSString *_serviceNamespace;
    NSString *_rawToken;
    NSString *_token;
}
@end

@implementation WAMServiceCall

- (id)initWithServiceNamespace:(NSString *)namespace token:(NSString *)token
{
    if ((self = [super init])) {
        _serviceNamespace = [namespace copy];
        _rawToken = [token copy];
        _token = [token URLDecode];
    }

    return self;
}

#define ISO_TIMEZONE_UTC_FORMAT    @"Z"
#define ISO_TIMEZONE_OFFSET_FORMAT @"%+02d%02d"

+ (NSString *)iso8601StringFromDate:(NSDate *)date
{
    NSTimeZone *timeZone = [NSTimeZone localTimeZone];
    NSInteger offset = [timeZone secondsFromGMT];

    date = [date dateByAddingTimeInterval:-offset];

    static NSDateFormatter *sISO8601 = nil;

    if (!sISO8601) {
        sISO8601 = [[NSDateFormatter alloc] init];

        NSMutableString *strFormat = [NSMutableString stringWithString:@"yyyy-MM-dd'T'HH:mm:ss.sss'Z'"];
        [sISO8601 setTimeStyle:NSDateFormatterFullStyle];
        [sISO8601 setDateFormat:strFormat];
    }

    return [sISO8601 stringFromDate:date];
}

- (NSString *)URLforEntity:(NSString *)entity
{
    return [NSString stringWithFormat:@"https://%@.accesscontrol.windows.net/v2/mgmt/service/%@", _serviceNamespace, entity];
}

+ (void)obtainTokenFromNamespace:(NSString *)serviceNamespace managementKey:(NSString *)managementKey withCompletionHandler:(void (^)(NSInteger statusCode, NSError *error, WAMServiceCall *client))block
{
    NSString *urlStr = [NSString stringWithFormat:@"https://%@.accesscontrol.windows.net/WRAPv0.9/", serviceNamespace];
    NSString *scope = [NSString stringWithFormat:@"https://%@.accesscontrol.windows.net/v2/mgmt/service/", serviceNamespace];
    NSString *payload = [NSString stringWithFormat:@"wrap_name=ManagementClient&wrap_password=%@&wrap_scope=%@",
                         [managementKey URLEncode], [scope URLEncode]];

    WAMServiceRequest *request = [WAMServiceRequest serviceRequestWithURL:urlStr
                                                               httpMethod:@"POST"
                                                                  payload:[payload dataUsingEncoding:NSUTF8StringEncoding]
                                                              contentType:@"application/x-www-form-urlencoded; charset=UTF-8"
                                                                    token:nil
                                                    withCompletionHandler:^(NSInteger statusCode, NSData *response, NSError *error)
    {
        if (error) {
            block(statusCode, error, nil);
            return;
        }

        NSString *str = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
        NSArray *parts = [str componentsSeparatedByString:@"&"];

        for (NSString *s in parts) {
            if ([s hasPrefix:@"wrap_access_token="]) {
                NSString *token = [s substringFromIndex:18];
                WAMServiceCall *client = [[WAMServiceCall alloc] initWithServiceNamespace:serviceNamespace token:token];

                block(200, error, client);
                break;
            }
        }
    }];

    [request start];
}

- (void)getFromEntity:(NSString *)entity withCompletionHandler:(void (^)(NSData *data, NSError *error))block
{
    NSString *urlStr = [self URLforEntity:entity];

    WAMServiceRequest *request = [WAMServiceRequest serviceRequestWithURL:urlStr
                                                                    token:_token
                                                    withCompletionHandler:^(NSInteger statusCode, NSData *response, NSError *error) {
        if (error) {
            block(nil, error);
            return;
        }

        block(response, nil);
    }];

    [request start];
}

- (void)getFromEntity:(NSString *)entity withXmlCompletionHandler:(void (^)(xmlDocPtr doc, NSError *error))block
{
    [self getFromEntity:entity withCompletionHandler:^(NSData *data, NSError *error)
    {
        if (error) {
            block(nil, error);
            return;
        }

        const char *baseURL = NULL;
        const char *encoding = NULL;

#if DEBUG
        NSString * xml = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        LOGLINE(@"XML Response: %@", xml);
#endif

        xmlDocPtr doc = xmlReadMemory([data bytes], (int)[data length], baseURL, encoding, (XML_PARSE_NOCDATA | XML_PARSE_NOBLANKS));

        error = [WAMXMLHelper checkForError:doc];

        if (error) {
            xmlFreeDoc(doc);
            block(nil, error);
            return;
        }

        block(doc, nil);
        xmlFreeDoc(doc);
    }];
}

- (void)    getFromEntity:(NSString *)entity
         atomEntryHandler:(void (^)(WAMAtomPubEntry *entry, BOOL *stop))itemHandler
    withCompletionHandler:(void (^)(NSError *error))block
{
    [self getFromEntity:entity withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error)
    {
        if (error) {
            if (block) {
                block(error);
            }

            return;
        }

        [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop)
        {
            itemHandler(entry, stop);
        }];

        if (block) {
            block(nil);
        }
    }];
}

- (void)getFromEntity:(NSString *)entity withAtomCompletionHandler:(void (^)(WAMAtomPubEntry *entry, NSError *error, BOOL *stop))block
{
    [self getFromEntity:entity withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error)
    {
        if (error) {
            BOOL stop = NO;
            block(nil, error, &stop);
            return;
        }

        [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop)
        {
            block(entry, nil, stop);
        }];
    }];
}

- (void)deleteFromEntity:(NSString *)entity withCompletionHandler:(void (^)(NSError *error))block
{
    NSString *urlStr = [self URLforEntity:entity];

    WAMServiceRequest *request = [WAMServiceRequest serviceRequestWithURL:urlStr
                                                               httpMethod:@"DELETE"
                                                                  payload:nil
                                                              contentType:nil
                                                                    token:_token
                                                    withCompletionHandler:^(NSInteger statusCode, NSData *response, NSError *error)
    {
        block(error);
    }];

    [request start];
}

- (WAMultipartMime *)createMimeBody
{
    return [[WAMultipartMime alloc] initWithServiceClient:self];
}

- (void)sendBatch:(WAMultipartMime *)mimeBody mimeEntryHandler:(void (^)(xmlDocPtr doc))itemHandler withCompletionHandler:(void (^)(NSError *error))block
{
    NSData *data = [mimeBody data];
    NSString *urlStr = [self URLforEntity:@"$batch"];
    NSString *contentType = [NSString stringWithFormat:@"multipart/mixed; boundary=batch_%@", mimeBody.batchIdentity];

#if DEBUG
    NSString *str1 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    LOGLINE(@"%@", str1);
#endif

    WAMServiceRequest *request = [WAMServiceRequest serviceRequestWithURL:urlStr
                                                               httpMethod:@"POST"
                                                                  payload:data
                                                              contentType:contentType
                                                                    token:_token
                                                    withCompletionHandler:^(NSInteger statusCode, NSData *response, NSError *error)
    {
        if (error) {
            block(error);
            return;
        }

        NSString *str = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
        NSArray *lines = [str componentsSeparatedByString:@"\r\n"];

        if (lines.count == 0) {
            LOGLINE(@"Payload body is missing?");
            // weird...
            block(nil);
            return;
        }

        if (![lines[0] hasPrefix:@"--batchresponse"]) {
            LOGLINE(@"Invalid MIME body");

            // weird...
            block(nil);
            return;
        }

        NSString *boundary = [@"--" stringByAppendingString :[lines[1] componentsSeparatedByString:@"="][1]];

        NSMutableDictionary *contentHeaders = nil;
        NSMutableString *body = nil;
        BOOL gotHeader = NO;
        BOOL gotSeparator = NO;
        BOOL collecting = NO;

        for (NSString *s in lines) {
            if ([s hasPrefix:boundary]) {
                if (body) {
                    NSData *bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
                    const char *baseURL = NULL;
                    const char *encoding = NULL;
                    xmlDocPtr doc = xmlReadMemory([bodyData bytes], (int)[bodyData length], baseURL, encoding, (XML_PARSE_NOCDATA | XML_PARSE_NOBLANKS));

                    error = [WAMXMLHelper checkForError:doc];

                    if (error) {
                        xmlFreeDoc(doc);
                        block(error);
                        return;
                    }

                    if (itemHandler) {
                        itemHandler(doc);
                    }

                    xmlFreeDoc(doc);

                    body = nil;
                    gotHeader = NO;
                    gotSeparator = NO;
                    contentHeaders = nil;
                } else {
                    collecting = YES;
                }
            } else if (!collecting) {
                continue;
            } else if (gotSeparator && !gotHeader) {
                if (!s.length) {
                    gotHeader = YES;
                } else if (!contentHeaders) {
                    contentHeaders = [NSMutableDictionary dictionaryWithCapacity:10];
                } else {
                    NSRange r = [s rangeOfString:@":"];

                    if (r.length > 0) {
                        NSString *key = [[s substringToIndex:r.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        NSString *value = [[s substringFromIndex:1 + r.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                        contentHeaders[key] = value;
                    }
                }
            } else if (gotHeader) {
                if (!body) {
                    body = [NSMutableString stringWithCapacity:2000];
                }

                [body appendFormat:@"%@\n", s];
            } else if (!s.length) {
                gotSeparator = YES;
            }
        }

        // ok, we're done
        block(nil);
    }];

    [request start];
}

@end

@implementation WAMServiceRequest

- (id)initServiceRequestWithURL:(NSString *)url httpMethod:(NSString *)httpMethod payload:(NSData *)payload contentType:(NSString *)contentType token:(NSString *)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData *response, NSError *error))block
{
    if ((self = [super init])) {
        _block = [block copy];

        _request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];

        [_request setHTTPMethod:httpMethod];
        [_request setHTTPShouldHandleCookies:NO];
        [_request setValue:@"Microsoft ADO.NET Data Services" forHTTPHeaderField:@"User-Agent"];

        if (payload) {
            [_request setHTTPBody:payload];
            [_request setValue:contentType forHTTPHeaderField:@"Content-Type"];
        }

        if (token) {
            NSString *wrapper = [NSString stringWithFormat:@"WRAP access_token=\"%@\"", token];
            [_request setValue:wrapper forHTTPHeaderField:@"Authorization"];

            [_request setValue:@"UTF-8" forHTTPHeaderField:@"Accept-Charset"];
            [_request setValue:@"application/atom+xml,application/xml" forHTTPHeaderField:@"Accept"];
            [_request setValue:@"1.0;NetFx" forHTTPHeaderField:@"DataServiceVersion"];
            [_request setValue:@"2.0;NetFx" forHTTPHeaderField:@"MaxDataServiceVersion"];
        }

        LOGLINE(@"%@ %@", httpMethod, url);
        LOGLINE(@"Headers: %@", [_request allHTTPHeaderFields]);

        // _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    }

    return self;
}

+ (WAMServiceRequest *)serviceRequestWithURL:(NSString *)url httpMethod:(NSString *)httpMethod payload:(NSData *)payload contentType:(NSString *)contentType token:(NSString *)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData *response, NSError *error))block
{
    return [[self alloc] initServiceRequestWithURL:url httpMethod:httpMethod payload:payload contentType:contentType token:token withCompletionHandler:block];
}

+ (WAMServiceRequest *)serviceRequestWithURL:(NSString *)url token:(NSString *)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData *response, NSError *error))block
{
    return [[self alloc] initServiceRequestWithURL:url httpMethod:@"GET" payload:nil contentType:nil token:token withCompletionHandler:block];
}

- (void)start
{
    _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    _statusCode = [response statusCode];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_data) {
        [_data appendData:data];
    } else {
        _data = [data mutableCopy];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    _block(_statusCode, nil, error);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSError *error = nil;

    if (_statusCode >= 300) {
        error = [NSError errorWithDomain:@"com.microsoft.WAToolkitConfig"
                                    code:_statusCode
                                userInfo:@{NSLocalizedDescriptionKey: @"Invalid HTTP status returned.\nInsure your ACS management key is correct."}];
        _block(_statusCode, nil, error);
        return;
    }

    _block(_statusCode, _data, nil);
}

@end