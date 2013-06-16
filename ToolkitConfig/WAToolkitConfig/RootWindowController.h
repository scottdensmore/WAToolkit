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

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface RootWindowController : NSWindowController <NSTabViewDelegate, NSTextFieldDelegate> {
}

@property (weak) IBOutlet NSTabView *tabView;
@property (weak) IBOutlet NSTabViewItem *tabFileSelection;
@property (weak) IBOutlet NSTabViewItem *tabAzureSetup;
@property (weak) IBOutlet NSTabViewItem *tabServiceSelect;
// @property (weak) IBOutlet NSTabViewItem *tabDirect;
@property (weak) IBOutlet NSTabViewItem *tabProxyACS;
@property (weak) IBOutlet NSTabViewItem *tabProxyGeneral;
@property (weak) IBOutlet NSTabViewItem *tabAPNSImport;
@property (weak) IBOutlet NSTabViewItem *tabReview;
@property (weak) IBOutlet NSMatrix *connectionType;
@property (weak) IBOutlet NSTextField *accountName;
@property (weak) IBOutlet NSTextField *directAccessKey;
@property (weak) IBOutlet NSTextField *acsNamespace;
@property (weak) IBOutlet NSTextField *acsManagementKey;
// @property (weak) IBOutlet NSTextField *proxyService;
@property (weak) IBOutlet NSMatrix *saveType;
@property (weak) IBOutlet NSProgressIndicator *acsSpinner;
@property (weak) IBOutlet NSPanel *acsSetupPanel;

@property (readonly) BOOL canGoPrevious;
@property (readonly) BOOL canGoNext;


@property (weak, readonly) NSString *nextText;
@property (copy) NSString *fieldAccountName;
@property (strong) NSNumber *fieldConnectionType;
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
@property (weak, readonly) NSString *fieldReview;
@property (strong) NSNumber *fieldSaveType;
@property (strong) NSAttributedString *fieldIntroHyperlink;
@property (strong) NSAttributedString *fieldDownloadHyperlink;
@property (strong) NSAttributedString *fieldObtainACSKey;

- (IBAction)previousClicked:(id)sender;
- (IBAction)nextClicked:(id)sender;
- (IBAction)sslImportClicked:(id)sender;
- (IBAction)apnsImputClicked:(id)sender;

@end