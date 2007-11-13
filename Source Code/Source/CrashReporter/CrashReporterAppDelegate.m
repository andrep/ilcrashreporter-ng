//
//  CrashReporterAppDelegate.m
//  ILCrashReporter
//
//  Created by Claus Broch on Wed Jun 02 2004.
//  Copyright 2004 Infinite Loop. All rights reserved.
//

//#import <Message/NSMailDelivery.h>

#import "CrashReporterAppDelegate.h"
#import "GetPID.h"
#import "SMTPMailDelivery.h"
#import "SystemProfileReporter.h"

#include <unistd.h>
#include <sys/sysctl.h>

@interface CrashReporterAppDelegate(Private)

- (void)_suppressAppleCrashNotify;
- (void)_appTerminated:(NSNotification *)notification;
- (void)_appLaunched:(NSNotification *)notification;
- (void)_displayCrashNotificationForProcess:(NSString*)processName;
- (void)_serviceCrashAlert;
- (BOOL)_submitCrashReportToApple:(NSDictionary*)report;
- (NSDictionary*)_systemVersionDictionary;
- (NSString*)_systemProductVersion;
- (NSString*)_systemProductBuildVersion;
- (NSString*)_machineModelName;
- (unsigned long)_machinePhysicalMemoryInMegabytes;

@end

@implementation CrashReporterAppDelegate

- (void)dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	[_processName release];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[reportController setDelegate:self];
}

@end

@implementation CrashReporterAppDelegate(CrashReporterControllerDelegate)

- (void)userDidSubmitCrashReport:(NSDictionary*)report
{
	if(report)
	{
		const BOOL submittedToAppleSuccessfully = [self _submitCrashReportToApple:report];
		if(submittedToAppleSuccessfully) NSLog(@"Succesfully sent crash report for %@ to Apple", _processName);
		else NSLog(@"Couldn't submit crash report for %@ to Apple", _processName);
		
		//NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults]; 
		//NSString* smtpFromAddress = [defaults stringForKey:PMXSMTPFromAddress]; 
		NSString	*subject;
		BOOL sent = NO; 
		NSFileWrapper* fw; 
		//NSTextAttachment* ta; 
		//NSAttributedString* msg;
		NSString	*notes;
		NSString	*log;
		NSString	*logName;
		NSString	*name;
		NSString	*email;
		NSString	*mailMessage;
		NSMutableArray	*attachments = [NSMutableArray array];
		
		name = [report objectForKey:@"name"];
		email = [report objectForKey:@"email"];
		notes = [report objectForKey:@"notes"];
		if(name || email)
			mailMessage = [NSString stringWithFormat:NSLocalizedString(@"Reported by: %@ <%@>\n\n%@", @"Report template"), name, email, notes];
		else
			mailMessage = notes;
		
		log = [report objectForKey:@"crashlog"];
		logName = [NSString stringWithFormat:@"%@.crash.log", _processName];
		fw = [[NSFileWrapper alloc] initRegularFileWithContents:[log dataUsingEncoding:NSUTF8StringEncoding]]; 
		[fw setFilename:logName]; 
		[fw setPreferredFilename:logName]; 
		[attachments addObject:fw];

		log = [report objectForKey:@"consolelog"];
		logName = @"console.log";
		fw = [[NSFileWrapper alloc] initRegularFileWithContents:[log dataUsingEncoding:NSUTF8StringEncoding]]; 
		[fw setFilename:logName]; 
		[fw setPreferredFilename:logName]; 
		[attachments addObject:fw];
		
		//ta = [[NSTextAttachment alloc] initWithFileWrapper:fw];
		//msg = [NSAttributedString attributedStringWithAttachment:ta]; 
		subject = [NSString stringWithFormat:NSLocalizedString(@"Crash report for \"%@\"", "Crash report window title"), _processName];
		
		
#if 1
		NSData *rawMail = [SMTPMailDelivery mailMessage:mailMessage 
											 withSubject:subject
													  to:_reportEmail
													from:_fromEmail
											 attachments:attachments];
		if(_smtpServer)
		{
			SMTPMailDelivery	*sender;
			
			sender = [[SMTPMailDelivery alloc] init];
			sent = [sender sendMail:rawMail to:_reportEmail from:_fromEmail usingServer:_smtpServer onPort:_smtpPort];
			[sender release];
		}
		else
		{
			sent = [SMTPMailDelivery sendMail:rawMail
										   to:_reportEmail
										 from:_fromEmail];
		}
		
		if(sent)
			NSLog(@"Successfully sent crash report to %@", _companyName);
		else
			NSLog(@"Could not send crash report to %@", _companyName);
#else
		NSMutableDictionary *headers = [NSMutableDictionary dictionary]; 
		[headers setObject:_fromEmail forKey:@"From"]; 
		[headers setObject:_reportEmail forKey:@"To"]; 
		[headers setObject:subject forKey:@"Subject"]; 
		[headers setObject:@"ILCrashReporter" forKey:@"X-Mailer"]; 
		[headers setObject:@"multipart/mixed" forKey:@"Content-Type"]; 
		[headers setObject:@"1.0" forKey:@"Mime-Version"]; 

		if([NSMailDelivery hasDeliveryClassBeenConfigured])
		{
			sent = [NSMailDelivery deliverMessage:msg 
										  headers:headers 
										   format:NSMIMEMailFormat 
										 protocol:NSSMTPDeliveryProtocol];
		}
#endif
		
		//[ta release]; 
		[fw release];
		
		_shouldQuit = YES;
		
		[NSApp terminate:nil];
	}
}

