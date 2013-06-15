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

#import "AzureURLTransformer.h"

@implementation AzureURLTransformer

+ (Class)transformedValueClass 
{ 
	return [NSAttributedString class]; 
}

+ (BOOL)allowsReverseTransformation 
{ 
	return NO; 
}

+ (NSString *)format
{
	return @"http://%1$@.*.core.windows.net/";
}

- (id)transformedValue:(id)item 
{
	NSMutableAttributedString* attr;
	NSString* format = [[self class] format];
	
	if(!item || ![item length])
	{
		item = @"{\\i name }";

		format = [NSString stringWithFormat:@"{\\rtf1\\ansi %@ }", format];
		
		NSString* str = [NSString stringWithFormat:format, item];
		NSData* data = [str dataUsingEncoding:NSUTF8StringEncoding];
		
		attr = [[NSMutableAttributedString alloc] initWithString:@"" attributes:[NSDictionary dictionary]];
		
		[attr readFromData:data options:[NSDictionary dictionary] documentAttributes:nil];
	}
	else
	{
		NSString* str = [NSString stringWithFormat:format, item];
		attr = [[NSMutableAttributedString alloc] initWithString:str attributes:[NSDictionary dictionary]];
	}
	
	return [attr autorelease];
}

@end

@implementation ACSURLTransformer

+ (NSString *)format
{
	return @"http://%1$@.accesscontrol.windows.net/";
}

@end

@implementation ProxyURLTransformer

+ (NSString *)format
{
	return @"https://%1$@.cloudapp.net/";
}

@end
