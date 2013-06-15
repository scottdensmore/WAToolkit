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

@class WorkerQueue;
@class ServiceCall;
typedef void (^WorkerQueueBlock)(WorkerQueue *queue);

@interface WorkerQueue : NSObject {
@private
	NSMutableArray *_workers;
    NSMutableDictionary *_values;
	NSError *_error;
	WorkerQueueBlock _completionHandler;
	BOOL _complete;
	ServiceCall *_client;
	void(^_statusCallback)(NSString *);
}

- (void)processLast;

- (id)objectForKey:(id)aKey;
- (void)setObject:(id)value forKey:(id)aKey;

- (void)setCompletionHandler:(WorkerQueueBlock)block;
- (void)setStatusTarget:(void(^)(NSString *))statusCallback;

@property (retain) NSError *error;
@property (retain) ServiceCall *client;

@property (assign) NSString *status;
@property (readonly) NSDictionary *values;

@end

