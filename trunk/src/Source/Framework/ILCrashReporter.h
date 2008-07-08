/*

 COPYRIGHT AND PERMISSION NOTICE

 Copyright (c) 2004 Claus Broch, Infinite Loop. All rights reserved.

 Permission to use, copy and distribute this software for any purpose
 with or without fee is hereby granted, provided that the above copyright
 notice and this permission notice appear in all copies.

 This Software is provided by Infinite Loop on an "AS IS" basis. INFINITE LOOP
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
 WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE, REGARDING THE INFINITE LOOP SOFTWARE OR ITS USE AND OPERATION ALONE OR
 IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL INFINITE LOOP BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION
 AND/OR DISTRIBUTION OF THE INFINITE LOOP SOFTWARE, HOWEVER CAUSED AND WHETHER 
 UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
 OTHERWISE, EVEN IF INFINITE LOOP HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH 
 DAMAGE.

 Except as contained in this notice, the name of the copyright holder shall not
 be used in advertising or otherwise to promote the sale, use or other dealings
 in this Software without prior written authorization of the copyright holder.
 */ 

/*!
    @header ILCrashReporter
 The ILCrashReporter class enables developers to easily integrate crash reporting facilities into existing applications.
 The service is provided by the ILCrashReporter.framework which must be embedded into the application bundles Frameworks folder.<p>
 If the monitored application should crash or otherwise terminate unexpectedly a notification will appear
 allowing the user to provide additional information. If the user then elects to submit the report an email
 is sent directly to the address provided by the developer.
*/

#import <Foundation/Foundation.h>

/*!
    @class ILCrashReporter
    @abstract    Crash reporter task
	@discussion The ILCrashReporter class enables you to launch a background task that will monitor the launching application. If the application
 unexpectedly terminates the crash reporter will display a notification and allow the user to provide a description of the nature of the crash.
 If the user desides to complete the crash report an email is sent containing the users description and the crashlog generated by the operating system.
*/
@interface ILCrashReporter : NSObject

/*!
    @method defaultReporter
    @abstract   Default ILCrashReporter object
    @discussion Returns the default ILCrashReporter object. You invoke all ILCrashReporter instance methods with this object as the receiver.
	@result	Returns the default ILCrashReporter object or nil on failure
*/
+ (ILCrashReporter*)defaultReporter;

/*!
    @method     launchReporterForCompany:reportAddr:
    @abstract   Launch the crash reporter task
	@param		company The name of the company to send the report to. This parameter is used for displaying the company name to the user if the application terminates unexpectedly.
	@param		reportAddr The email address to send the report to. This parameter is used internally by the crash reporter and must contain the email address without enclosing brackets (&lt; or &gt;)
    @discussion Launch the crash reporter task by calling <a href="Methods.html#//apple_ref/occ/instm/ILCrashReporter/launchReporterForCompany%58reportAddr%58fromAddr%58" target="doc">launchReporterForCompany:reportAddr:fromAddr:</a> with <i>fromAddr</i> set to <i>reportAddr</i>
*/
- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr;

/*!
 @method     launchReporterForCompany:reportAddr:
 @abstract   Launch the crash reporter task
 @param		company The name of the company to send the report to. This parameter is used for displaying the company name to the user if the application terminates unexpectedly.
 @param		reportAddr The email address to send the report to. This parameter is used internally by the crash reporter and must contain the email address without enclosing brackets (&lt; or &gt;)
 @param     userInfo This is an arbitrary string that will be embedded in the crash report email, as a "User Info:" field.  It's useful if you need to specify additional information in the crash report, e.g. a customer's ID number or registration code if you'd like to contact them.
 @discussion Launch the crash reporter task by calling <a href="Methods.html#//apple_ref/occ/instm/ILCrashReporter/launchReporterForCompany%58reportAddr%58fromAddr%58" target="doc">launchReporterForCompany:reportAddr:fromAddr:</a> with <i>fromAddr</i> set to <i>reportAddr</i>
*/
- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr userInfo:(NSString*)userInfo;

