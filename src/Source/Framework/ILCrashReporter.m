//
//  ILCrashReporter.m
//  ILCrashReporter
//
//  Created by Claus Broch on Thu Jul 22 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "ILCrashReporter.h"

@implementation ILCrashReporter

+ (ILCrashReporter*)defaultReporter
{
	static ILCrashReporter *reporter = nil;
	
	if(reporter == nil) reporter = [[ILCrashReporter alloc] init];
	
	return reporter;
}

- (void)dealloc
{
	[_reporterTask release];
	_reporterTask = nil;
	
	[self setCompanyName:nil];
	[self setReportAddress:nil];
	[self setFromAddress:nil];
	[self setSMTPServer:nil];
	[self setUserInfo:nil];
	
	[super dealloc];
}

- (NSString *)companyName {
    return [[_companyName retain] autorelease];
}

- (void)setCompanyName:(NSString *)value {
    if (_companyName != value) {
        [_companyName release];
        _companyName = [value copy];
    }
}

- (NSString *)reportAddress {
    return [[_reportAddress retain] autorelease];
}

- (void)setReportAddress:(NSString *)value {
    if (_reportAddress != value) {
        [_reportAddress release];
        _reportAddress = [value copy];
    }
}

- (NSString *)fromAddress {
    return [[_fromAddress retain] autorelease];
}

- (void)setFromAddress:(NSString *)value {
    if (_fromAddress != value) {
        [_fromAddress release];
        _fromAddress = [value copy];
    }
}

- (NSString *)SMTPServer {
    return [[_SMTPServer retain] autorelease];
}

- (void)setSMTPServer:(NSString *)value {
    if (_SMTPServer != value) {
        [_SMTPServer release];
        _SMTPServer = [value copy];
    }
}

- (uint16_t)SMTPPort {
	return _SMTPPort;
}

- (void)setSMTPPort:(uint16_t)value {
	_SMTPPort = value;
}

- (NSString *)userInfo {
    return [[_userInfo retain] autorelease];
}

- (void)setUserInfo:(NSString *)value {
    if (_userInfo != value) {
        [_userInfo release];
        _userInfo = [value copy];
    }
}

- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr
{
	[self launchReporterForCompany:company reportAddr:reportAddr fromAddr:reportAddr];
}

- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr userInfo:(NSString*)userInfo
{
	[self launchReporterForCompany:company reportAddr:reportAddr fromAddr:reportAddr smtpServer:nil smtpPort:25 userInfo:userInfo];
}

- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr fromAddr:(NSString*)fromAddr
{
	[self launchReporterForCompany:company reportAddr:reportAddr fromAddr:fromAddr smtpServer:nil smtpPort:25];
}

- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr fromAddr:(NSString*)fromAddr smtpServer:(NSString*)smtpServer smtpPort:(int)smtpPort
{
	[self launchReporterForCompany:company reportAddr:reportAddr fromAddr:fromAddr smtpServer:nil smtpPort:25 userInfo:@""];
}

- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr fromAddr:(NSString*)fromAddr smtpServer:(NSString*)smtpServer smtpPort:(int)smtpPort userInfo:(NSString*)userInfo
{
	[self setCompanyName:company];
	[self setReportAddress:reportAddr];
	[self setFromAddress:fromAddr];
	[self setSMTPServer:smtpServer];
	
	if(smtpPort > 0 && smtpPort < 65535) [self setSMTPPort:smtpPort];
	else [NSException raise:@"Port number out of range" format:@"SMTP port number is not between [1, 65535] (%d)", smtpPort];
	
	[self setUserInfo:userInfo];
	
	[self launchReporter];
}

- (NSTask*)reporterTask
{
	NSTask* task = [[NSTask alloc] init];
	
	NSBundle* bundle = [NSBundle bundleForClass:[self class]];
	NSString* path = [bundle pathForResource:@"CrashReporter" ofType:@"app"];
	path = [path stringByResolvingSymlinksInPath];
	bundle = [NSBundle bundleWithPath:path];
	path = [bundle executablePath];
	[task setLaunchPath:path];
	
	NSProcessInfo* procInfo = [NSProcessInfo processInfo];
	const int pid = [procInfo processIdentifier];
	NSMutableArray* args = [NSMutableArray arrayWithObjects:
							@"-pidToWatch", [NSString stringWithFormat:@"%d", pid],
							@"-company", [self companyName],
							@"-reportAddr", [self reportAddress],
							@"-fromAddr", [self fromAddress],
							nil];
	
	if([[self userInfo] length] > 0)
	{
		[args addObject:@"-userInfo"];
		[args addObject:[self userInfo]];
	}
	
	if([self SMTPServer] && ![[self SMTPServer] isEqualToString:@""])
	{
		[args addObjectsFromArray:[NSArray arrayWithObjects:
								   @"-smtpServer", [self SMTPServer],
								   @"-smtpPort", [NSString stringWithFormat:@"%hd", [self SMTPPort]],
								   nil]];
	}
	
	[task setArguments:args];
	
	[task launch];
	
	
	return task;
}

- (void)launchReporter
{
	// Kill any already running CrashReporter instances
	[self terminate];

	if(_reporterTask == nil)
	{
		_reporterTask = [[self reporterTask] retain];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(_appWillTerminate:)
													 name:NSApplicationWillTerminateNotification
												   object:NSApp];
	}
}


- (void)submitManualCrashReport
{
	[self reporterTask];
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"ILCrashReporterSubmitCrashReportNow" 
																   object:[[NSProcessInfo processInfo] processName]];
}

- (void)terminate
{
	if(_reporterTask)
	{
		[_reporterTask terminate];
		[_reporterTask release];
		_reporterTask = nil;
	}
}

- (void)_appWillTerminate:(NSNotification*)notification
{
	[self terminate];
}

- (void)test
{
    NSProcessInfo   *procInfo;
    //int             pid;
	
	procInfo = [NSProcessInfo processInfo];
	//pid = [procInfo processIdentifier];
	NSLog(@"Testing crash reporter interface");
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"ILCrashReporterTest" 
																   object:[procInfo processName]];
}

@end
