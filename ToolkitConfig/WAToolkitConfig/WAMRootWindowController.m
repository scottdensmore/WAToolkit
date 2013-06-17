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

#import "WAMRootWindowController.h"
#import "WAMSimpleBase64.h"
#import "WAMConfigureACS.h"
#import "NSAttributedString+Hyperlink.h"
#import <Security/Security.h>
#include <CommonCrypto/CommonDigest.h>

typedef enum {
    WAImportSSL = 0,
    WAImportAPNS = 1
} WAImportCertType;

@interface WAMRootWindowController ()

@property (strong) NSMutableArray *sequence;

- (void)willUpdateState;
- (void)didUpdateState;
- (void)updateState;

- (void)textChanged:(NSNotification *)notification;
- (void)reviewChanged;
- (NSString *)fieldReview;

- (void)pushView:(NSTabViewItem *)view;
- (void)popView;

- (void)showError:(NSError *)error;

- (void)performSSLImportForCertType:(WAImportCertType)importType;
- (BOOL)validateSSLThumbprint:(NSString *)thumbprint;

- (void)acsSetupComplete:(NSString *)configurationFilename;
- (void)commitChanges:(NSString *)configurationFilename;
- (void)performSave:(NSString *)configurationFilename;
- (void)saveConfirmed:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end

@implementation WAMRootWindowController

@synthesize tabView;
@synthesize tabFileSelection;
@synthesize tabServiceSelect;
@synthesize connectionType;
@synthesize accountName;
@synthesize directAccessKey;
@synthesize acsNamespace;
@synthesize acsManagementKey;
// @synthesize proxyService;
@synthesize tabAzureSetup;
// @synthesize tabDirect;
@synthesize tabProxyACS;
@synthesize tabProxyGeneral;
@synthesize tabAPNSImport;
@synthesize tabReview;
@synthesize saveType;
@synthesize acsSpinner;
@synthesize acsSetupPanel;
@synthesize sequence;
@synthesize fieldAccountName;
@synthesize fieldConnectionType;
@synthesize fieldDirectAccessKey;
@synthesize fieldDirectAccessKeyError;
@synthesize fieldACSNamespace;
@synthesize fieldACSManagementKey;
@synthesize fieldACSManagementKeyError;
@synthesize fieldACSRelyingName;
@synthesize fieldACSRealm;
@synthesize fieldACSSigningKey;
@synthesize fieldACSStatus;
@synthesize fieldSSLThumbprint;
@synthesize fieldSSLThumbprintError;
@synthesize fieldAPNSThumbprint;
@synthesize fieldSaveType;
@synthesize fieldIntroHyperlink;
@synthesize fieldDownloadHyperlink;
@synthesize fieldObtainACSKey;

#pragma mark Memory Managment

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];

    if (self) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(textChanged:) name:NSControlTextDidChangeNotification object:nil];

        self.sequence = [[NSMutableArray alloc] initWithCapacity:10];

        NSMutableAttributedString *string;
        string = [NSAttributedString attributedStringWithValues:
                  @"This tool will configure the ",
                  [NSURL URLWithString:@"http://www.windowsazure.com/en-us/solutions/identity/"],
                  @"Access Control Service",
                  @" while also creating the Windows Azure service configuration file for the ",
                  [NSURL URLWithString:@"https://github.com/scottdensmore/WAToolkit"],
                  @"Cloud Ready Packages for Devices",
                  @".", nil];
        [string addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:13.0] range:NSMakeRange(0, [string length])];
        self.fieldIntroHyperlink = string;

        string = [NSAttributedString attributedStringWithValues:
                  @"Haven't yet deployed the Cloud Ready Package? ",
                  [NSURL URLWithString:@"https://github.com/scottdensmore/WAToolkit"],
                  @"Download it now",
                  @".", nil];
        [string addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:NSMakeRange(0, [string length])];
        self.fieldDownloadHyperlink = string;

        string = [NSAttributedString attributedStringWithValues:
                  [NSURL URLWithString:@"http://www.windowsazure.com/en-us/services/data-management/"],
                  @"How to obtain the namespace and management key?", nil];
        [string addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:NSMakeRange(0, [string length])];
        self.fieldObtainACSKey = string;

        self.fieldSaveType = @1;
    }

    return self;
}

