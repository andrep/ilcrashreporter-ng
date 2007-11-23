#import <ILCrashReporter/ILCrashReporter.h>
#import "SampleCrashApp.h"

@implementation SampleCrashApp

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	// Launch the crash reporter task
	// Make sure to change the name and email before running the application
	[[ILCrashReporter defaultReporter] launchReporterForCompany:@"My Company" reportAddr:@"report@my.company"];
}

- (void)bam
{
	NSLog(@"About to crash... 3... 2... 1...");
	
	// Leopard installs an extra exception handler that will catch the NULL-
	// pointer dereference below, so we need to reset it to the default OS
	// behaviour.
	signal(SIGBUS, SIG_DFL);
	
	// Write to address 0 -> ka-boom!!!!
	*(long*)0 = 0xDEADBEEF;
}

- (IBAction)doCrash:(id)sender
{
	// Invoke another method just to change the stack trace a bit.
	
	[self bam];
}

@end
