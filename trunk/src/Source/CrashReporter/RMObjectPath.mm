//***************************************************************************

// Copyright (C) 2007 Realmac Software Pty Ltd
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject
// to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
// ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//***************************************************************************

#import "RMObjectPath.h"

#include <utility>

//***************************************************************************

@implementation NSArray (ObjectPathSupport)

static NSCharacterSet* DotCharacterSet()
{
	static NSCharacterSet* dotCharacterSet = nil;
	
	if(dotCharacterSet == nil) dotCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"."] retain];
	
	return dotCharacterSet;
}

typedef std::pair<NSString*,NSString*> NSStringPair;

static NSStringPair Tokenise(NSString* string, NSCharacterSet* delimeters)
{
	const NSRange delimiterRange = [string rangeOfCharacterFromSet:delimeters];
	
	if(delimiterRange.location == NSNotFound) return NSStringPair(string, nil);
	
	NSString* firstToken = [string substringToIndex:delimiterRange.location];
	
	NSString* restOfString = (NSMaxRange(delimiterRange) < [string length])
		? [string substringFromIndex:NSMaxRange(delimiterRange)]
		: nil;
	
	return NSStringPair(firstToken, restOfString);
}

- (id)objectForPath:(NSString*)objectPath
{
	NSStringPair pair = Tokenise(objectPath, DotCharacterSet());
	
	NSString* firstObjectPathNode = pair.first;
	if(firstObjectPathNode == nil) return nil;
	
	NSString* otherObjectPathNodes = pair.second;
	
	NSScanner* numberScanner = [NSScanner scannerWithString:firstObjectPathNode];
	int index = -1;
	const BOOL scannedNumberSuccessfully = [numberScanner scanInt:&index];
	
	if(scannedNumberSuccessfully && index >= 0 && (unsigned)index < [self count])
	{
		id object = [self objectAtIndex:index];
		
		if(object == nil) return nil;
		else if([otherObjectPathNodes length] > 0) return [object objectForPath:otherObjectPathNodes];
		else return object;
	}
	else
	{
		return nil;
	}
}

@end

//---------------------------------------------------------------------------

@implementation NSDictionary (ObjectPathSupport)

- (id)objectForPath:(NSString*)objectPath
{
	NSStringPair pair = Tokenise(objectPath, DotCharacterSet());
	
	NSString* firstObjectPathNode = pair.first;
	if(firstObjectPathNode == nil) return nil;
	
	NSString* otherObjectPathNodes = pair.second;
	
	id object = [self objectForKey:firstObjectPathNode];
	
	if(object == nil) return nil;
	else if([otherObjectPathNodes length] > 0) return [object objectForPath:otherObjectPathNodes];
	else return object;
}

@end

//***************************************************************************