/*!
    @method     launchReporterForCompany:reportAddr:fromAddr:
	 @abstract   Launch the crash reporter task
	 @param		company The name of the company to send the report to. This parameter is used for displaying the company name to the user if the application terminates unexpectedly.
	 @param		reportAddr The email address to send the report to. This parameter is used internally by the crash reporter and must contain the email address without enclosing brackets (&lt; or &gt;)
	 @param		fromAddr The email address to use as the from address. This parameter is used internally by the crash reporter and must contain the email address without enclosing brackets (&lt; or &gt;)
	 @discussion Launch the crash reporter task by calling <a href="Methods.html#//apple_ref/occ/instm/ILCrashReporter/launchReporterForCompany%58reportAddr%58fromAddr%58smtpServer%58smtpPort%58" target="doc">launchReporterForCompany:reportAddr:fromAddr:smtpServer:smtpPort:</a> with <i>smtpServer</i> set to NULL and <i>smtpPort</i> set to 0
*/
- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr fromAddr:(NSString*)fromAddr;

/*!
    @method     launchReporterForCompany:reportAddr:fromAddr:smtpServer:smtpPort:
	 @abstract   Launch the crash reporter task
	 @param		company The name of the company to send the report to. This parameter is used for displaying the company name to the user if the application terminates unexpectedly.
	 @param		reportAddr The email address to send the report to. This parameter is used internally by the crash reporter and must contain the email address without enclosing brackets (&lt; or &gt;)
	 @param		fromAddr The email address to use as the from address. This parameter is used internally by the crash reporter and must contain the email address without enclosing brackets (&lt; or &gt;)
	 @param		smtpServer The smtp server to send the crash report through. If you specify NULL for this parameter the default mail exchanger (MX server) for the recipient will automatically be looked up in the DNS system. Normally you would not need to specify a server.
	 @param		smtpPort The port to use when connecting to the server. This parameter will be ignored if <i>smtpServer</i> is not specified. Specify 0 to use the default smtp port.
	 @discussion This method will launch the crash reporter task in the background. The crash reporter will monitor the execution of the application that launched it and generate a crash report if it should unexpectedly terminate.
	 */
- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr fromAddr:(NSString*)fromAddr smtpServer:(NSString*)smtpServer smtpPort:(int)smtpPort;

/*!
 @method     launchReporterForCompany:reportAddr:fromAddr:smtpServer:smtpPort:
 @abstract   Launch the crash reporter task
 @param		company The name of the company to send the report to. This parameter is used for displaying the company name to the user if the application terminates unexpectedly.
 @param		reportAddr The email address to send the report to. This parameter is used internally by the crash reporter and must contain the email address without enclosing brackets (&lt; or &gt;)
 @param		fromAddr The email address to use as the from address. This parameter is used internally by the crash reporter and must contain the email address without enclosing brackets (&lt; or &gt;)
 @param		smtpServer The smtp server to send the crash report through. If you specify NULL for this parameter the default mail exchanger (MX server) for the recipient will automatically be looked up in the DNS system. Normally you would not need to specify a server.
 @param		smtpPort The port to use when connecting to the server. This parameter will be ignored if <i>smtpServer</i> is not specified. Specify 0 to use the default smtp port.
 @param     userInfo This is an arbitrary string that will be embedded in the crash report email, as a "User Info:" field.  It's useful if you need to specify additional information in the crash report, e.g. a customer's ID number or registration code if you'd like to contact them.
 @discussion This method will launch the crash reporter task in the background. The crash reporter will monitor the execution of the application that launched it and generate a crash report if it should unexpectedly terminate.
 */
- (void)launchReporterForCompany:(NSString*)company reportAddr:(NSString*)reportAddr fromAddr:(NSString*)fromAddr smtpServer:(NSString*)smtpServer smtpPort:(int)smtpPort userInfo:(NSString*)userInfo;

/*!
    @method     terminate
    @abstract   Terminate the crash reported task
    @discussion This method will terminate the crash reporter task. You would normally not need to call this method since the crash reporter will automatically terminate when the host application quits normally.
*/
- (void)terminate;

@end
