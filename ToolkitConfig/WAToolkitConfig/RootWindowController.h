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

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface RootWindowController : NSWindowController <NSTabViewDelegate, NSTextFieldDelegate> {
@private    
	NSProgressIndicator *acsSpinner;
	NSPanel *acsSetupPanel;
	
    NSTabView *tabView;
	NSTabViewItem *tabFileSelection;
	NSTabViewItem *tabAzureSetup;
	NSTabViewItem *tabServiceSelect;
	NSTabViewItem *tabDirect;
	NSTabViewItem *tabProxyACS;
	NSTabViewItem *tabProxyGeneral;
    NSTabViewItem *tabAPNSImport;
	NSTabViewItem *tabReview;
	NSMatrix *connectionType;
	NSTextField *accountName;
	NSTextField *directAccessKey;
	NSTextField *acsNamespace;
	NSTextField *acsManagementKey;
	NSTextField *proxyService;
	NSMatrix *saveType;
	
    NSMutableArray *sequence;
    
	NSString *fieldAccountName;
	NSNumber *fieldConnectionType;
	NSString *fieldDirectAccessKey;
	NSString *fieldDirectAccessKeyError;
	NSString *fieldACSNamespace;
	NSString *fieldACSManagementKey;
	NSString *fieldACSManagementKeyError;
	NSString *fieldACSRelyingName;
	NSString *fieldACSRealm;
	NSString *fieldACSSigningKey;
	NSString *fieldACSStatus;
	NSString *fieldSSLThumbprint;
	NSString *fieldSSLThumbprintError;
    NSString *fieldAPNSThumbprint;
	NSString *fieldReview;
	NSNumber *fieldSaveType;
	NSAttributedString *fieldIntroHyperlink;
	NSAttributedString *fieldDownloadHyperlink;
	NSAttributedString *fieldObtainACSKey;
}

@property (assign) IBOutlet NSTabView *tabView;
@property (assign) IBOutlet NSTabViewItem *tabFileSelection;
@property (assign) IBOutlet NSTabViewItem *tabAzureSetup;
@property (assign) IBOutlet NSTabViewItem *tabServiceSelect;
@property (assign) IBOutlet NSTabViewItem *tabDirect;
@property (assign) IBOutlet NSTabViewItem *tabProxyACS;
@property (assign) IBOutlet NSTabViewItem *tabProxyGeneral;
@property (assign) IBOutlet NSTabViewItem *tabAPNSImport;
@property (assign) IBOutlet NSTabViewItem *tabReview;
@property (assign) IBOutlet NSMatrix *connectionType;
@property (assign) IBOutlet NSTextField *accountName;
@property (assign) IBOutlet NSTextField *directAccessKey;
@property (assign) IBOutlet NSTextField *acsNamespace;
@property (assign) IBOutlet NSTextField *acsManagementKey;
@property (assign) IBOutlet NSTextField *proxyService;
@property (assign) IBOutlet NSMatrix *saveType;
@property (assign) IBOutlet NSProgressIndicator *acsSpinner;
@property (assign) IBOutlet NSPanel *acsSetupPanel;

@property (readonly) BOOL canGoPrevious;
@property (readonly) BOOL canGoNext;

@property (readonly) NSString* nextText;
@property (copy) NSString *fieldAccountName;
@property (retain) NSNumber *fieldConnectionType;
@property (copy) NSString *fieldDirectAccessKey;
@property (copy) NSString *fieldDirectAccessKeyError;
@property (copy) NSString *fieldACSNamespace;
@property (copy) NSString *fieldACSManagementKey;
@property (copy) NSString *fieldACSManagementKeyError;
@property (copy) NSString *fieldACSRelyingName;
@property (copy) NSString *fieldACSRealm;
@property (copy) NSString *fieldACSSigningKey;
@property (copy) NSString *fieldACSStatus;
@property (copy) NSString *fieldSSLThumbprint;
@property (copy) NSString *fieldSSLThumbprintError;
@property (copy) NSString *fieldAPNSThumbprint;
@property (readonly) NSString* fieldReview;
@property (retain) NSNumber* fieldSaveType;
@property (retain) NSAttributedString* fieldIntroHyperlink;
@property (retain) NSAttributedString* fieldDownloadHyperlink;
@property (retain) NSAttributedString* fieldObtainACSKey;

- (IBAction)previousClicked:(id)sender;
- (IBAction)nextClicked:(id)sender;
- (IBAction)sslImportClicked:(id)sender;
- (IBAction)apnsImputClicked:(id)sender;

@end
