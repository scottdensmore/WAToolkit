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

#import "WorkerQueue.h"
#import "ServiceCall.h"

@implementation WorkerQueue

@synthesize client = _client;
@synthesize values = _values;

- (id)init
{
	if((self = [super init]))
	{
		_workers = [[NSMutableArray alloc] initWithCapacity:20];
		_values = [[NSMutableDictionary alloc] initWithCapacity:10];
	}
	
	return self;
}


- (void)processLast
{
	if(!_complete && _completionHandler)
	{
		_completionHandler(self);
		_complete = YES;
	}
}

- (id)objectForKey:(id)aKey
{
	return _values[aKey];
}

- (void)setObject:(id)value forKey:(id)aKey
{
	_values[aKey] = value;
}

- (void)setCompletionHandler:(WorkerQueueBlock)block
{
	_completionHandler = [block copy];
}

- (NSError *)error
{
	return _error;
}

- (void)setError:(NSError *)error
{
	_error = error;
	
	if(_error)
	{
		[self performSelector:@selector(processNext) withObject:nil afterDelay:0.0];
	}
}

- (void)setStatusTarget:(void(^)(NSString *))statusCallback
{
	_statusCallback = [statusCallback copy];
}

- (NSString*)status
{
	return nil;
}

- (void)setStatusInternal:(NSString *)status
{
	_statusCallback(status);
}

- (void)setStatus:(NSString *)status
{
	if(_statusCallback)
	{
		[self performSelectorOnMainThread:@selector(setStatusInternal:) withObject:status waitUntilDone:YES];
	}
}

@end
