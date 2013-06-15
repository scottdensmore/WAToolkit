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

#import "WAMultipartMime.h"
#import "NSString+URLEncode.h"
#import "WASimpleBase64.h"
#include <libxml/xmlwriter.h>
#include <stdlib.h>

@interface WAMultipartMime (Extended)

- (void)appendLine:(NSString *)line;
- (void)appendLineWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

@end

@implementation WAMultipartMime

@synthesize batchIdentity = _batch;

- (id)initWithServiceClient:(ServiceCall *)client
{
	if((self = [super init]))
	{
		_client = [client retain];
		_contentID = 1;
		_batch = [[NSString generateUuidString] retain];
		_changeSet = [[NSString generateUuidString] retain];
		_data = [[NSMutableData alloc] initWithCapacity:10000];

		[self appendLineWithFormat:@"--batch_%@", _batch];
		[self appendLineWithFormat:@"Content-Type: multipart/mixed; boundary=changeset_%@", _changeSet];
		[self appendLine:@""];
	}
	
	return self;
}

- (void)dealloc
{
	[_client release];
	[_batch release];
	[_changeSet release];
	[_data release];
	
	[super dealloc];
}

- (void)appendLine:(NSString *)line
{
	line = [line stringByAppendingString:@"\r\n"];
	[_data appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)appendLineWithFormat:(NSString*)format, ...
{
	va_list args;
	
	va_start(args, format);
	
	NSString* line = [[NSString alloc] initWithFormat:format arguments:args];
	
	va_end(args);
	
	[self appendLine:line];
	[line release];
}

- (NSData*)appendDataWithAtomPubEntity:(NSString *)entity term:(NSString *)term args:(va_list)args
{
	xmlTextWriterPtr writer;
	xmlBufferPtr buf;
	
	buf = xmlBufferCreate();
    if (buf == NULL) 
	{
        NSLog(@"Error creating the xml buffer");
        return nil;
    }
		
	writer = xmlNewTextWriterMemory(buf, 0);
	if (buf == NULL) 
	{
		xmlBufferFree(buf);
		
        NSLog(@"Error creating the xml writer");
        return nil;
    }
	
	xmlTextWriterSetIndent(writer, 2);
	
	xmlTextWriterStartDocument(writer, "1.0", "utf-8", "yes");
	
	xmlTextWriterStartElementNS(writer, BAD_CAST nil, BAD_CAST "entry", BAD_CAST "http://www.w3.org/2005/Atom");
	xmlTextWriterWriteAttribute(writer, BAD_CAST "xmlns:d", BAD_CAST "http://schemas.microsoft.com/ado/2007/08/dataservices");
	xmlTextWriterWriteAttribute(writer, BAD_CAST "xmlns:m", BAD_CAST "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata");

	xmlTextWriterStartElement(writer, BAD_CAST "category");
	xmlTextWriterWriteAttribute(writer, BAD_CAST "scheme", BAD_CAST "http://schemas.microsoft.com/ado/2007/08/dataservices/scheme");
	term = [NSString stringWithFormat:@"Microsoft.Cloud.AccessControl.Management.%@", term];
	xmlTextWriterWriteAttribute(writer, BAD_CAST "term", BAD_CAST [term UTF8String]);
	xmlTextWriterEndElement(writer); // </category>

	xmlTextWriterStartElement(writer, BAD_CAST "title");
	xmlTextWriterEndElement(writer); // </title>
	
	xmlTextWriterStartElement(writer, BAD_CAST "author");
	xmlTextWriterStartElement(writer, BAD_CAST "name");
	xmlTextWriterEndElement(writer); // </name>
	xmlTextWriterEndElement(writer); // </author>
	
	xmlTextWriterStartElement(writer, BAD_CAST "updated");
	
	xmlTextWriterWriteString(writer, BAD_CAST [[ServiceCall iso8601StringFromDate:[NSDate date]] UTF8String]);
	xmlTextWriterEndElement(writer); // </updated>
	
	xmlTextWriterStartElement(writer, BAD_CAST "id");
	xmlTextWriterEndElement(writer); // </id>
	
	xmlTextWriterStartElement(writer, BAD_CAST "content");
	xmlTextWriterWriteAttribute(writer, BAD_CAST "type", BAD_CAST "application/xml");
	
	xmlTextWriterStartElement(writer, BAD_CAST "m:properties");
	
	NSString* name;
	while((name = va_arg(args, NSString*)))
	{
		NSString *tag = [NSString stringWithFormat:@"d:%@", name];
		xmlTextWriterStartElement(writer, BAD_CAST [tag UTF8String]);

		EdmDataType type = va_arg(args, EdmDataType);
		switch(type)
		{
			case EdmInt32:
			{
				int value = va_arg(args, int);
				char buffer[20];
				sprintf(buffer, "%d", value);
				xmlTextWriterWriteAttribute(writer, BAD_CAST "m:type", BAD_CAST "Edm.Int32");
				xmlTextWriterWriteString(writer, BAD_CAST buffer);
				break;
			}
				
			case EdmInt64:
			{
				long long value = va_arg(args, long long);
				char buffer[20];
				sprintf(buffer, "%qd", value);
				xmlTextWriterWriteAttribute(writer, BAD_CAST "m:type", BAD_CAST "Edm.Int64");
				xmlTextWriterWriteString(writer, BAD_CAST buffer);
				break;
			}
				
			case EdmBoolean:
			{
				BOOL value = va_arg(args, int);
				xmlTextWriterWriteAttribute(writer, BAD_CAST "m:type", BAD_CAST "Edm.Boolean");
				xmlTextWriterWriteString(writer, BAD_CAST (value ? "true" : "false"));
				break;
			}
				
			case EdmBinary:
			{
				NSData *value = va_arg(args, NSData*);
				
				xmlTextWriterWriteAttribute(writer, BAD_CAST "m:type", BAD_CAST "Edm.Binary");
				if([value isKindOfClass:[NSNull class]])
				{
					xmlTextWriterWriteAttribute(writer, BAD_CAST "m:null", BAD_CAST "true");
				}
				else
				{
					NSString *b64;
					if([value isKindOfClass:[NSString class]])
					{
						b64 = (NSString*)value;
					}
					else
					{
						b64 = [value stringWithBase64EncodedData];
					}

					xmlTextWriterWriteString(writer, BAD_CAST [b64 UTF8String]);
				}
				break;
			}
				
			case EdmDateTime:
			{
				NSDate *value = va_arg(args, NSDate*);
				xmlTextWriterWriteAttribute(writer, BAD_CAST "m:type", BAD_CAST "Edm.DateTime");
				if([value isKindOfClass:[NSNull class]])
				{
					xmlTextWriterWriteAttribute(writer, BAD_CAST "m:null", BAD_CAST "true");
				}
				else
				{
					NSString *str = [ServiceCall iso8601StringFromDate:value];
					xmlTextWriterWriteString(writer, BAD_CAST [str UTF8String]);
				}
				break;
			}
				
			case EdmString:
			{
				NSString *value = va_arg(args, NSString*);
				if([value isKindOfClass:[NSNull class]])
				{
					xmlTextWriterWriteAttribute(writer, BAD_CAST "m:null", BAD_CAST "true");
				}
				else
				{
					xmlTextWriterWriteString(writer, BAD_CAST [value UTF8String]);
				}
				break;
			}
		}

		xmlTextWriterEndElement(writer); 
	}
	
	xmlTextWriterEndElement(writer); // </m:properties>
	
	xmlTextWriterEndElement(writer); // </content>
	
	xmlTextWriterEndElement(writer); // </entry>
	
	xmlTextWriterEndDocument(writer);

	NSString *str = @((const char*)buf->content);

	xmlFreeTextWriter(writer);
	xmlBufferFree(buf);
	
	str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@"\r\n"];

	return [str dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)appendDataWithAtomPubEntity:(NSString*)entity term:(NSString*)term, ...
{
	if(_closed)
	{
		LOGLINE(@"appendDataWithAtomPubEntity:term: called on closed body");
		return;
	}

	[self appendLineWithFormat:@"--changeset_%@", _changeSet];
	[self appendLine:@"Content-Type: application/http"];
	[self appendLine:@"Content-Transfer-Encoding: binary"];
	[self appendLine:@""];
	[self appendLineWithFormat:@"POST %@ HTTP/1.1", [_client URLforEntity:entity]];
	[self appendLineWithFormat:@"Content-ID: %ld", _contentID++];
	[self appendLine:@"Content-Type: application/atom+xml;type=entry"];
	
	va_list args;
	va_start(args, term);
	NSData *payload = [self appendDataWithAtomPubEntity:entity term:term args:args];
	va_end(args);
	
	[self appendLineWithFormat:@"Content-Length: %ld", payload.length];
	[self appendLine:@""];
	
	[_data appendData:payload];
}

- (NSData *)data
{
	if(!_closed)
	{
		[self appendLineWithFormat:@"--changeset_%@--", _changeSet];
		[self appendLineWithFormat:@"--batch_%@--", _batch];
		_closed = YES;
	}
	
	return _data;
}


@end
