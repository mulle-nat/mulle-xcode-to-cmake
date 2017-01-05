/*
 mulle-xcode-settings
 
 $Id: utility-main.m,v 71cb8aaa9ef7 2011/12/21 14:00:39 nat $
 
 Created by Nat! on 06.10.15
 Copyright 2015 Mulle kybernetiK
 
 This file is part of mulle-xcode-settings
 
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
#import <Foundation/Foundation.h>

#import "MullePBXArchiver.h"
#import "MullePBXUnarchiver.h"
#import "PBXObject.h"

static BOOL   verbose;

static void   usage()
{
   fprintf( stderr,
           "usage: mulle-xcode-settings [options] <commands> <file.xcodeproj>\n"
           "\n"
           "Options:\n"
           ""
           "\t-c <configuration>          : configuration to set\n"
           "\t-t <target>                 : target to set\n"
           "\t-a                          : set on all targets\n"
           "\n"
           "Commands:\n"
           "\tlist                        : list all keys\n"
           "\tget     <key>               : get value for key\n"
           "\tset     <key> <value>       : sets key to value\n"
           "\tadd     <key> <value>       : adds value to key\n"
           "\tinsert  <key> <value>       : inserts value in front of key\n"
           "\tremove  <key> <value>       : removes value from key\n"
           "\treplace <key> <old> <value> : replace old value for key (if exists)\n"
           "\n"
           "Environment:\n"
           "\tVERBOSE                     : dump some info to stderr\n"
         );
   
   exit( 1);
}


static PBXTarget   *find_target_by_name( PBXProject *root, NSString *name)
{
   NSEnumerator   *rover;
   PBXTarget      *pbxtarget;
   
   rover = [[root targets] objectEnumerator];
   while( pbxtarget = [rover nextObject])
      if( [[pbxtarget name] isEqualToString:name])
         break;
   
   return( pbxtarget);
}


static void   list_target_names( PBXProject *root)
{
   NSEnumerator   *rover;
   PBXTarget      *pbxtarget;
   
   printf( "Targets:\n");
   rover = [[root targets] objectEnumerator];
   while( pbxtarget = [rover nextObject])
      printf( "\t%s\n", [[pbxtarget name] UTF8String]);
}


static XCBuildConfiguration  *find_configuration_by_name( PBXObjectWithConfigurationList *root, NSString *name)
{
   NSEnumerator            *rover;
   XCBuildConfiguration    *pbxconfiguration;
   
   rover = [[root buildConfigurations] objectEnumerator];
   while( pbxconfiguration = [rover nextObject])
      if( [[pbxconfiguration name] isEqualToString:name])
         break;
   
   return( pbxconfiguration);
}


enum Command
{
   Add,
   Get,
   Insert,
   List,
   Remove,
   Replace,
   Set
};


static void  fail( NSString *format, ...)
{
   va_list   args;
   
   va_start( args, format);
   NSLogv( format, args);
   va_end( args);
   
   exit( 1);
}


static void   hackit_array( XCBuildConfiguration *xcconfiguration, enum Command cmd, NSString *key, id value, id old, NSMutableDictionary *settings, id prevValue)
{
   NSEnumerator  *rover;
   NSString      *s;
   NSUInteger    index;
   
   NSCParameterAssert( [prevValue isKindOfClass:[NSArray class]]);

   if( cmd != Set)
      prevValue = [[prevValue mutableCopy] autorelease];
   
   switch( cmd)
   {
   case Get:
      printf( "%s\n", prevValue ? [[prevValue description] UTF8String] : "<null>");
      return;
         
   case Add    :
      if( [prevValue containsObject:value])
      {
         if( verbose)
            fprintf( stderr, "value is already present\n");
         return;
      }

      if( verbose)
         fprintf( stderr, "adding %s to %s for key %s\n",
               [[value description] UTF8String],
               [[prevValue description] UTF8String],
               [key UTF8String]);

      [prevValue addObject:value];
      value = prevValue;
      break;

   case Insert :
      if( [prevValue containsObject:value])
      {
         if( verbose)
            fprintf( stderr, "value is already present\n");
         return;
      }

      if( verbose)
         fprintf( stderr, "insert %s into %s for key %s\n",
               [[value description] UTF8String],
               [[prevValue description] UTF8String],
               [key UTF8String]);

      [prevValue insertObject:value
                      atIndex:0];
      value = prevValue;
      break;

   case Set:
      value = [NSArray arrayWithObject:value];
      if( verbose)
         fprintf( stderr, "set %s for key %s\n",
               [[value description] UTF8String],
               [key UTF8String]);
      break;

   case Replace :
      index = [prevValue indexOfObject:old];
      if( index == NSNotFound)
      {
         if( verbose)
            fprintf( stderr, "old value is not present\n");
         return;
      }
   
      if( verbose)
         fprintf( stderr, "replace %s with %s from %s for key %s\n",
               [[old description] UTF8String],
               [[value description] UTF8String],
               [[prevValue description] UTF8String],
               [key UTF8String]);
         
      [prevValue replaceObjectAtIndex:index
                           withObject:value];
      value = prevValue;
      break;
         
   case Remove :
      if( ! [prevValue containsObject:value])
      {
         if( verbose)
            fprintf( stderr, "value is not present\n");
         return;
      }

      if( verbose)
         fprintf( stderr, "remove %s from %s for key %s\n",
               [[value description] UTF8String],
               [[prevValue description] UTF8String],
               [key UTF8String]);
   
      [prevValue removeObject:value];
      value = prevValue;
      break;
   }

   if( [value count])
      [settings setObject:value
                   forKey:key];
   else
      [settings removeObjectForKey:key];
   
   [xcconfiguration setObject:settings
                       forKey:@"buildSettings"];
}


static void   hackit_string( XCBuildConfiguration *xcconfiguration, enum Command cmd,  NSString *key, id value, id old, NSMutableDictionary *settings, NSString *prevValue)
{
   NSRange   range;
   NSRange   range2;
   NSArray   *array;
   
   if( ! [prevValue length])
      prevValue = nil;

   if( ! [value length])
   {
      value = nil;
      range = NSMakeRange( 0, 0);
   }
   else
      range = [prevValue rangeOfString:value];
   
   switch( cmd)
   {
   case Get:
      printf( "%s\n", prevValue ? [[prevValue description] UTF8String] : "<null>");
      return;

   case Add :
      if( prevValue)
      {
         if( range.length == [prevValue length])  // or what ?
         {
            if( verbose)
               fprintf( stderr, "value already set\n");
            return;
         }

         if( verbose)
            fprintf( stderr, "add %s after %s for key %s\n",
                  [[value description] UTF8String],
                  [[prevValue description] UTF8String],
                  [key UTF8String]);
      
         if( value)
         {
            value = [NSArray arrayWithObjects:prevValue, value, nil];
            if( verbose)
               fprintf( stderr, "promoting to array\n");
         }
         break;
      }
      if( verbose)
         fprintf( stderr, "set %s for key %s\n",
                  [[value description] UTF8String],
                  [key UTF8String]);
      break;
         
   case Insert  :
      if( prevValue)
      {
         if( range.length == [prevValue length])  // or what ?
         {
            if( verbose)
               fprintf( stderr, "value already set\n");
            return;
         }
      
         if( verbose)
            fprintf( stderr, "insert %s before %s for key %s\n",
                  [[value description] UTF8String],
                  [[prevValue description] UTF8String],
                  [key UTF8String]);
         if( value)
         {
            value = [NSArray arrayWithObjects:value, prevValue, nil];
            if( verbose)
               fprintf( stderr, "promoting to array\n");
         }
         break;
      }
      // fall thru
   case Set:
      if( verbose)
         fprintf( stderr, "set %s for key %s\n",
                  [[value description] UTF8String],
                  [key UTF8String]);
      break;

   case Replace :
      if( ! prevValue)
      {
         if( verbose)
            fprintf( stderr, "nothing to replace\n");
         return;
      }

      range = [prevValue rangeOfString:old];
      if( range.length != [prevValue length])
      {
         if( verbose)
            fprintf( stderr, "old value doesnt match\n");
         return;
      }

      if( verbose)
         fprintf( stderr, "replace %s with %s for key %s\n",
               [[old description] UTF8String],
               [[value description] UTF8String],
               [key UTF8String]);
      break;
      
   case Remove :
      if( range.length != [prevValue length])
      {
         if( verbose)
            fprintf( stderr, "value doesnt match\n");
         return;
      }
      
      if( verbose)
         fprintf( stderr, "remove %s for key %s\n",
               [[value description] UTF8String],
               [key UTF8String]);

      value = nil;
      break;
   }

   if( value)
      [settings setObject:value
                   forKey:key];
   else
      [settings removeObjectForKey:key];
   
   [xcconfiguration setObject:settings
                       forKey:@"buildSettings"];
}


static void   hackit( XCBuildConfiguration *xcconfiguration, enum Command cmd, NSString *key, NSString *value, NSString *old)
{
   id             settings;
   id             prevValue;
   NSEnumerator   *rover;
   
   if( verbose)
      fprintf( stderr, "%s\n", [[xcconfiguration name] UTF8String]);

   settings = [xcconfiguration buildSettings];
   if( cmd == List)
   {
      rover = [[[settings allKeys] sortedArrayUsingSelector:@selector( caseInsensitiveCompare:)] objectEnumerator];

      printf( "\t%s:\n", [[xcconfiguration name] UTF8String]);
      while( key = [rover nextObject])
      {
         prevValue = [settings objectForKey:key];
         printf( "\t\t%s=\"%s\"\n",
                  [key UTF8String],
                  [[prevValue description] UTF8String]);
      }
      return;
   }

   prevValue = [settings objectForKey:key];
   if( verbose)
      fprintf( stderr, "old: %s = %s\n",
          [key UTF8String], [[prevValue description] UTF8String]);
   
   settings = [[settings mutableCopy] autorelease];
   if( [prevValue isKindOfClass:[NSArray class]])
   {
      hackit_array( xcconfiguration, cmd, key, value, old, settings, prevValue);
      return;
   }
   hackit_string( xcconfiguration, cmd, key, value, old, settings, prevValue);
}


static void   _setting_hack( PBXObjectWithConfigurationList *obj,
                             enum Command cmd,
                             NSString *key,
                             NSString *value,
                             NSString *old,
                             NSString *configuration)
{
   PBXTarget              *pbxtarget;
   XCBuildConfiguration   *xcconfiguration;
   NSEnumerator           *rover;

   if( verbose)
      fprintf( stderr, "object: %s\n", [[obj name] UTF8String]);
   
   if( cmd == List)
      printf( "%s:\n", [[obj name] UTF8String]);
   
   if( configuration)
   {
      xcconfiguration = find_configuration_by_name( obj, configuration);
      if( ! xcconfiguration)
         fail( @"configuration \"%@\" not found", configuration);

      hackit( xcconfiguration, cmd, key, value, old);
      return;
   }

   rover = [[obj buildConfigurations] objectEnumerator];
   while( xcconfiguration = [rover nextObject])
      hackit( xcconfiguration, cmd, key, value, old);
}


static void   setting_hack( PBXProject *root,
                            enum Command cmd,
                            NSString *key,
                            NSString *value,
                            NSString *old,
                            NSString *configuration,
                            NSString *target)
{
   PBXTarget                        *pbxtarget;
   XCBuildConfiguration             *xcconfiguration;
   PBXObjectWithConfigurationList   *obj;
   NSEnumerator                     *rover;

   obj = root;

   if( target)
   {
      if( [target isEqualToString:@"##ALL##"])
      {
         rover = [[root targets] objectEnumerator];
         while( pbxtarget = [rover nextObject])
            _setting_hack( pbxtarget, cmd, key, value, old, configuration);
         return;
      }
      
      pbxtarget = find_target_by_name( root, target);
      if( ! pbxtarget)
         fail( @"target \"%@\" not found", target);
      obj = pbxtarget;
   }
   else
   {
      if( cmd == List)
         list_target_names( root);
   }

   _setting_hack( obj, cmd, key, value, old, configuration);
}


static NSString  *backupPathForPath( NSString *file)
{
   NSString  *ext;
   NSString  *dir;
   NSString  *name;
   
   dir  = [file stringByDeletingLastPathComponent];
   name = [file lastPathComponent];
   ext  = [name pathExtension];
   name = [name stringByDeletingPathExtension];
   name = [name stringByAppendingString:@"~"];
   name = [name stringByAppendingPathExtension:ext];
   file = [dir stringByAppendingPathComponent:name];
   return( file);
}


static void   writeStringToPath( NSString *s, NSString *file)
{
   NSString        *backupFile;
   NSFileManager   *manager;
   NSError         *error;
   
   backupFile = backupPathForPath( file);
   manager    = [NSFileManager defaultManager];
   
   [manager removeItemAtPath:backupFile
                       error:&error];
   if( ! [manager moveItemAtPath:file
                          toPath:backupFile
                           error:&error])
      fail( @"failed to backup %@", file);

   if( ! [s writeToFile:file
             atomically:YES
               encoding:NSUTF8StringEncoding
                  error:&error])
      fail( @"failed to write %@: %@", [error localizedFailureReason]);
}


static int   _main( int argc, const char * argv[])
{
   NSArray         *arguments;
   NSDictionary    *plist;
   NSString        *backupFile;
   NSString        *configuration;
   NSString        *file;
   NSString        *key;
   NSString        *old;
   NSString        *s;
   NSString        *target;
   NSString        *value;
   id              root;
   unsigned int    i, n;
   BOOL            allTargets;
   
   configuration = nil;
   target        = nil;
   allTargets    = NO;
   verbose       = getenv( "VERBOSE") ? YES : NO;
   
   arguments = [[NSProcessInfo processInfo] arguments];
   n         = [arguments count];
   
   if( [arguments containsObject:@"-v"] || [arguments containsObject:@"--version"] || [arguments containsObject:@"-version"])
   {
      fprintf( stderr, "v%s\n", CURRENT_PROJECT_VERSION);
      return( 0);
   }

   if( [arguments containsObject:@"-h"] || [arguments containsObject:@"--help"] || [arguments containsObject:@"-help"])
      usage();
   
   file = [arguments lastObject];
   if( ! --n)
      usage();
   
   if( [[file pathExtension] isEqualToString:@"xcodeproj"])
      file = [file stringByAppendingPathComponent:@"project.pbxproj"];
   
   root = [MullePBXUnarchiver unarchiveObjectWithFile:&file];
   if( ! root)
      fail( @"File %@ is not a PBX (Xcode) file", file);
   
   for( i = 1; i < n; i++)
   {
      s = [arguments objectAtIndex:i];
      
      // options
      if(  [s isEqualToString:@"-c"] ||
           [s isEqualToString:@"-configuration"] ||
           [s isEqualToString:@"--configuration"])
      {
         if( ++i >= n)
            usage();
         
         configuration = [arguments objectAtIndex:i];
         continue;
      }

      if( [s isEqualToString:@"-t"] ||
          [s isEqualToString:@"-target"] ||
          [s isEqualToString:@"--target"])
      {
         if( ++i >= n)
            usage();
         
         target = [arguments objectAtIndex:i];
         continue;
      }
      
      if( [s isEqualToString:@"-a"] ||
          [s isEqualToString:@"-alltargets"] ||
          [s isEqualToString:@"--alltargets"])
      {
         target = @"##ALL##";
         continue;
      }

      // commands
      if( [s isEqualToString:@"list"])
      {
         setting_hack( root, List, nil, nil, nil, configuration, target);
         continue;
      }

      if( ++i >= n)
         usage();
      
      key = [arguments objectAtIndex:i];

      if( [s isEqualToString:@"get"])
      {
         setting_hack( root, Get, key, nil, nil, configuration, target);
         continue;
      }

      if( ++i >= n)
         usage();
      value = [arguments objectAtIndex:i];

      if( [s isEqualToString:@"set"])
      {
         setting_hack( root, Set, key, value, nil, configuration, target);
         continue;
      }
      
      if( [s isEqualToString:@"add"])
      {
         setting_hack( root, Add, key, value, nil, configuration, target);
         continue;
      }

      if( [s isEqualToString:@"insert"])
      {
         setting_hack( root, Insert, key, value, nil, configuration, target);
         continue;
      }

      if( [s isEqualToString:@"remove"])
      {
         setting_hack( root, Remove, key, value, nil, configuration, target);
         continue;
      }
      
      if( ++i >= n)
         usage();
      old   = value;
      value = [arguments objectAtIndex:i];

      if( [s isEqualToString:@"replace"])
      {
         setting_hack( root, Replace, key, value, old, configuration, target);
         continue;
      }
      
      NSLog( @"unknown command %@", s);
      usage();
   }
   
   plist = [MullePBXArchiver archivedPropertyListWithRootObject:root];
   s     = [NSString stringWithFormat:@"// !$*UTF8*$!\n%@", [plist description]];

   writeStringToPath( s, file);
   
   return( 0);
}


int   main( int argc, const char * argv[])
{
   NSAutoreleasePool   *pool;
   int                 rval;
   
   pool = [NSAutoreleasePool new];
   rval = _main( argc, argv);
   [pool release];
   return( rval);
}