- (void)userDidCancelCrashReport
{
	_shouldQuit = YES;
	
	[NSApp terminate:nil];
}

@end

@implementation CrashReporterAppDelegate(NSApplicationDelegate)


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
#if DEBUG
	NSLog(@"applicationShouldTerminate:");
#endif
	
	return _shouldQuit;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
#if DEBUG
	NSLog(@"applicationShouldTerminateAfterLastWindowClosed:");
#endif
	
	return _shouldQuit;
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	//NSLog(@"applicationWillFinishLaunching:");
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	//NSProcessInfo   *procInfo;
	//NSArray			*args;
	NSUserDefaults	*defaults;
	
	defaults = [NSUserDefaults standardUserDefaults];
	
	//NSLog(@"applicationDidFinishLaunching:");
	_processToWatch = [defaults integerForKey:@"pidToWatch"];
	_companyName = [defaults stringForKey:@"company"];
	_reportEmail = [defaults stringForKey:@"reportAddr"];
	_fromEmail = [defaults stringForKey:@"fromAddr"];
	_smtpServer = [defaults stringForKey:@"smtpServer"];
	if([defaults objectForKey:@"smtpPort"])
		_smtpPort = [defaults integerForKey:@"smtpPort"];
	
	if(_smtpPort == 0)
		_smtpPort = 25;

	if ((_processToWatch == 0) || (_reportEmail == nil) || ([_reportEmail isEqualToString:@""])) {
		_shouldQuit = YES;
		[NSApp terminate:nil];
	}
	
#if DEBUG
	NSLog(@"%@", [[NSProcessInfo processInfo] arguments]);
#endif
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
														   selector:@selector(_appTerminated:)
															   name:NSWorkspaceDidTerminateApplicationNotification
															 object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
														   selector:@selector(_appLaunched:)
															   name:NSWorkspaceDidLaunchApplicationNotification
															 object:nil];
	if([defaults boolForKey:@"EnableInterfaceTest"])
	{
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self
															selector:@selector(_displayCrashNotificationTest:)
																name:@"ILCrashReporterTest"
															  object:nil];
	}
}

@end

@implementation CrashReporterAppDelegate(Private)

