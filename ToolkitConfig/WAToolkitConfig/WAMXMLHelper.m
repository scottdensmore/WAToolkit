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

#import "WAMXMLHelper.h"


@implementation WAMXMLHelper

+ (void)performXPath:(NSString *)xpath onDocument:(xmlDocPtr)doc block:(void (^)(xmlNodePtr node, BOOL *stop))block
{
    [self performXPath:xpath onNode:(xmlNodePtr)doc block:block];
}

+ (void)performXPath:(NSString *)xpath onNode:(xmlNodePtr)node block:(void (^)(xmlNodePtr node, BOOL *stop))block
{
    xmlDocPtr doc;

    if (node->type == XML_DOCUMENT_NODE) {
        doc = (xmlDocPtr)node;
    } else {
        doc = node->doc;
    }

    xmlXPathContextPtr xpathCtx = xmlXPathNewContext(doc);

    if (!xpathCtx) {
        return;
    }

    xmlNodePtr root = xmlDocGetRootElement(doc);
    xpathCtx->node = ((void *)node == (void *)doc) ? root : node;

    // anchor at our current node
    if (root != NULL) {
        for (xmlNsPtr nsPtr = root->nsDef; nsPtr != NULL; nsPtr = nsPtr->next) {
            const xmlChar *prefix = nsPtr->prefix;

            if (prefix != NULL) {
                xmlXPathRegisterNs(xpathCtx, prefix, nsPtr->href);
            } else {
                xmlXPathRegisterNs(xpathCtx, (xmlChar *)"_default", nsPtr->href);
            }
        }
    }

    xmlXPathObjectPtr xpathObj;
    xpathObj = xmlXPathEval((const xmlChar *)[xpath UTF8String], xpathCtx);

    if (xpathObj) {
        xmlNodeSetPtr nodeSet = xpathObj->nodesetval;

        if (nodeSet) {
            for (int index = 0; index < nodeSet->nodeNr; index++) {
                BOOL stop = NO;
                block(nodeSet->nodeTab[index], &stop);

                if (stop) {
                    break;
                }
            }
        }

        xmlXPathFreeObject(xpathObj);
    }

    xmlXPathFreeContext(xpathCtx);
}

+ (NSString *)getElementValue:(xmlNodePtr)parent name:(NSString *)name
{
    xmlChar *nameStr = (xmlChar *)[name UTF8String];

    for (xmlNodePtr child = xmlFirstElementChild(parent); child; child = xmlNextElementSibling(child)) {
        if (xmlStrcmp(child->name, nameStr) == 0) {
            xmlChar *value = xmlNodeGetContent(child);
            NSString *str = @((const char *)value);
            xmlFree(value);
            return str;
        }
    }

    return nil;
}

+ (NSError *)checkForError:(xmlDocPtr)doc
{
    if (!doc) {
        return nil;
    }

    xmlNodePtr root = xmlDocGetRootElement(doc);

    if (xmlStrcmp(root->name, (xmlChar *)"Error") == 0) {
        NSString *code = [self getElementValue:root name:@"Code"];
        NSString *message = [self getElementValue:root name:@"Message"];
        NSString *detail = [self getElementValue:root name:@"AuthenticationErrorDetail"];

        return [NSError errorWithDomain:@"com.microsoft.AzureIOSToolkit"
                                   code:-1
                               userInfo:@{NSLocalizedDescriptionKey: message,
                                          NSLocalizedFailureReasonErrorKey: detail,
                                          @"AzureReasonCode": code}];
    }

    if (xmlStrcmp(root->name, (xmlChar *)"error") == 0) {
        NSString *code = [self getElementValue:root name:@"code"];
        NSString *message = [self getElementValue:root name:@"message"];

        return [NSError errorWithDomain:@"com.microsoft.AzureIOSToolkit"
                                   code:-1
                               userInfo:@{NSLocalizedDescriptionKey: message,
                                          @"AzureReasonCode": code}];
    }

    return nil;
}

+ (void)parseAtomPub:(xmlDocPtr)doc block:(void (^)(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop))block
{
    xmlNodePtr root = xmlDocGetRootElement(doc);

    if (xmlStrcmp(root->name, (xmlChar *)"entry") == 0) {
        BOOL stop = NO;
        WAMAtomPubEntry *entry = [[WAMAtomPubEntry alloc] initWithNode:root];
        block(entry, 0, &stop);
        return;
    }

    __block NSInteger index = 0;

    [WAMXMLHelper performXPath:@"/_default:feed/_default:entry" onDocument:doc block:^(xmlNodePtr node, BOOL *stop)
    {
        WAMAtomPubEntry *entry = [[WAMAtomPubEntry alloc] initWithNode:node];
        block(entry, index++, stop);
    }];
}

@end