- (void)dealloc
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center removeObserver:self];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
    LOGLINE(@"Unknown selector: %@", NSStringFromSelector(aSelector));

    [super doesNotRecognizeSelector:aSelector];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

#pragma mark View Methods

- (NSString *)nextText
{
    NSTabViewItem *current = [tabView selectedTabViewItem];

    return (current == tabReview) ? ([fieldSaveType intValue] == 0 ? @"Copy" : @"Save") : @"Next";
}

- (void)didChangeValueForKey:(NSString *)key
{
    [super didChangeValueForKey:key];

    if ([key isEqualToString:@"fieldDirectAccessKey"]) {
        NSData *data = [fieldDirectAccessKey dataWithBase64DecodedString];

        if (fieldDirectAccessKey.length > 0 && data.length != 64) {
            self.fieldDirectAccessKeyError = @"Please provide a 512-bit base-64 encoded key";
        } else {
            self.fieldDirectAccessKeyError = @"";
        }

        [self updateState];
    } else if ([key isEqualToString:@"fieldACSManagementKey"]) {
        NSData *data = [fieldACSManagementKey dataWithBase64DecodedString];

        if (fieldACSManagementKey.length > 0 && data.length != 32) {
            self.fieldACSManagementKeyError = @"Please provide a 256-bit base-64 encoded key";
        } else {
            self.fieldACSManagementKeyError = @"";
        }

        [self updateState];
    } else if ([key isEqualToString:@"fieldSSLThumbprint"]) {
        if (fieldSSLThumbprint.length > 0 && ![self validateSSLThumbprint:fieldSSLThumbprint]) {
            self.fieldSSLThumbprintError = @"SSL thumbprint should be 40 characters";
        } else {
            self.fieldSSLThumbprintError = @"";
        }

        [self updateState];
    } else if ([key isEqualToString:@"fieldAPNSThumbprint"]) {
        if (fieldAPNSThumbprint.length > 0 && ![self validateSSLThumbprint:fieldAPNSThumbprint]) {
            self.fieldSSLThumbprintError = @"SSL thumbprint should be 40 characters";
        } else {
            self.fieldSSLThumbprintError = @"";
        }

        [self updateState];
    } else if ([key isEqualToString:@"fieldConnectionType"]) {
        [self updateState];
    } else if ([key isEqualToString:@"fieldSaveType"]) {
        [self updateState];
        [self reviewChanged];
    } else if ([key isEqualToString:@"fieldACSStatus"]) {
        [self updateState];
    }
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [self willUpdateState];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [self didUpdateState];
}

#pragma mark Action Methods