- (void)_displayCrashNotificationTest:(NSNotification*)notification
{
	_processName = [[notification object] retain];
	[self _displayCrashNotificationForProcess:_processName];
}

- (void)_displayCrashNotificationForProcess:(NSString*)processName
{
	NSString	*title;
	NSString	*message;
	NSString	*button1;
	NSString	*button2;

	title = [NSString stringWithFormat:NSLocalizedString(@"The application %@ has unexpectedly quit.", @"App crash title"), processName];
	message = [NSString stringWithFormat:NSLocalizedString(@"The system and other applications have not been affected.\n\nWould you like to submit a bug report to %@?", @"App crash message"), _companyName];
	button1 = NSLocalizedString(@"Cancel", @"Button title");
	button2 = NSLocalizedString(@"Submit Report...", @"Button title");
	_alertPanel = NSGetInformationalAlertPanel(title, message, button1, nil, button2);
	if(_alertPanel)
	{
		_alertSession = [NSApp beginModalSessionForWindow:_alertPanel];
		[_alertPanel setLevel:NSStatusWindowLevel];
		//[_alertPanel orderFrontRegardless];
		[_alertPanel makeKeyAndOrderFront:self];
		[self _serviceCrashAlert];
	}
}

- (void)_serviceCrashAlert
{
	int response = [NSApp runModalSession:_alertSession];
	if(response == NSRunContinuesResponse)
	{
		[self performSelector:@selector(_serviceCrashAlert) withObject:nil afterDelay:0.05];
	}
	else
	{
		[NSApp endModalSession:_alertSession];
		NSReleaseAlertPanel(_alertPanel);
		_alertPanel = nil;
		
		if(response == NSAlertOtherReturn)
		{
			[reportController prepareReportForApplication:_processName process:_processToWatch companyName:_companyName];
		}
		else
		{
			_shouldQuit = YES;
			[NSApp terminate:nil];
		}
	}
	
}

- (void)_suppressAppleCrashNotify
{
	pid_t			pids[50];   // More than enough ???
	unsigned int	noOfPids = 0;
	int				err;
	static int		noOfRuns = 0;
	static BOOL		firstBlood = NO;
	
	// This is a dirty, rotten hack but it seems to work
	err = GetAllPIDsForProcessName("UserNotificationCenter", pids, 50, &noOfPids, nil);
	if(err == 0)
	{
		int i;
		
		for(i = 0; i < noOfPids; i++)
		{
			kill(pids[i], SIGTERM);
#if DEBUG
			NSLog(@"Suppressed Apple Crash Notify (pid: %d)", pids[i]);
#endif
			
			// When the Apple Crash notification is shown the crash data has been gathered
			// (at least that's what my tests show)
			if(!firstBlood)
			{
				firstBlood = YES;
				[self _displayCrashNotificationForProcess:_processName];
			}
		}
	}
	
	if(noOfRuns++ < 100) // Don't run forever
		[self performSelector:@selector(_suppressAppleCrashNotify) withObject:nil afterDelay:0.1+((float)noOfRuns / 50.0)];
	else
	{
#if DEBUG
		NSLog(@"Bye bye");
#endif
		if (!firstBlood) {
			_shouldQuit = YES;
			[NSApp terminate:self];
		}
	}
}

- (void)_appTerminated:(NSNotification *)notification
{
	NSDictionary	*info;
	NSNumber		*pid;
	
	info = [notification userInfo];
	pid = [info objectForKey:@"NSApplicationProcessIdentifier"];
	if(pid && ([pid intValue] == _processToWatch))
	{
		//_processName = [[info objectForKey:@"NSApplicationName"] retain];
		_processName = [[[[NSBundle bundleWithPath:[info objectForKey:@"NSApplicationPath"]] executablePath] lastPathComponent] retain];
		
		NSLog(@"%@ terminated unexpectedly - preparing report", _processName);
		
		[self _suppressAppleCrashNotify];
		//[NSApp terminate:self];
	}
	//NSLog(@"appTerminated: %@", notification);
}

