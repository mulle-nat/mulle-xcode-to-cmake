/*
   mulle-xcode-to-cmake
   
   $Id: MullePBXUnarchiver.m,v 888dcac8ab3c 2011/10/11 08:32:04 nat $

   Created by Nat! on 26.12.10.
   Copyright 2010 Mulle kybernetiK
   
   This file is part of mulle-xcode-to-cmake.

   mulle-xcode-to-cmake is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   mulle-xcode-to-cmake is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with mulle-xcode-to-cmake.  If not, see <http://www.gnu.org/licenses/>.
*/
#import "MullePBXUnarchiver.h"

#import "NSObject+DecodeWithObjectStorage.h"
#import "PBXObject.h"
#import "PBXProjectProxy.h"
#import <Foundation/NSDebug.h>
#include <objc/runtime.h>


@implementation MullePBXUnarchiver

static NSDictionary   *_openDictionary( NSString *path, NSPropertyListFormat *format, NSError **error)
{
   NSData   *data;

   *error = nil;
   data = [NSData dataWithContentsOfFile:path
#ifdef __APPLE__
                                 options:0
                                   error:error
#endif
                                              ];
   if( ! data)
      return( nil);
   
   return( [NSPropertyListSerialization propertyListWithData:data
                                                     options:0
                                                      format:format
                                                       error:error]);
}


static NSDictionary   *openDictionary( NSString **path, NSPropertyListFormat *format, NSError **error)
{
   NSDictionary   *dict;
   NSString       *subpath;
   
   dict = _openDictionary( *path, format, error);
   if( dict || [*path hasSuffix:@"pbxproj"])
      return( dict);
   
   subpath = [*path stringByAppendingPathComponent:@"project.pbxproj"];
   dict = _openDictionary( *path, format, error);
   if( dict)
      *path = subpath;
   return( dict);
}


- (int) archiveVersion
{
   return( archiveVersion_);
}


- (int) objectVersion
{
   return( objectVersion_);
}


- (Class) dynamicallySubclassPBXObject:(NSString *) name
                                 class:(Class) superClass
{
   Class   subclass;
   
   subclass = objc_allocateClassPair( superClass, [name UTF8String], 0);
   if( ! subclass)
      [NSException raise:NSInternalInconsistencyException
                  format:@"Couldn't create class for %@", name];
   
   objc_registerClassPair( subclass);
#if !defined(DEBUG) && defined(__APPLE__)
   if( NSDebugEnabled)
#endif
      NSLog( @"dynamically created %@ class", name);
   return( subclass);
}


//
// list all isa types
// grep 'isa ='  X.xcodeproj/project.pbxproj | sed 's/.*isa = \([A-Za-z0-9_]*\);.*/\1/g' | sort | sort -u
//
- (void) createObjectStorageWithDictionary:(NSDictionary *) dictionary
{
   NSDictionary          *info;
   NSEnumerator          *rover;
   NSString              *key;
   NSString              *className;
   Class                 aClass;
   Class                 superClass;
   id                    obj;
   
   objectStorage_ = [NSMutableDictionary new];
   reverseLookup_ = NSCreateMapTable( NSNonOwnedPointerMapKeyCallBacks,
                                      NSObjectMapValueCallBacks, 
                                      128);
   //
   // first create all objects
   //
   rover = [dictionary keyEnumerator];
   while( key = [rover nextObject])
   {
      info      = [dictionary objectForKey:key];
      className = [info objectForKey:@"isa"];
      aClass    = NSClassFromString( className);
      
      // just ignore stuff, that has no PBX prefix
      if( ! [className hasPrefix:@"PBX"] && ! [className hasPrefix:@"XC"])
      {
         [NSException raise:NSInvalidArgumentException
                     format:@"Unknown prefix on isa %@. Is this an Xcode project ?", className];
      }

      if( ! aClass)
      {
         superClass = [PBXObject class];
         if( [className hasSuffix:@"BuildPhase"])
            superClass = [PBXBuildPhase class];
         else
            if( [className hasSuffix:@"Target"])
               superClass = [PBXTarget class];
         
         aClass = [self dynamicallySubclassPBXObject:className
                                               class:superClass];
      }
      
      obj = [aClass alloc];   // assume based on NSObject, so it's OK
      [obj setCodecKey:key];
      [objectStorage_ setObject:obj
                         forKey:key];
      [obj release];
      
      NSMapInsert( reverseLookup_, obj, key);
   }
}


- (id) initWithDictionary:(NSDictionary *) dictionary
{
   NSDictionary     *infos;
   NSEnumerator     *rover;
   NSString         *key;
   id               obj;
   PBXProjectProxy  *proxy;
   
   NSParameterAssert( [dictionary isKindOfClass:[NSDictionary class]]);

   [self init];
   
   archiveVersion_ = [[dictionary objectForKey:@"archiveVersion"] intValue];
   if( archiveVersion_ > 1)
      NSLog( @"later archive version format");
   objectVersion_ = [[dictionary objectForKey:@"objectVersion"] intValue];
   if( archiveVersion_ > 42)
      NSLog( @"later object version format");

   proxy = [[PBXProjectProxy alloc] init];  // leaks (but so what)
   
   infos = [dictionary objectForKey:@"objects"];
   [self createObjectStorageWithDictionary:infos];
   infoStorage_ = [[infos decodeWithObjectStorage:objectStorage_] retain];
   
   rover = [objectStorage_ keyEnumerator];
   while( key = [rover nextObject])
   {
      obj = [objectStorage_ objectForKey:key];
      [obj initWithPBXUnarchiver:self
                          project:(PBXProject *) proxy];
   }

   rootKey_ = [[dictionary objectForKey:@"rootObject"] retain];
   obj      = [objectStorage_ objectForKey:rootKey_];
   [proxy setProject:obj];
   
   return( self);
}


- (id) decodeRootObject
{
   id   root;
   
   root = [objectStorage_ objectForKey:rootKey_];
   return( root);
}


- (NSDictionary *) infoForObject:(id) obj
{
   NSString  *key;
   
   key = NSMapGet( reverseLookup_, obj);
   if( ! key)
      return( nil);
   return( [infoStorage_ objectForKey:key]);
}


- (void) dealloc
{
   [rootKey_ release];
   [objectStorage_ release];
   [infoStorage_ release];
   if( reverseLookup_)
      NSFreeMapTable( reverseLookup_);
   
   [super dealloc];
}


+ (id) unarchiveObjectWithFile:(NSString **) path
{
   NSDictionary           *dict;
   MullePBXUnarchiver     *decoder;
   PBXProject             *project;
   NSString               *dir;
   NSPropertyListFormat   format;
   NSError                *error;
   
   dict = openDictionary( path, &format, &error);
   if( ! dict)
      return( nil);
   
   decoder = [[[self alloc] initWithDictionary:dict] autorelease];
   project = [decoder decodeRootObject];
   [[project rootGroup] setProject:project];
   
   // get main directory (relative possibly)
   dir = [[*path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
   if( ! [dir length])
      dir = @".";

   [project setPath:dir];
   
   return( project);
}

@end
