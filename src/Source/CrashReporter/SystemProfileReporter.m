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
#import "SystemProfileReporter.h"

//***************************************************************************

@implementation SystemProfileReporter

static void AddUSBDevicesArrayToCrashReport(NSMutableArray* crashReport, NSArray* usbDeviceProfiles)
{
	NSEnumerator* usbDeviceProfilesEnumerator = [usbDeviceProfiles objectEnumerator];
	NSDictionary* usbDeviceProfile = nil;
	while(usbDeviceProfile = [usbDeviceProfilesEnumerator nextObject])
	{
		NSMutableArray* usbDeviceReport = [NSMutableArray array];
		
		[usbDeviceReport addObject:@"USB Device"];
		
		NSString* usbDeviceName = [usbDeviceProfile objectForKey:@"_name"];
		if([usbDeviceName isEqual:@"hub_device"]) [usbDeviceReport addObject:@"Hub"];
		else [usbDeviceReport addObject:usbDeviceName];
		
		NSString* manufacturer = [usbDeviceProfile objectForKey:@"manufacturer"];
		if(manufacturer) [usbDeviceReport addObject:manufacturer];
		else [usbDeviceReport addObject:@""];
		
		NSString* usbDeviceSpeed = [usbDeviceProfile objectForKey:@"device_speed"];
		if([usbDeviceSpeed isEqual:@"high_speed"]) [usbDeviceReport addObject:@"Up to 480 Mb/sec"];
		else if([usbDeviceSpeed isEqual:@"full_speed"]) [usbDeviceReport addObject:@"Up to 12 Mb/sec"];
		else if([usbDeviceSpeed isEqual:@"low_speed"]) [usbDeviceReport addObject:@"Up to 1.5 Mb/sec"];
		else [usbDeviceReport addObject:@""];
		
		NSString* busPowerString = [usbDeviceProfile objectForKey:@"bus_power"];
		if(busPowerString) [usbDeviceReport addObject:[NSString stringWithFormat:@"%@ mA", busPowerString]];
		else [usbDeviceReport addObject:@""];
		
		[crashReport addObject:usbDeviceReport];
		
		if([usbDeviceProfile objectForKey:@"_items"]) AddUSBDevicesArrayToCrashReport(crashReport, [usbDeviceProfile objectForKey:@"_items"]);
	}
}