- (IBAction)nextClicked:(id)sender
{
    id current = [tabView selectedTabViewItem];

    if (current == tabFileSelection) {
        [self pushView:tabAzureSetup];
        [accountName becomeFirstResponder];
        return;
    } else if (current == tabServiceSelect) {
        switch ([connectionType selectedRow]) {
            case 0: {
                [self pushView:tabReview];
                return;
            }

            case 1: {
                [self pushView:tabProxyACS];
                [acsNamespace becomeFirstResponder];
                return;
            }
        }
        return;
    } else if (current == tabAzureSetup) {
        [self pushView:tabProxyGeneral];
        return;
    } else if (current == tabProxyGeneral) {
        [self pushView:tabAPNSImport];
        return;
    } else if (current == tabAPNSImport) {
        [self pushView:tabServiceSelect];
        return;
    } else if (current == tabReview) {
        self.fieldACSRelyingName = @"WazMobileToolkit";
        self.fieldACSRealm = @"uri:wazmobiletoolkit";

        self.fieldACSStatus = @" ";

        if ([fieldSaveType intValue] == 1) {
            NSSavePanel *panel = [NSSavePanel savePanel];
            NSURL *home = [NSURL fileURLWithPath:@"~/"];
            [panel setDirectoryURL:home];
            [panel setAllowedFileTypes:@[@"cscfg"]];
            [panel setAllowsOtherFileTypes:NO];
            [panel setNameFieldStringValue:@"ServiceConfiguration.cscfg"];
            [panel setExtensionHidden:NO];

            [panel beginSheetModalForWindow:[tabView window]
                          completionHandler:^(NSInteger result)
            {
                if (result != NSFileHandlingPanelOKButton) {
                    return;
                }

                NSString *filename = [[[panel URL] filePathURL] path];
                [self performSelector:@selector(commitChanges:) withObject:filename afterDelay:0.2];
            }];
        } else {
            [self commitChanges:nil];
        }
    } else if (current == tabProxyACS) {
        [self pushView:tabReview];
        [self reviewChanged];
    }
}

- (IBAction)previousClicked:(id)sender
{
    [self popView];
}

- (IBAction)sslImportClicked:(id)sender
{
    [self performSSLImportForCertType:WAImportSSL];
}

- (IBAction)apnsImputClicked:(id)sender
{
    [self performSSLImportForCertType:WAImportAPNS];
}

#pragma mark Public Methods

- (BOOL)canGoPrevious
{
    return !!sequence.count;
}

- (BOOL)canGoNext
{
    id current = [tabView selectedTabViewItem];

    if (current == tabAzureSetup) {
        return !!fieldAccountName.length && !!fieldDirectAccessKey.length && !!fieldDirectAccessKeyError.length;
    } else if (current == tabProxyACS) {
        return !fieldACSStatus.length && fieldACSNamespace.length && fieldACSManagementKey.length && !fieldACSManagementKeyError.length;
    } else if (current == tabProxyGeneral) {
        return fieldSSLThumbprint.length && !fieldSSLThumbprintError.length;
    }

    return YES;
}

#pragma mark Private Methods

- (void)willUpdateState
{
    [self willChangeValueForKey:@"canGoPrevious"];
    [self willChangeValueForKey:@"canGoNext"];
    [self willChangeValueForKey:@"nextText"];
}

- (void)didUpdateState
{
    [self didChangeValueForKey:@"canGoPrevious"];
    [self didChangeValueForKey:@"canGoNext"];
    [self didChangeValueForKey:@"nextText"];
}

- (void)updateState
{
    [self willUpdateState];
    [self didUpdateState];
}

- (void)textChanged:(NSNotification *)notification
{
    // cause the Next button to be re-evaluated
    [self willChangeValueForKey:@"canGoNext"];
    [self didChangeValueForKey:@"canGoNext"];
}

- (void)reviewChanged
{
    [self willChangeValueForKey:@"fieldReview"];
    [self didChangeValueForKey:@"fieldReview"];
}

- (NSString *)fieldReview
{
    if ([connectionType selectedRow] == 1) {
        return [NSString stringWithFormat:@"Once you click %@ we will configure the Access Control Service namespace your provided.",
                self.nextText];
    }

    return @"";
}

- (void)pushView:(NSTabViewItem *)view
{
    NSTabViewItem *current = [tabView selectedTabViewItem];

    [self.sequence addObject:current];

    [tabView selectTabViewItem:view];
}

- (void)popView
{
    NSTabViewItem *previous = [self.sequence lastObject];

    [tabView selectTabViewItem:previous];
    [sequence removeLastObject];
}

- (void)showError:(NSError *)error
{
    NSAlert *alert = [NSAlert alertWithError:error];

    [alert beginSheetModalForWindow:[tabView window]
                      modalDelegate:nil
                     didEndSelector:nil
                        contextInfo:nil];
}

