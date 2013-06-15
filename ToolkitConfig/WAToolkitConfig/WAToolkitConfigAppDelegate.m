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

#import "WAToolkitConfigAppDelegate.h"
#import "AzureURLTransformer.h"

@implementation WAToolkitConfigAppDelegate

@synthesize window;
@synthesize rootController;

- (void)statusChanged:(NSString *)status
{
	NSLog(@"ACS Status: %@", status);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	NSValueTransformer *transformer = [AzureURLTransformer new];
	[NSValueTransformer setValueTransformer:transformer forName:@"AzureURLTransformer"];
	[transformer release];
	
	transformer = [ACSURLTransformer new];
	[NSValueTransformer setValueTransformer:transformer forName:@"ACSURLTransformer"];
	[transformer release];
	
	transformer = [ProxyURLTransformer new];
	[NSValueTransformer setValueTransformer:transformer forName:@"ProxyURLTransformer"];
	[transformer release];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	
	[window setDelegate:self];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[NSApp terminate:self];
}



@end