- (NSDictionary*)_systemVersionDictionary
{
	static NSDictionary* systemVersionPropertyList = nil;
	
	// The documentation for gestaltSystemVersion says to use this file to
	// determine the Mac OS X version number, so I ain't going to argue with
	// it...
	
	if(systemVersionPropertyList == nil)
	{
		systemVersionPropertyList = [[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"] retain];
	}
	
	return systemVersionPropertyList;
}

- (NSString*)_systemProductVersion
{
	return [[self _systemVersionDictionary] objectForKey:@"ProductVersion"];
}

- (NSString*)_systemProductBuildVersion
{
	return [[self _systemVersionDictionary] objectForKey:@"ProductBuildVersion"];
}

- (NSString*)_machineModelName
{
	size_t hwModelSysctlBufferSize = 0;
	const int sysctlResult1 = sysctlbyname("hw.model", NULL, &hwModelSysctlBufferSize, NULL, 0);
	NSAssert1(sysctlResult1 == 0, @"sysctlbyname(1) returned non-zero value: %d", sysctlResult1);
	
	char hwModelBuffer[hwModelSysctlBufferSize];
	const int sysctlResult2 = sysctlbyname("hw.model", hwModelBuffer, &hwModelSysctlBufferSize, NULL, 0);
	NSAssert1(sysctlResult2 == 0, @"sysctlbyname(2) returned non-zero value: %d", sysctlResult1);
	
	return [NSString stringWithUTF8String:hwModelBuffer];
}

- (unsigned long)_machinePhysicalMemoryInMegabytes
{
	long physicalRAMSizeInMegabytes;
	
	const OSErr gestaltResult = Gestalt(gestaltPhysicalRAMSizeInMegabytes, &physicalRAMSizeInMegabytes);
	NSCAssert1(gestaltResult == noErr, @"gestaltPhysicalRAMSizeInMegabytes returned %d", gestaltResult);
	
	return physicalRAMSizeInMegabytes;
}

+ (NSString*)_temporaryFilename
{
	for(;;)
	{
		NSString* temporaryFilenameTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ILCrashReporter-XXXXXX"];
		
		// Need to strdup() the result of -fileSystemRepresentation below
		// since mktemp() overwrites the buffer
		char* cTemporaryFilenameTemplate = strdup([temporaryFilenameTemplate fileSystemRepresentation]);

		// Using mktemp() is safe here since we use open(2) with O_EXCL below:
		// see mktemp(3) for more information
		char* cTemporaryFilename = mktemp(cTemporaryFilenameTemplate);
		
		const int temporaryFileDescriptor = open(cTemporaryFilename, O_CREAT|O_EXCL, S_IRWXU);

		NSString* temporaryFilename = [NSString stringWithUTF8String:cTemporaryFilename];
		
		free(cTemporaryFilenameTemplate);
		if(cTemporaryFilename != cTemporaryFilenameTemplate) free(cTemporaryFilename);
		
		if(temporaryFileDescriptor >= 0)
		{
			close(temporaryFileDescriptor);
			
			return temporaryFilename;
		}
		else if(temporaryFileDescriptor == -1 && errno == EEXIST)
		{
			continue;
		}
		else
		{
			NSLog(@"open() for %@ returned %d", temporaryFilename, errno);
			return nil;
		}
	}
}

- (BOOL)_submitCrashReportToApple:(NSDictionary*)report
{
	if(_processName == nil)
	{
		NSLog(@"Couldn't determine process name");
		return NO;
	}
	
	NSString* versionString = [reportController versionStringForApplication:_processName];
	if(versionString == nil)
	{
		NSLog(@"Couldn't determine application version");
		return NO;
	}
	
	NSString* crashLog = [reportController anonymisedCrashLog:_processName];
	if(crashLog == nil)
	{
		NSLog(@"Couldn't locate crash log for %@", _processName);
		return NO;
	}

	NSString* temporaryCrashLogPath = [CrashReporterAppDelegate _temporaryFilename];
	if(temporaryCrashLogPath == nil)
	{
		NSLog(@"Unable to determine filename for temporary crash log path");
		return NO;
	}
	
	const BOOL wroteTemporaryCrashLogSuccessfully = [crashLog writeToFile:temporaryCrashLogPath atomically:NO];
	if(!wroteTemporaryCrashLogSuccessfully)
	{
		NSLog(@"Couldn't write temporary crash log to %@", temporaryCrashLogPath);
		return NO;
	}
	
	NSString* notes = [report objectForKey:@"notes"] ? [report objectForKey:@"notes"] : @"";
	
	NSData* systemProfile = [SystemProfileReporter systemProfileReport];
	if(systemProfile == nil)
	{
		NSLog(@"System profile couldn't be generated");
		return NO;
	}
	
	NSString* systemProfileReportPath = [CrashReporterAppDelegate _temporaryFilename];
	if(systemProfileReportPath == nil)
	{
		NSLog(@"Unable to determine filename for temporary system profile report path");
	}
	
	const BOOL wroteSystemProfileReportSuccessfully = [systemProfile writeToFile:systemProfileReportPath atomically:NO];
	if(!wroteSystemProfileReportSuccessfully)
	{
		NSLog(@"Couldn't write system profile to %@", systemProfileReportPath);
		return NO;
	}
	
	NSDictionary* formInformation = [NSDictionary dictionaryWithObjectsAndKeys:
									 [NSString stringWithFormat:@"%@ crash", _processName], @"url_from",
									 [report objectForKey:notes] ? [report objectForKey:notes] : @"", @"feedback_comments",
									 @"9", @"bug_type",
									 _processName, @"app_name",
									 versionString, @"app_version",
									 [NSString stringWithFormat:@"%@:%@", [self _systemProductVersion], [self _systemProductBuildVersion]], @"os_version",
									 [NSString stringWithFormat:@"%@ (%luMB)", [self _machineModelName], [self _machinePhysicalMemoryInMegabytes]], @"machine_config",
									 [NSString stringWithFormat:@"<%@", temporaryCrashLogPath], @"page_source",
									 [NSString stringWithFormat:@"<%@", systemProfileReportPath], @"system_profile",
									 nil];

	NSMutableArray* curlArguments = [NSMutableArray array];
	
	[curlArguments addObject:@"-q"];

	NSEnumerator* formInformationEnumerator = [formInformation keyEnumerator];
	NSString* formKey = nil;
	while(formKey = [formInformationEnumerator nextObject])
	{
		NSString* formValue = [formInformation objectForKey:formKey];
		[curlArguments addObject:@"-F"];
		[curlArguments addObject:[NSString stringWithFormat:@"%@=%@", formKey, formValue]];
	}
	
	[curlArguments addObject:@"http://radarsubmissions.apple.com/process.jsp"];
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/curl"])
	{
		NSLog(@"/usr/bin/curl doesn't exist?");
		return NO;
	}
	
	NSTask* curlTask = [[NSTask alloc] init];
	[curlTask setLaunchPath:@"/usr/bin/curl"];
	[curlTask setArguments:curlArguments];
	[curlTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
	[curlTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	
	[curlTask launch];
	[curlTask waitUntilExit];
	const BOOL curlRanSucessfully = ([curlTask terminationStatus] == 0);
	
	[[NSFileManager defaultManager] removeFileAtPath:temporaryCrashLogPath handler:nil];
	
	return curlRanSucessfully;
}

- (void)_appLaunched:(NSNotification *)notification
{
	NSDictionary	*info;
	//NSNumber		*pid;
	
	info = [notification userInfo];

#if DEBUG
	NSLog(@"_appLaunched: %@", info);
#endif
}

@end