- (void)performSSLImportForCertType:(WAImportCertType)importType
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setCanChooseFiles:YES];
    NSURL *home = [NSURL fileURLWithPath:@"~/"];
    [panel setDirectoryURL:home];
    [panel setAllowsMultipleSelection:NO];
    // [panel setAllowedFileTypes:[NSArray arrayWithObject:@"cer"]];
    [panel setAllowedFileTypes:@[@"cer", @"pfx", @"pem"]];
    [panel setAllowsOtherFileTypes:NO];


    __weak WAMRootWindowController *weakSelf = self;
    [panel beginSheetModalForWindow:[tabView window]
                  completionHandler:^(NSInteger result)
    {
        if (result != NSFileHandlingPanelOKButton) {
            return;
        }

        NSData *certData;
        uint8_t *certBytes;

        NSString *filename = [[[panel URL] filePathURL] path];
        certData = [NSData dataWithContentsOfFile:filename];
        certBytes = malloc(certData.length);

        [certData getBytes:certBytes length:certData.length];

        uint8_t sha[CC_SHA1_DIGEST_LENGTH];
        memset(sha, 0, sizeof(sha));
        CC_SHA1(certBytes, (CC_LONG)certData.length, sha);

        free(certBytes);

        NSMutableString *tp = [NSMutableString stringWithCapacity:sizeof(sha) * 2];

        for (uint8_t * p = sha; p < ((uint8_t *)sha + sizeof(sha)); p++) {
            int n = *p;
            [tp appendFormat:@"%02X", n];
        }

        if (importType == WAImportSSL) {
            weakSelf.fieldSSLThumbprint = tp;
        } else {
            weakSelf.fieldAPNSThumbprint = tp;
        }
    }];
}

- (BOOL)validateSSLThumbprint:(NSString *)thumbprint
{
    if (thumbprint.length != 40) {
        return NO;
    }

    NSCharacterSet *hexChars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
    NSRange r = [fieldSSLThumbprint rangeOfCharacterFromSet:hexChars];

    return r.length == 0;
}

- (void)acsSetupComplete:(NSString *)configurationFilename
{
    [NSApp endSheet:acsSetupPanel];
    [acsSetupPanel orderOut:nil];

    [acsSpinner stopAnimation:self];
    self.fieldACSStatus = @"";

    [self performSelector:@selector(performSave:) withObject:configurationFilename afterDelay:0.2];
}

- (void)commitChanges:(NSString *)configurationFilename
{
    if ([self.fieldConnectionType intValue] == 0) {
        [self performSave:configurationFilename];
        return;
    }

    [NSApp beginSheet:acsSetupPanel modalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];

    NSString *groupName = @"Default Rule Group for WazMobileToolkit";

    __block int progress = 0;

    [WAMConfigureACS configureACSWithServiceNamespace:fieldACSNamespace
                                        managementKey:fieldACSManagementKey
                                                realm:self.fieldACSRealm
                                     relyingPartyName:self.fieldACSRelyingName
                                            groupName:groupName
                                           signingKey:nil
                                       statusCallback:^(NSString *status)
    {
        self.fieldACSStatus = [NSString stringWithFormat:@"%@...", status];
        [acsSpinner setDoubleValue:++progress];
    }

                                withCompletionHandler:^(NSDictionary *values, NSError *error)
    {
        if (error) {
            self.fieldACSStatus = @"";
            // Dismiss the acsSetupPanel sheet
            [NSApp endSheet:acsSetupPanel];
            [acsSetupPanel orderOut:nil];

            [self showError:error];

            return;
        } else {
            self.fieldACSSigningKey = values[@"TokenSigningKey"];
            self.fieldACSStatus = @"Finishing...";

            [acsSpinner setDoubleValue:++progress];

            [self performSelector:@selector(acsSetupComplete:) withObject:configurationFilename afterDelay:2.0];
        }
    }];
}

