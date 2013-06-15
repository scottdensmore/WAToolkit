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

#import <Foundation/Foundation.h>
#import "ServiceCall.h"

typedef enum
{
	EdmInt32,
	EdmInt64,
	EdmBoolean,
	EdmBinary,
	EdmDateTime,
	EdmString
} EdmDataType;

@interface WAMultipartMime : NSObject {
@private
	ServiceCall *_client;
	NSString *_batch;
	NSString *_changeSet;
    NSMutableData *_data;
	NSInteger _contentID;
	BOOL _closed;
}

- (id)initWithServiceClient:(ServiceCall *)client;

- (void)appendDataWithAtomPubEntity:(NSString*)entity term:(NSString*)term, ... NS_REQUIRES_NIL_TERMINATION;

- (NSData *)data;

@property (readonly) NSString *batchIdentity;

@end
