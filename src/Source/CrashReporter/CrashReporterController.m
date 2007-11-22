//
//  CrashReporterController.m
//  ILCrashReporter
//
//  Created by Claus Broch on Sun Jul 11 2004.
//  Copyright 2004 Infinite Loop. All rights reserved.
//

#include "asl-weak.h"

#import <fcntl.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <AddressBook/AddressBook.h>
#import "CrashReporterController.h"

@interface CrashReporterController(Private)

- (void)setupLocalizedFields;
- (void)fillOutUserCredentials;
- (NSString*)gatherConsoleLogForApplication:(NSString*)appName withProcessID:(int)processID;
- (NSString*)currentArchitecture;
- (NSString*)pathToCrashLogForApplication:(NSString*)appName;
- (NSString*)rawCrashLog:(NSString*)appName;
- (NSString*)gatherCrashLog:(NSString*)appName;

@end

@implementation CrashReporterController

- (void)prepareReportForApplication:(NSString*)appName process:(int)processID companyName:(NSString*)companyName
{
	NSWindow	*win;
	NSString	*crashLog;
	NSString	*consoleLog;
	NSString	*buttonText;
	NSString	*windowTitle;
	NSRect		frame;
	float		x;
	
	//Make sure window is loaded from nib
	win = [self window];
	
	[self setupLocalizedFields];
	[self fillOutUserCredentials];
	
	//[crashLogHeader setStringValue:NSLocalizedString(@"Crash Report:", @"Crash log header")];
	[[reportsTabView tabViewItemAtIndex:
		[reportsTabView indexOfTabViewItemWithIdentifier:@"crashreport"]]
		setLabel:NSLocalizedString(@"Crash Report", @"Crash log header")];
	crashLog = [self gatherCrashLog:appName];
	[crashLogTextView setString:(crashLog ? crashLog : @"")];
	
	[[reportsTabView tabViewItemAtIndex:
		[reportsTabView indexOfTabViewItemWithIdentifier:@"consolelog"]]
		setLabel:NSLocalizedString(@"Console Log", @"Console log header")];
	consoleLog = [self gatherConsoleLogForApplication:appName withProcessID:processID];
	[consoleLogTextView setString:(consoleLog ? consoleLog : @"")];
		

	buttonText = [NSString stringWithFormat:
		NSLocalizedString(@"Send to %@", @"Send to #COMPANY# button text"), companyName];
	[submitButton setTitle:buttonText];
	frame = [submitButton frame];
	x = NSMaxX(frame);
	[submitButton sizeToFit];
	frame = [submitButton frame];
	frame.origin.x += x - NSMaxX(frame);
	[submitButton setFrameOrigin:frame.origin];

	windowTitle = [NSString stringWithFormat:NSLocalizedString(@"Crash report for \"%@\"", "Crash report window title"), appName];
	[win setTitle:windowTitle];
	
	[win setLevel:NSNormalWindowLevel];
	[win makeKeyAndOrderFront:self];
	//[win orderFrontRegardless];
}

- (IBAction)submitReport:(id)sender
{
	NSString		*userNotes;
	NSString		*crashLog;
	NSString		*consoleLog;
	NSString		*name;
	NSString		*email;
	NSDictionary	*report;
	
	if([_delegate respondsToSelector:@selector(userDidSubmitCrashReport:)])
	{
		userNotes = [descriptionTextView string];
		crashLog = [crashLogTextView string];
		consoleLog = [consoleLogTextView string];
		name = [nameField stringValue];
		email = [emailField stringValue];
		report = [NSDictionary dictionaryWithObjectsAndKeys:
			userNotes, @"notes",
			crashLog, @"crashlog",
			consoleLog, @"consolelog",
			(name != nil) ? name : @"", @"name",
			(email != nil) ? email : @"", @"email",
			nil ];
		
		[_delegate userDidSubmitCrashReport:report];
		_hasSubmittedReport = YES;
	}
	
	[[self window] performClose:self];
}

- (void)windowWillClose:(NSNotification *)notification
{
	if(!_hasSubmittedReport)
	{
		if([_delegate respondsToSelector:@selector(userDidCancelCrashReport)])
			[_delegate userDidCancelCrashReport];
	}
}

