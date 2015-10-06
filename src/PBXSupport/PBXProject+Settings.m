/*
   mulle-xcode-settings
   
   $Id: PBXProject+Settings.m,v 255094b1c447 2011/12/21 15:37:37 nat $

   Created by Nat! on 26.12.10.
   Copyright 2010 Mulle kybernetiK
   
   This file is part of mulle-xcode-settings.

   mulle-xcode-settings is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   mulle-xcode-settings is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with mulle-xcode-settings.  If not, see <http://www.gnu.org/licenses/>.
*/
#import "PBXProject+Settings.h"

#import "PBXPathObject+HierarchyAndPaths.h"
#import "PBXFileReference+MakefileDependency.h"
#import "NSArray+MulleFirstObject.h"
#import "NSDictionary+CommonAndDifferences.h"
#import "NSDictionary+Settings.h"
#import "NSString+XcconfigSettings.h"
#import "Xcode.h"
#import "XcodeGCCPlugin.h"


#define DUMP_DEFAULT_SETTINGS  0


@implementation XCBuildConfiguration( Settings)

- (NSDictionary *) settings
{
   PBXFileReference      *base;
   NSMutableDictionary   *settings;
   
   settings = [NSMutableDictionary dictionary];

   base = [self baseConfigurationReference];
   if( base)
      [settings addSettings:[base settings]];

   [settings addSettings:[self buildSettings]];
   return( settings);
}

@end


@implementation XCConfigurationList( Settings)

- (XCBuildConfiguration *) configurationNamed:(NSString *) name
{
   NSEnumerator           *rover;
   XCBuildConfiguration   *configuration;
   
   rover = [[self buildConfigurations] objectEnumerator];
   while( configuration = [rover nextObject])
      if( [[configuration name] isEqualToString:name])
         break;
   return( configuration);
}

@end


@implementation PBXObjectWithConfigurationList( Settings)

- (NSDictionary *) buildSettings
{
   return( nil);
}


- (XCBuildConfiguration *) configurationNamed:(NSString *) name
{
   return( [[self buildConfigurationList] configurationNamed:name]);
}


- (NSDictionary *) settingsForConfigurationNamed:(NSString *) name
{
   XCBuildConfiguration  *configuration;

   configuration = [self configurationNamed:name];
   return( [configuration settings]);
}

@end


@implementation PBXTarget( Settings)

- (NSDictionary *) defaultBuildSettings
{
   NSMutableDictionary   *settings;
   Xcode                 *xcode;
   NSString              *type;
   
   xcode = [Xcode sharedInstance];
   type  = [self productType];
      
   settings = [NSMutableDictionary dictionary];
   [settings addSettings:[xcode settingsForBuildType:@"com.apple.build-system.core"]];

   if( type)
      [settings addSettings:[xcode settingsForProductType:type]];
      
   // ok not "really build settings" but there is no $(inherited) in those above
   return( settings);
}


- (NSDictionary *) buildSettingsForConfigurationNamed:(NSString *) name
{
   XCBuildConfiguration   *configuration;
   
   configuration = [self configurationNamed:name];
   return( [configuration buildSettings]);
}


- (NSDictionary *) commonBuildSettingsOfAllConfigurations
{
   XCBuildConfiguration   *configuration;
   NSEnumerator           *rover;
   NSDictionary           *settings;
   NSDictionary           *common;
   
   common = nil;

   rover = [[self buildConfigurations] objectEnumerator];
   while( configuration = [rover nextObject])
   {
      settings = [configuration buildSettings];
      common   = [settings commonSettings:common];
   }

   return( common);
}

- (id) buildPhaseOfClass:(Class) aClass
{
   PBXBuildPhase   *phase;
   NSEnumerator    *rover;
   
   rover = [[self buildPhases] reverseObjectEnumerator];
   while( phase = [rover nextObject])
      if( [phase isKindOfClass:aClass])
         break;
   return( phase);
}


@end


@implementation PBXNativeTarget( Settings)

- (NSDictionary *) buildSettings
{
   NSMutableDictionary   *settings;
   Xcode                 *xcode;
   
   xcode = [Xcode sharedInstance];

   settings = [NSMutableDictionary dictionary];
   [settings addSettings:[xcode settingsForBuildType:@"com.apple.build-system.native"]];
   [settings addSettings:[xcode settingsForProductType:[self productType]]];
   
   // ok not "really build settings" but there is no $(inherited) in those above
   return( settings);
}

@end


@implementation PBXProject( Settings)

- (NSDictionary *) buildSettings
{
   return( [[Xcode sharedInstance] defaultSettings]);
}

@end
