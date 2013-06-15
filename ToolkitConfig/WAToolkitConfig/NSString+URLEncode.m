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
#import "NSString+URLEncode.h"

// Converts a hex character to its integer value
unichar from_hex(unichar ch) {
	return isdigit(ch) ? ch - '0' : tolower(ch) - 'a' + 10;
}

// Converts an integer value to its hex character
unichar to_hex(unichar code) {
	static unichar hex[] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };
	return hex[code & 15];
}

int wstrlen(unichar *str) {
	int n;
	for(n = 0; *str; n++, str++)
		;
	
	return n;
}

// Returns a url-encoded version of str
// IMPORTANT: be sure to free() the returned string after use
unichar *url_encode(unichar *str) {
	unichar *pstr = str, *buf = malloc(wstrlen(str) * 3 + 1), *pbuf = buf;
	while (*pstr) {
		if (isalnum(*pstr) || *pstr == '-' || *pstr == '_' || *pstr == '.' || *pstr == '~') 
			*pbuf++ = *pstr;
		else if (*pstr == ' ') 
			*pbuf++ = '+';
		else 
			*pbuf++ = '%', *pbuf++ = to_hex(*pstr >> 4), *pbuf++ = to_hex(*pstr & 15);
		pstr++;
	}
	*pbuf = '\0';
	return buf;
}

// Returns a url-decoded version of str
// IMPORTANT: be sure to free() the returned string after use
unichar *url_decode(unichar *str) {
	unichar *pstr = str, *buf = malloc(wstrlen(str) + 1), *pbuf = buf;
	while (*pstr) {
		if (*pstr == '%') {
			if (pstr[1] && pstr[2]) {
				*pbuf++ = from_hex(pstr[1]) << 4 | from_hex(pstr[2]);
				pstr += 2;
			}
		} else if (*pstr == '+') { 
			*pbuf++ = ' ';
		} else {
			*pbuf++ = *pstr;
		}
		pstr++;
	}
	*pbuf = '\0';
	return buf;
}

@implementation NSString (URLEncode)

- (NSString *)URLEncode
{
	unichar* chr = (unichar*)calloc(self.length + 1, sizeof(unichar));
	[self getCharacters:chr];
	
	unichar* result = url_encode(chr);
	NSString* str = [NSString stringWithCharacters:result length:wstrlen(result)];
	
	free(chr);
	free(result);
	
	return str;
}

- (NSString *)URLDecode
{
	NSString *result = (NSString *) CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault, (CFStringRef)self, CFSTR(""), kCFStringEncodingUTF8); 
	return [result autorelease]; 
}

// return a new autoreleased UUID string
+ (NSString *)generateUuidString
{
	// create a new UUID which you own
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	
	// create a new CFStringRef (toll-free bridged to NSString) that you own
	NSString *uuidString = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
	
	// transfer ownership of the string to the autorelease pool
	[uuidString autorelease];
	
	// release the UUID
	CFRelease(uuid);
	
	return uuidString;
}

@end