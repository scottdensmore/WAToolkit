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

#import <Foundation/Foundation.h>
#import "WAMXMLHelper.h"
#import "WAMAtomPubEntry.h"

@class WAMMultipartMime;

@interface WAMServiceCall : NSObject

+ (void)obtainTokenFromNamespace:(NSString *)serviceNamespace
                   managementKey:(NSString *)key
           withCompletionHandler:(void (^)(NSInteger statusCode, NSError *error, WAMServiceCall *client))block;

- (NSString *)URLforEntity:(NSString *)entity;

- (void)getFromEntity:(NSString *)entity withCompletionHandler:(void (^)(NSData *data, NSError *error))block;
- (void)getFromEntity:(NSString *)entity withXmlCompletionHandler:(void (^)(xmlDocPtr doc, NSError *error))block;
- (void)getFromEntity:(NSString *)entity atomEntryHandler:(void (^)(WAMAtomPubEntry *entry, BOOL *stop))itemHandler withCompletionHandler:(void (^)(NSError *error))block;

- (void)deleteFromEntity:(NSString *)entity withCompletionHandler:(void (^)(NSError *error))block;

- (WAMMultipartMime *)createMimeBody;
- (void)sendBatch:(WAMMultipartMime *)mimeBody mimeEntryHandler:(void (^)(xmlDocPtr doc))itemHandler withCompletionHandler:(void (^)(NSError *error))block;

+ (NSString *)iso8601StringFromDate:(NSDate *)date;

@end