- (void)setDelegate:(id)delegate
{
	if(delegate != _delegate)
	{
		[_delegate release];
		_delegate = [delegate retain];
	}
}

- (NSString*)versionStringForApplication:(NSString*)appName
{
	NSString* crashLog = [self gatherCrashLog:appName];
	if(crashLog == nil) return nil;
	
	const NSRange rangeForVersionField = [crashLog rangeOfString:@"\nVersion: "];
	if(rangeForVersionField.location == NSNotFound) return nil;
	
	const unsigned indexOfVersionFieldValueStart = NSMaxRange(rangeForVersionField);
	
	const NSRange endOfLineSearchRange = NSMakeRange(indexOfVersionFieldValueStart,
													 [crashLog length]-indexOfVersionFieldValueStart);
	if(NSMaxRange(endOfLineSearchRange) > [crashLog length]) return nil;
	
	const unsigned indexOfVersionFieldValueEndOfLine = [crashLog rangeOfString:@"\n" options:0 range:endOfLineSearchRange].location;
	if(indexOfVersionFieldValueEndOfLine == NSNotFound) return nil;
	
	const NSRange versionFieldValueRange = NSMakeRange(indexOfVersionFieldValueStart,
													   indexOfVersionFieldValueEndOfLine-indexOfVersionFieldValueStart);
	
	return [crashLog substringWithRange:versionFieldValueRange];
}

