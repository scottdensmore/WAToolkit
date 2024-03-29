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
#import <libxml/tree.h>
#import <libxml/xmlstring.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>
#import "WAMAtomPubEntry.h"

@interface WAMXMLHelper : NSObject

+ (void)performXPath:(NSString *)xpath onDocument:(xmlDocPtr)doc block:(void (^)(xmlNodePtr, BOOL *stop))block;
+ (void)performXPath:(NSString *)xpath onNode:(xmlNodePtr)node block:(void (^)(xmlNodePtr node, BOOL *stop))block;
+ (NSString *)getElementValue:(xmlNodePtr)parent name:(NSString *)name;
+ (NSError *)checkForError:(xmlDocPtr)doc;
+ (void)parseAtomPub:(xmlDocPtr)doc block:(void (^)(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop))block;

@end