- (void)performSave:(NSString *)configurationFilename
{
    NSError *error = nil;
    int connType = [fieldConnectionType intValue];
    NSString *f = [[NSBundle mainBundle] pathForResource:connType == 0 ? @"ServiceConfiguration-Mem":@"ServiceConfiguration-ACS" ofType:@"cscfg"];
    NSMutableString *contents = [NSMutableString stringWithContentsOfFile:f encoding:NSUTF8StringEncoding error:nil];

    [contents replaceOccurrencesOfString:@"{youraccountname}" withString:fieldAccountName options:NSCaseInsensitiveSearch range:NSMakeRange(0, contents.length)];
    [contents replaceOccurrencesOfString:@"{youraccountkey}" withString:fieldDirectAccessKey options:NSCaseInsensitiveSearch range:NSMakeRange(0, contents.length)];
    [contents replaceOccurrencesOfString:@"{yoursslcertificatethumbprint}" withString:fieldSSLThumbprint options:NSCaseInsensitiveSearch range:NSMakeRange(0, contents.length)];

    NSString *thumbprint;
    NSString *useAPNS;

    if (fieldAPNSThumbprint.length > 0) {
        thumbprint = [fieldAPNSThumbprint copy];
        useAPNS = @"true";
    } else {
        thumbprint = [fieldSSLThumbprint copy];
        useAPNS = @"false";
    }

    [contents replaceOccurrencesOfString:@"{useapns}" withString:useAPNS options:NSCaseInsensitiveSearch range:NSMakeRange(0, contents.length)];
    [contents replaceOccurrencesOfString:@"{yourapplethumbprint}" withString:thumbprint options:NSCaseInsensitiveSearch range:NSMakeRange(0, contents.length)];

    if (connType == 1) {
        [contents replaceOccurrencesOfString:@"{yourrealm}" withString:fieldACSRealm options:NSCaseInsensitiveSearch range:NSMakeRange(0, contents.length)];
        [contents replaceOccurrencesOfString:@"{yourservicekey}" withString:fieldACSSigningKey options:NSCaseInsensitiveSearch range:NSMakeRange(0, contents.length)];
        [contents replaceOccurrencesOfString:@"{yourissuersidentifier}" withString:[NSString stringWithFormat:@"https://%@.accesscontrol.windows.net/", fieldACSNamespace] options:NSCaseInsensitiveSearch range:NSMakeRange(0, contents.length)];
        [contents replaceOccurrencesOfString:@"{yourissuername}" withString:fieldACSRelyingName options:NSCaseInsensitiveSearch range:NSMakeRange(0, contents.length)];
    }

    if (configurationFilename) {
        [contents writeToFile:configurationFilename atomically:YES encoding:NSUTF8StringEncoding error:&error];
    } else {
        NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];

        [pasteBoard declareTypes:@[NSStringPboardType] owner:nil];
        [pasteBoard setString:contents forType:NSStringPboardType];
    }

    if (error) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Error"
                                         defaultButton:@"OK"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"%@", [error localizedDescription]];
        [alert beginSheetModalForWindow:[tabView window]
                          modalDelegate:nil
                         didEndSelector:nil
                            contextInfo:nil];
        return;
    }

    NSString *text;

    if (!configurationFilename) {
        text = @"The service configuration has been copied to the Clipboard.";
    } else {
        text = @"The service configuration has been been saved.";
    }

    NSAlert *alert = [NSAlert alertWithMessageText:@"Save Complete"
                                     defaultButton:@"Quit"
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", text];
    [alert beginSheetModalForWindow:[tabView window]
                      modalDelegate:self
                     didEndSelector:@selector(saveConfirmed:returnCode:contextInfo:)
                        contextInfo:nil];
}

- (void)saveConfirmed:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    exit(0);
}

@end