- (NSString*)anonymisedCrashLog:(NSString*)appName
{
	// Strip out the Host Name from the crash log
	NSString* crashLog = [self rawCrashLog:appName];
	
	const NSRange logInsertPoint = [crashLog rangeOfString:@"Date/Time:"];
	if((logInsertPoint.length != 0) && (logInsertPoint.location != NSNotFound))
	{
		crashLog = [crashLog substringFromIndex:logInsertPoint.location];
	}
	
	return [[crashLog stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByAppendingString:@"\n"];
}

@end

@implementation CrashReporterController(Private)

- (void)setupLocalizedFields
{
	[nameLabelField setStringValue:
		NSLocalizedString(@"Your name:", @"Field header")];
	[nameField setToolTip:
		NSLocalizedString(@"Leave field blank to remain anomymous", @"Field tool tip")];
	[emailLabelField setStringValue:
		NSLocalizedString(@"Your email:", @"Field header")];
	[emailField setToolTip:
		NSLocalizedString(@"Leave field blank to remain anomymous", @"Field tool tip")];
	
	[descriptionHeader setStringValue:
		NSLocalizedString(@"Problem Description:", @"Description header")];
	[descriptionTextView setString:
		NSLocalizedString(@"Please describe the circumstances leading to the crash and any other relevant information:\n\n", @"Description text")];
}

- (void)fillOutUserCredentials
{
	ABAddressBook	*book = [ABAddressBook sharedAddressBook];
	ABPerson	*me = [book me];
	
	// Current User
	if(me)
	{
		NSString	*firstName;
		NSString	*lastName;
		
		firstName = [me valueForProperty:kABFirstNameProperty];
		lastName = [me valueForProperty:kABLastNameProperty];
		if(firstName || lastName)
		{
			[nameField setStringValue:[NSString stringWithFormat:@"%@%@%@",
										  firstName ? firstName : @"",
								   firstName && lastName ? @" " : @"",
											lastName ? lastName : @""]];
		}
	}
	else
	{
		[nameField setStringValue:NSFullUserName()];
	}
	
	// Email
	if(me)
	{
		ABMultiValue *mails = [me valueForProperty:kABEmailProperty];
		if(mails && [mails count])
		{
			NSString	*email = [mails valueAtIndex:[mails indexForIdentifier:[mails primaryIdentifier]]];
			
			if(!email)
				email = [mails valueAtIndex:0];
			if(email)
				[emailField setStringValue:email];
		}
	}
}

- (NSString*)pathToCrashLogForApplication:(NSString*)appName
{
	NSFileManager* fileManager = [NSFileManager defaultManager];
	
	NSString* crashLogName = [NSString stringWithFormat:@"%@.crash.log", appName];
	
	NSArray* possibleDirectoriesForCrashLog = [NSArray arrayWithObjects:
		[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/CrashReporter"],
		@"/Library/Logs/CrashReporter",
		nil];
	
	NSEnumerator* directoryEnumerator = [possibleDirectoriesForCrashLog objectEnumerator];
	NSString* directoryToSearchForCrashLog = nil;
	while(directoryToSearchForCrashLog = [directoryEnumerator nextObject])
	{
		// Search for Mac OS X 10.5 (Leopard) crash logs
		
		NSString* leopardCrashLogLocation = nil;
		
		NSDate* latestCrashLogModificationDate = [NSDate distantPast];
		
		NSEnumerator* filesEnumerator = [[fileManager directoryContentsAtPath:directoryToSearchForCrashLog] objectEnumerator];
		NSString* filename = nil;
		while(filename = [filesEnumerator nextObject])
		{
			if(![filename hasPrefix:appName]) continue;
			
			NSString* fullPathFilename = [directoryToSearchForCrashLog stringByAppendingPathComponent:filename];
			NSDate* fileModificationDate = [[fileManager fileAttributesAtPath:fullPathFilename traverseLink:NO] objectForKey:NSFileModificationDate];
			if([latestCrashLogModificationDate compare:fileModificationDate] == NSOrderedAscending)
			{
				leopardCrashLogLocation = fullPathFilename;
				latestCrashLogModificationDate = fileModificationDate;
			}
		}
		
		if(leopardCrashLogLocation) return leopardCrashLogLocation;
		
		// Search for Mac OS X 10.0-10.4 (Cheetah to Tiger) crash logs

		NSString* tigerCrashLogLocation = [directoryToSearchForCrashLog stringByAppendingPathComponent:crashLogName];
		
		if([fileManager fileExistsAtPath:tigerCrashLogLocation]) return tigerCrashLogLocation;
	}
	
	return nil;
}

- (NSString*)_gatherConsoleLogViaAppleSystemLogger:(NSString*)applicationName fromDate:(NSDate*)date
{
	// asl_* functions only exist on Mac OS X 10.4 (Tiger) onward, so bail out
	// early if the functions don't exist.  (See the #include'd "asl-weak.h"
	// file: it's the same as /usr/include/asl.h, but all functions are
	// defined to be weak-imported.)
	if(asl_new == NULL || asl_set_query == NULL || asl_search == NULL
	   || aslresponse_next == NULL || asl_get == NULL
	   || aslresponse_free == NULL)
	{
		return nil;
	}
	
	aslmsg query = asl_new(ASL_TYPE_QUERY);
	if(query == NULL) return nil;
	
	const uint32_t senderQueryOptions = ASL_QUERY_OP_EQUAL|ASL_QUERY_OP_CASEFOLD|ASL_QUERY_OP_SUBSTRING;
	const int aslSetSenderQueryReturnCode = asl_set_query(query, ASL_KEY_SENDER, [applicationName UTF8String], senderQueryOptions);
	if(aslSetSenderQueryReturnCode != 0) return nil;
	
	static const size_t timeBufferLength = 64;
	char oneHourAgo[timeBufferLength];
	snprintf(oneHourAgo, timeBufferLength, "%0lf", [date timeIntervalSince1970]);
	const int aslSetTimeQueryReturnCode = asl_set_query(query, ASL_KEY_TIME, oneHourAgo, ASL_QUERY_OP_GREATER_EQUAL);
	if(aslSetTimeQueryReturnCode != 0) return nil;
	
	aslresponse response = asl_search(NULL, query);
	
	NSMutableString* searchResults = [NSMutableString string];
	for(;;)
	{
		aslmsg message = aslresponse_next(response);
		if(message == NULL) break;
		
		const char* time = asl_get(message, ASL_KEY_TIME);
		if(time == NULL) continue;
		
		const char* level = asl_get(message, ASL_KEY_LEVEL);
		if(level == NULL) continue;
		
		const char* messageText = asl_get(message, ASL_KEY_MSG);
		if(messageText == NULL) continue;
		
		NSCalendarDate* date = [NSCalendarDate dateWithTimeIntervalSince1970:atof(time)];
		
		[searchResults appendFormat:@"%@[%s]: %s\n", [date description], level, messageText];
	}
	
	aslresponse_free(response);
	
	return searchResults;
}

- (NSString*)gatherConsoleLogForApplication:(NSString*)appName withProcessID:(int)processID
{
	NSDate* oneHourAgo = [[NSCalendarDate calendarDate] dateByAddingYears:0 months:0 days:0 hours:(-1) minutes:0 seconds:0];
	NSString* consoleLog = [self _gatherConsoleLogViaAppleSystemLogger:appName fromDate:oneHourAgo];
	
	if(consoleLog == nil)
	{
		NSString* path = [NSString stringWithFormat:@"/Library/Logs/Console/%d/console.log", getuid()]; //10.4
		
		if(!path || ![[NSFileManager defaultManager] fileExistsAtPath:path])
			path = [NSString stringWithFormat:@"/Library/Logs/Console/%@/console.log", NSUserName()]; // 10.3
		if(!path || ![[NSFileManager defaultManager] fileExistsAtPath:path])
			path = @"/var/tmp/console.log"; // 10.2
		path = [path stringByResolvingSymlinksInPath];
		if([[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			consoleLog = [NSString stringWithContentsOfFile:path];
			
			// Limit the console log to 512 KB to prevent over-stuffing the receiving email account
			if([consoleLog length] > 512*1024)
				consoleLog = [consoleLog substringToIndex:512*1024];
		}
	}
	
	return consoleLog;
}

- (NSString*)currentArchitecture
{
	size_t size;
	cpu_type_t	cputype;
	cpu_subtype_t	subtype;
	
	size = sizeof(cputype);
	if(sysctlbyname("hw.cputype", &cputype, &size, NULL, 0) < 0)
		cputype = 0;
	size = sizeof(subtype);
	if(sysctlbyname("hw.cpusubtype", &subtype, &size, NULL, 0) < 0)
		subtype = 0;
	
	switch(cputype)
	{
		case CPU_TYPE_I386:
			return @"i386";
			
		case CPU_TYPE_POWERPC:
			switch(subtype)
			{
				case CPU_SUBTYPE_POWERPC_970:
					return @"ppc970";
					
				case CPU_SUBTYPE_POWERPC_7400:
				case CPU_SUBTYPE_POWERPC_7450:
					return @"ppc7400";
					
				default:
					return @"ppc";
			}
			
		case CPU_TYPE_POWERPC64:
			return @"ppc64";
	}
	
	return @"unknown";
}

- (NSString*)rawCrashLog:(NSString*)appName
{
	static NSString* cachedCrashLog = nil;
	
	if(cachedCrashLog) return cachedCrashLog;
	
	NSString* crashLogPath = [self pathToCrashLogForApplication:appName];
	if(!crashLogPath)
	{
		NSLog(@"Could not find crashlog for %@", appName);
		return NSLocalizedString(@"Could not locate crash report.", @"Missing crash report");
	}
	
	NSString* crashLog = [NSString stringWithContentsOfFile:crashLogPath];
	if(!crashLog)
	{
		NSLog(@"Could not load crashlog: %@", crashLogPath);
		return nil;
	}
	
	const NSRange delimRng = [crashLog rangeOfString:@"**********" options:NSBackwardsSearch];
	if(delimRng.location == NSNotFound && delimRng.length == 0)
	{
		// Crash log only contains one entry, which should be the correct one
		return crashLog;
	}
	
	// Crash log contains more logs - only need the last one
	NSRange logRange;
	logRange.location = delimRng.location + delimRng.length;
	logRange.length = [crashLog length] - logRange.location;
	
	cachedCrashLog = [[crashLog substringWithRange:logRange] retain];
	
	return cachedCrashLog;
}

- (NSString*)gatherCrashLog:(NSString*)appName
{
	// Insert a line to make it easier to match stripped universal binary versions with the unstripped version
	NSString* crashLog = [self rawCrashLog:appName];
	const NSRange logInsertPoint = [crashLog rangeOfString:@"Date/Time:"];
	
	if((logInsertPoint.length != 0) && (logInsertPoint.location != NSNotFound))
	{
		crashLog = [NSString stringWithFormat:@"%@Architecture:   %@\n%@",
			[crashLog substringToIndex:logInsertPoint.location],
			[self currentArchitecture],
			[crashLog substringFromIndex:logInsertPoint.location]];
	}
	
	return [[crashLog stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByAppendingString:@"\n"];
}

@end

