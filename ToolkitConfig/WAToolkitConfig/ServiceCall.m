/*
 Copyright 2010 Microsoft Corp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "ServiceCall.h"
#import "NSString+URLEncode.h"
#import "WAMultipartMime.h"

@interface NSURLRequest (NSURLRequestWithIgnoreSSL)

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString*)host;

@end

@implementation NSURLRequest (NSURLRequestWithIgnoreSSL)

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host
{
    return YES;
}

@end

@interface ServiceRequest : NSObject 
{
@private
	NSURLConnection *_connection;
	NSInteger _statusCode;
	NSMutableData *_data;
	void (^_block)(NSInteger statusCode, NSData *response, NSError *error);
}

+ (void) createServiceRequestWithURL:(NSString*)url httpMethod:(NSString*)httpMethod payload:(NSData*)payload contentType:(NSString*)contentType token:(NSString*)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData* response, NSError* error))block;
+ (void) createServiceRequestWithURL:(NSString*)url token:(NSString*)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData* response, NSError* error))block;

@end

@implementation ServiceCall

- (id) initWithServiceNamespace:(NSString*)namespace token:(NSString*)token
{
	if((self = [super init]))
	{
		_serviceNamespace = [namespace copy];
		_rawToken = [token copy];
		_token = [[token URLDecode] retain];
	}
	
	return self;
}

- (void)dealloc
{
	[_serviceNamespace release];
	[_rawToken release];
	[_token release];
	[super dealloc];
}

#define ISO_TIMEZONE_UTC_FORMAT @"Z"
#define ISO_TIMEZONE_OFFSET_FORMAT @"%+02d%02d"

+ (NSString*)iso8601StringFromDate:(NSDate*)date
{
	NSTimeZone *timeZone = [NSTimeZone localTimeZone];
	NSInteger offset = [timeZone secondsFromGMT];
	date = [date dateByAddingTimeInterval:-offset];
	
    static NSDateFormatter* sISO8601 = nil;
	
    if (!sISO8601) 
	{
        sISO8601 = [[NSDateFormatter alloc] init];
		
		NSMutableString *strFormat = [NSMutableString stringWithString:@"yyyy-MM-dd'T'HH:mm:ss.sss'Z'"];
        [sISO8601 setTimeStyle:NSDateFormatterFullStyle];
        [sISO8601 setDateFormat:strFormat];
    }
	
    return [sISO8601 stringFromDate:date];
}

- (NSString*)URLforEntity:(NSString*)entity
{
	return [NSString stringWithFormat:@"https://%@.accesscontrol.windows.net/v2/mgmt/service/%@", _serviceNamespace, entity];
}

+ (void) obtainTokenFromNamespace:(NSString*)serviceNamespace managementKey:(NSString*)managementKey withCompletionHandler:(void (^)(NSInteger statusCode, NSError* error, ServiceCall* client))block
{
	NSString* urlStr = [NSString stringWithFormat:@"https://%@.accesscontrol.windows.net/WRAPv0.9/", serviceNamespace];
	NSString* scope = [NSString stringWithFormat:@"https://%@.accesscontrol.windows.net/v2/mgmt/service/", serviceNamespace];
	NSString* payload = [NSString stringWithFormat:@"wrap_name=ManagementClient&wrap_password=%@&wrap_scope=%@",
						 [managementKey URLEncode], [scope URLEncode]];
	
	[ServiceRequest createServiceRequestWithURL:urlStr
									 httpMethod:@"POST" 
										payload:[payload dataUsingEncoding:NSUTF8StringEncoding] 
									contentType:@"application/x-www-form-urlencoded; charset=UTF-8"
										  token:nil
						  withCompletionHandler:^(NSInteger statusCode, NSData *response, NSError* error) 
	      {
			  if(error)
			  {
				  block(statusCode, error, nil);
				  return;
			  }
			  
			  NSString* str = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
			  NSArray* parts = [str componentsSeparatedByString:@"&"];
			  [str release];
			  
			  for(NSString* s in parts)
			  {
				  if([s hasPrefix:@"wrap_access_token="])
				  {
					  NSString* token = [s substringFromIndex:18];
					  ServiceCall* client = [[ServiceCall alloc] initWithServiceNamespace:serviceNamespace token:token];
					  
					  block(200, error, client);
					  [client release];
					  break;
				  }
			  }
			  
		  }];
}

- (void) getFromEntity:(NSString*)entity withCompletionHandler:(void (^)(NSData* data, NSError* error))block
{
	NSString* urlStr = [self URLforEntity:entity];
	
	[ServiceRequest createServiceRequestWithURL:urlStr 
										  token:_token 
						  withCompletionHandler:^(NSInteger statusCode, NSData *response, NSError *error) {
							  if(error)
							  {
								  block(nil, error);
								  return;
							  }
							  
							  block(response, nil);
						  }];
}

- (void) getFromEntity:(NSString*)entity withXmlCompletionHandler:(void (^)(xmlDocPtr doc, NSError* error))block
{
	[self getFromEntity:entity withCompletionHandler:^(NSData *data, NSError *error) 
	{
		if(error)
		{
			block(nil, error);
			return;
		}
		
		const char *baseURL = NULL;
		const char *encoding = NULL;

#if DEBUG
		NSString* xml = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		LOGLINE(@"XML Response: %@", xml);
		[xml release];
#endif
		
		xmlDocPtr doc = xmlReadMemory([data bytes], (int)[data length], baseURL, encoding, (XML_PARSE_NOCDATA | XML_PARSE_NOBLANKS)); 
		
		error = [WAXMLHelper checkForError:doc];
		if(error)
		{
			xmlFreeDoc(doc);
			block(nil, error);
			return;
		}

		block(doc, nil);
		xmlFreeDoc(doc);
	}];
}

- (void) getFromEntity:(NSString*)entity 
	  atomEntryHandler:(void (^)(WAAtomPubEntry* entry, BOOL* stop))itemHandler 
 withCompletionHandler:(void (^)(NSError* error))block
{
	[self getFromEntity:entity withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error) 
	 {
		 if(error)
		 {
			 if(block)
			 {
				 block(error);
			 }
			 return;
		 }
		 
		 [WAXMLHelper parseAtomPub:doc block:^(WAAtomPubEntry* entry, NSInteger index, BOOL* stop) 
		  {
			  itemHandler(entry, stop);
		  }];
		 
		 if(block)
		 {
			 block(nil);
		 }
	 }];
}

- (void) getFromEntity:(NSString*)entity withAtomCompletionHandler:(void (^)(WAAtomPubEntry* entry, NSError* error, BOOL* stop))block
{
	[self getFromEntity:entity withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error) 
	{
		if(error)
		{
			BOOL stop = NO;
			block(nil, error, &stop);
			return;
		}
		
		[WAXMLHelper parseAtomPub:doc block:^(WAAtomPubEntry* entry, NSInteger index, BOOL* stop) 
		{
			block(entry, nil, stop);
		}];
	}];
}

- (void) deleteFromEntity:(NSString*)entity withCompletionHandler:(void (^)(NSError* error))block
{
	NSString* urlStr = [self URLforEntity:entity];
	
	[ServiceRequest createServiceRequestWithURL:urlStr 
									 httpMethod:@"DELETE" 
										payload:nil 
									contentType:nil
										  token:_token 
						  withCompletionHandler:^(NSInteger statusCode, NSData *response, NSError *error) 
	 {
		 block(error);
	 }];
}

- (WAMultipartMime*) createMimeBody
{
	return [[[WAMultipartMime alloc] initWithServiceClient:self] autorelease];
}

- (void) sendBatch:(WAMultipartMime*)mimeBody mimeEntryHandler:(void (^)(xmlDocPtr doc))itemHandler withCompletionHandler:(void (^)(NSError* error))block
{
	NSData* data = [mimeBody data];
	NSString* urlStr = [self URLforEntity:@"$batch"];
	NSString* contentType = [NSString stringWithFormat:@"multipart/mixed; boundary=batch_%@", mimeBody.batchIdentity];
	
#if DEBUG
	NSString* str1 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	LOGLINE(@"%@", str1);	
    [str1 release];
#endif
	
	[ServiceRequest createServiceRequestWithURL:urlStr
									 httpMethod:@"POST" 
										payload:data 
									contentType:contentType
										  token:_token
						  withCompletionHandler:^(NSInteger statusCode, NSData *response, NSError* error) 
	 {
		 if(error)
		 {
			 block(error);
			 return;
		 }

		 NSString *str = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
		 NSArray *lines = [str componentsSeparatedByString:@"\r\n"];
         [str release];
         
		 if(lines.count == 0)
		 {
			 LOGLINE(@"Payload body is missing?");
			 // weird...
			 block(nil);
			 return;
		 }
		 
		 if(![[lines objectAtIndex:0] hasPrefix:@"--batchresponse"])
		 {
			 LOGLINE(@"Invalid MIME body");

			 // weird...
			 block(nil);
			 return;
		 }
		 
		 NSString *boundary = [@"--" stringByAppendingString:[[[lines objectAtIndex:1] componentsSeparatedByString:@"="] objectAtIndex:1]];

		 NSMutableDictionary *contentHeaders = nil;
		 NSMutableString *body = nil;
		 BOOL gotHeader = NO;
		 BOOL gotSeparator = NO;
		 BOOL collecting = NO;
		 
		 for(NSString* s in lines)
		 {
			 if([s hasPrefix:boundary])
			 {
				 if(body)
				 {
					 NSData *bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
					 const char *baseURL = NULL;
					 const char *encoding = NULL;
					 xmlDocPtr doc = xmlReadMemory([bodyData bytes], (int)[bodyData length], baseURL, encoding, (XML_PARSE_NOCDATA | XML_PARSE_NOBLANKS)); 
					 
					 error = [WAXMLHelper checkForError:doc];
					 if(error)
					 {
						 xmlFreeDoc(doc);
						 block(error);
						 return;
					 }
					 
					 if(itemHandler)
					 {
						 itemHandler(doc);
					 }
					 
					 xmlFreeDoc(doc);
					 
					 body = nil;
					 gotHeader = NO;
					 gotSeparator = NO;
					 contentHeaders = nil;
				 }
				 else
				 {
					 collecting = YES;
				 }
			 }
			 else if(!collecting)
			 {
				 continue;
			 }
			 else if(gotSeparator && !gotHeader)
			 {
				 if(!s.length)
				 {
					 gotHeader = YES;
				 }
				 else if(!contentHeaders)
				 {
					 contentHeaders = [NSMutableDictionary dictionaryWithCapacity:10]; 
				 }
				 else
				 {
					 NSRange r = [s rangeOfString:@":"];
					 if(r.length > 0)
					 {
						 NSString* key = [[s substringToIndex:r.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
						 NSString* value = [[s substringFromIndex:1 + r.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
						 
						 [contentHeaders setObject:value forKey:key];
					 }
				 }
			 }
			 else if(gotHeader)
			 {
				 if(!body)
				 {
					 body = [NSMutableString stringWithCapacity:2000];
				 }
				 
				 [body appendFormat:@"%@\n", s];
			 }
			 else if(!s.length)
			 {
				 gotSeparator = YES;
			 }
		 }
		 
		 // ok, we're done
		 block(nil);
	 }];
}
														   														   
@end
	
@implementation ServiceRequest

- (id)initServiceRequestWithURL:(NSString *)url httpMethod:(NSString *)httpMethod payload:(NSData*)payload contentType:(NSString *)contentType token:(NSString *)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData *response, NSError *error))block
{
	if((self = [super init]))
	{
		_block = [block copy];
		
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
		
		[request setHTTPMethod:httpMethod];
		[request setHTTPShouldHandleCookies:NO];
		[request setValue:@"Microsoft ADO.NET Data Services" forHTTPHeaderField:@"User-Agent"];
		
		if(payload)
		{
			[request setHTTPBody:payload];
			[request setValue:contentType forHTTPHeaderField:@"Content-Type"];
		}
		
		if(token)
		{
			NSString* wrapper = [NSString stringWithFormat:@"WRAP access_token=\"%@\"", token];
			[request setValue:wrapper forHTTPHeaderField:@"Authorization"];
			
			[request setValue:@"UTF-8" forHTTPHeaderField:@"Accept-Charset"];
			[request setValue:@"application/atom+xml,application/xml" forHTTPHeaderField:@"Accept"];
			[request setValue:@"1.0;NetFx" forHTTPHeaderField:@"DataServiceVersion"];
			[request setValue:@"2.0;NetFx" forHTTPHeaderField:@"MaxDataServiceVersion"];
		}
		

		LOGLINE(@"%@ %@", httpMethod, url);
		LOGLINE(@"Headers: %@", [request allHTTPHeaderFields]);
		
		_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	}
	
	return self;
}

- (void)dealloc
{
	[_connection release];
	[_block release];
	[_data release];
	[super dealloc];
}

+ (void)createServiceRequestWithURL:(NSString *)url httpMethod:(NSString *)httpMethod payload:(NSData *)payload contentType:(NSString *)contentType token:(NSString *)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData *response, NSError *error))block
{
	[[[self alloc] initServiceRequestWithURL:url httpMethod:httpMethod payload:payload contentType:contentType token:token withCompletionHandler:block] autorelease];
}

+ (void)createServiceRequestWithURL:(NSString *)url token:(NSString*)token withCompletionHandler:(void (^)(NSInteger statusCode, NSData *response, NSError *error))block
{
	[[[self alloc] initServiceRequestWithURL:url httpMethod:@"GET" payload:nil contentType:nil token:token withCompletionHandler:block] autorelease];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
	_statusCode = [response statusCode];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if(_data)
	{
		[_data appendData:data];
	}
	else
	{
		_data = [data mutableCopy];
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	_block(_statusCode, nil, error);
	[self release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSError* error = nil;
	
	if(_statusCode >= 300)
	{
		error = [NSError errorWithDomain:@"com.microsoft.WAToolkitConfig" 
									code:_statusCode 
								userInfo:[NSDictionary dictionaryWithObject:@"Invalid HTTP status returned.\nInsure your ACS management key is correct." forKey:NSLocalizedDescriptionKey]];
		_block(_statusCode, nil, error);
		return;
	}

	_block(_statusCode, _data, nil);
}

@end