static NSString* TemporaryFilename()
{
	return [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
}

static NSArray* SystemProfilePropertyList()
{
	NSString* temporaryFilename = [TemporaryFilename() stringByAppendingPathExtension:@"plist"];
	if(temporaryFilename == nil) return nil;
	
	const BOOL createdTemporaryFileSuccessfully = [[NSFileManager defaultManager] createFileAtPath:temporaryFilename contents:[NSData data] attributes:nil];
	if(!createdTemporaryFileSuccessfully) return nil;
	
	NSFileHandle* temporaryFileHandle = [NSFileHandle fileHandleForWritingAtPath:temporaryFilename];
	if(temporaryFileHandle == nil) return nil;
	
	NSArray* systemProfilerArguments = [@"-xml -detailLevel basic SPHardwareDataType SPDisplaysDataType SPMemoryDataType SPAirPortDataType SPBluetoothDataType SPNetworkDataType SPSerialATADataType SPParallelATADataType SPUSBDataType" componentsSeparatedByString:@" "];
	
	NSTask* systemProfilerTask = [[[NSTask alloc] init] autorelease];
	[systemProfilerTask setLaunchPath:@"/usr/sbin/system_profiler"];
	[systemProfilerTask setArguments:systemProfilerArguments];
	[systemProfilerTask setStandardOutput:temporaryFileHandle];
	[systemProfilerTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	[systemProfilerTask launch];
	[systemProfilerTask waitUntilExit];
	[temporaryFileHandle closeFile];
	
	return [NSArray arrayWithContentsOfFile:temporaryFilename];
}

//---------------------------------------------------------------------------

+ (NSData*)systemProfileReport
{
	NS_DURING
	{
		NSArray* systemProfileArray = SystemProfilePropertyList();
		if(systemProfileArray == nil) NS_VALUERETURN(nil, NSData*);
		
		// Transform the array of items to a dictionary, for easier manipulation
		NSMutableDictionary* systemProfileDictionary = [NSMutableDictionary dictionary];
		{
			NSEnumerator* systemProfileArrayEnumerator = [systemProfileArray objectEnumerator];
			NSDictionary* profile = nil;
			while(profile = [systemProfileArrayEnumerator nextObject])
			{
				[systemProfileDictionary setObject:profile forKey:[profile objectForKey:@"_dataType"]];
			}
		}
		
		NSMutableArray* crashReport = [NSMutableArray array];
		
		NSDictionary* hardwareProfile = [systemProfileDictionary objectForKey:@"SPHardwareDataType"];
		if(hardwareProfile)
		{
			NSMutableArray* hardwareReport = [NSMutableArray array];
			[hardwareReport addObject:@"Model"];
			[hardwareReport addObject:[hardwareProfile objectForPath:@"_items.0.machine_model"]];
			[hardwareReport addObject:[NSString stringWithFormat:@"BootROM %@", [hardwareProfile objectForPath:@"_items.0.boot_rom_version"]]];
			[hardwareReport addObject:[NSString stringWithFormat:@"%@ processors", [hardwareProfile objectForPath:@"_items.0.number_processors"]]];
			[hardwareReport addObject:[hardwareProfile objectForPath:@"_items.0.cpu_type"]];
			[hardwareReport addObject:[hardwareProfile objectForPath:@"_items.0.current_processor_speed"]];
			[hardwareReport addObject:[hardwareProfile objectForPath:@"_items.0.physical_memory"]];
			
			[crashReport addObject:hardwareReport];
		}
		
		NSDictionary* displaysProfile = [systemProfileDictionary objectForKey:@"SPDisplaysDataType"];
		if(displaysProfile)
		{
			NSMutableArray* displaysReport = [NSMutableArray array];
			[displaysReport addObject:@"Graphics"];
			
			NSString* graphicsAdapterName = [displaysProfile objectForPath:@"_items.0._name"];
			if([graphicsAdapterName isEqual:@"kHW_IntelGMA950Item"]) [displaysReport addObject:@"Intel GMA 950"];
			else [displaysReport addObject:graphicsAdapterName];
			
			[displaysReport addObject:[displaysProfile objectForPath:@"_items.0.sppci_model"]];
			
			NSString* bus = [displaysProfile objectForPath:@"_items.0.sppci_bus"];
			if([bus isEqual:@"spdisplays_builtin"]) [displaysReport addObject:@"Built-In"];
			else [displaysReport addObject:bus];
			
			[displaysReport addObject:[displaysProfile objectForPath:@"_items.0.spdisplays_vram"]];
			
			[crashReport addObject:displaysReport];
		}
		
		NSDictionary* memoryModulesProfile = [systemProfileDictionary objectForKey:@"SPMemoryDataType"];
		if(memoryModulesProfile)
		{
			NSEnumerator* memoryModulesEnumerator = [[memoryModulesProfile objectForKey:@"_items"] objectEnumerator];
			NSDictionary* memoryModuleProfile = nil;
			while(memoryModuleProfile = [memoryModulesEnumerator nextObject])
			{
				NSMutableArray* memoryModuleReport = [NSMutableArray array];
				
				[memoryModuleReport addObject:@"Memory Module"];
				[memoryModuleReport addObject:[memoryModuleProfile objectForKey:@"_name"]];
				[memoryModuleReport addObject:[memoryModuleProfile objectForKey:@"dimm_size"]];
				[memoryModuleReport addObject:[memoryModuleProfile objectForKey:@"dimm_type"]];
				[memoryModuleReport addObject:[memoryModuleProfile objectForKey:@"dimm_speed"]];
				
				[crashReport addObject:memoryModuleReport];
			}
		}
		
		NSDictionary* airPortProfile = [systemProfileDictionary objectForKey:@"SPAirPortDataType"];
		if(airPortProfile)
		{
			NSMutableArray* airportReport = [NSMutableArray array];
			
			[airportReport addObject:@"AirPort"];
			[airportReport addObject:[airPortProfile objectForPath:@"_items.0.spairport_wireless_card_type"]];
			[airportReport addObject:[airPortProfile objectForPath:@"_items.0.spairport_wireless_firmware_version"]];
			
			[crashReport addObject:airportReport];
		}
		
		NSDictionary* bluetoothProfile = [systemProfileDictionary objectForKey:@"SPBluetoothDataType"];
		if(bluetoothProfile)
		{
			NSMutableArray* bluetoothReport = [NSMutableArray array];
			
			[bluetoothReport addObject:@"Bluetooth"];
			[bluetoothReport addObject:[NSString stringWithFormat:@"Version %@", [bluetoothProfile objectForPath:@"_items.0.apple_bluetooth_version"]]];
			
			NSArray* bluetoothServices = [bluetoothProfile objectForPath:@"_items.0.services_title"];
			if([bluetoothServices count] > 0) [bluetoothReport addObject:[NSString stringWithFormat:@"%u service", [bluetoothServices count]]];
			
			NSArray* localBluetoothDevices = [bluetoothProfile objectForPath:@"_items.0.local_device_title"];
			if([localBluetoothDevices count] > 0) [bluetoothReport addObject:[NSString stringWithFormat:@"%u devices", [localBluetoothDevices count]]];
			
			NSArray* bluetoothIncomingSerialPorts = [bluetoothProfile objectForPath:@"_items.0.incoming_serial_ports_title"];
			if([bluetoothIncomingSerialPorts count] > 0) [bluetoothReport addObject:[NSString stringWithFormat:@"%u incoming serial ports", [bluetoothIncomingSerialPorts count]]];
			
			[crashReport addObject:bluetoothReport];
		}
		
		NSDictionary* networkProfile = [systemProfileDictionary objectForKey:@"SPNetworkDataType"];
		if(networkProfile)
		{
			NSEnumerator* networkItemsEnumerator = [[networkProfile objectForKey:@"_items"] objectEnumerator];
			
			NSDictionary* networkItem = nil;
			while(networkItem = [networkItemsEnumerator nextObject])
			{
				if([[networkItem objectForKey:@"ip_assigned"] isEqual:@"yes"])
				{
					NSMutableArray* networkReport = [NSMutableArray array];
					
					[networkReport addObject:@"Network Service"];
					[networkReport addObject:[networkItem objectForKey:@"_name"]];
					[networkReport addObject:[networkItem objectForKey:@"hardware"]];
					[networkReport addObject:[networkItem objectForKey:@"interface"]];
					
					[crashReport addObject:networkReport];
				}
			}
		}
		
		NSDictionary* serialATAProfile = [systemProfileDictionary objectForKey:@"SPSerialATADataType"];
		if(serialATAProfile)
		{
			NSArray* serialATADevices = [serialATAProfile objectForPath:@"_items.0._items"];
			
			NSEnumerator* e = [serialATADevices objectEnumerator];
			NSDictionary* serialATADeviceProfile = nil;
			while(serialATADeviceProfile = [e nextObject])
			{
				NSMutableArray* serialATADeviceReport = [NSMutableArray array];
				
				[serialATADeviceReport addObject:@"Serial ATA Device"];
				[serialATADeviceReport addObject:[serialATADeviceProfile objectForKey:@"_name"]];
				
				NSString* sizeString = [serialATADeviceProfile objectForKey:@"size"];
				[serialATADeviceReport addObject:(sizeString ? sizeString : @"")];
				
				[crashReport addObject:serialATADeviceReport];
			}
		}
		
		NSDictionary* parallelATAProfile = [systemProfileDictionary objectForKey:@"SPParallelATADataType"];
		if(parallelATAProfile)
		{
			NSArray* parallelATADevices = [parallelATAProfile objectForPath:@"_items.0._items"];
			
			NSEnumerator* e = [parallelATADevices objectEnumerator];
			NSDictionary* parallelATADeviceProfile = nil;
			while(parallelATADeviceProfile = [e nextObject])
			{
				NSMutableArray* parallelATADeviceReport = [NSMutableArray array];
				
				[parallelATADeviceReport addObject:@"Parallel ATA Device"];
				[parallelATADeviceReport addObject:[parallelATADeviceProfile objectForKey:@"_name"]];
				
				NSString* sizeString = [parallelATADeviceProfile objectForKey:@"size"];
				[parallelATADeviceReport addObject:(sizeString ? sizeString : @"")];
				
				[crashReport addObject:parallelATADeviceReport];
			}
		}
		
		NSDictionary* usbProfile = [systemProfileDictionary objectForKey:@"SPUSBDataType"];
		if(usbProfile)
		{
			NSEnumerator* rootUSBDevicesEnumerator = [[usbProfile objectForKey:@"_items"] objectEnumerator];
			NSDictionary* rootUSBDevice = nil;
			while(rootUSBDevice = [rootUSBDevicesEnumerator nextObject]) AddUSBDevicesArrayToCrashReport(crashReport, [rootUSBDevice objectForKey:@"_items"]);
		}
		
		NS_VALUERETURN([NSPropertyListSerialization dataFromPropertyList:crashReport format:NSPropertyListXMLFormat_v1_0 errorDescription:nil], NSData*);
	}
	NS_HANDLER
	{
		NSLog(@"warning: couldn't generate system profile: %@", localException);
		
		return nil;
	}
	NS_ENDHANDLER
}

@end

//***************************************************************************
