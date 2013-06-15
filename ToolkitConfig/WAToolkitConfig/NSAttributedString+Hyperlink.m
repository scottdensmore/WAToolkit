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

#import "NSAttributedString+Hyperlink.h"

@implementation NSAttributedString (Hyperlink)

+ (id)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)aURL
{
	NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString: inString];
	NSRange range = NSMakeRange(0, [attrString length]);
 	
	[attrString beginEditing];
	[attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
 	
	// make the text appear in blue
	[attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];

	// next make the text appear with an underline
	[attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:range];
 	
	[attrString endEditing];
 	
	return [attrString autorelease];
}

+ (NSAttributedString *)attributedStringWithString:(NSString *)string
{
	return [[[NSAttributedString alloc] initWithString:string] autorelease];
}

+ (NSMutableAttributedString *)attributedStringWithValues:(id)value, ...
{
	va_list args;
	
	va_start(args, value);
	
	NSURL* url = nil;
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] init];
	
	if(value)
	{
		do	
		{
			if([value isKindOfClass:[NSURL class]])
			{
				url = value;
			}
			else
			{
				NSString* str = value;
				
				if(url)
				{
					[string appendAttributedString:[self hyperlinkFromString:str withURL:url]];
					url = nil;
				}
				else
				{
					[string appendAttributedString:[self attributedStringWithString:str]];
				}	
			}
		}
		while((value = va_arg(args, id)));
	}
	
	
	va_end(args);
	
	return [string autorelease];
}

@end
