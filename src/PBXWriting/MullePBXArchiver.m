/*
   mulle-xcode-to-cmake
   
   $Id: MullePBXArchiver.m,v 22d35ece68c9 2011/01/11 15:22:39 nat $

   Created by Nat! on 08.1.11
   Copyright 2011 Mulle kybernetiK
   
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
#import "MullePBXArchiver.h"

#import "MulleSortedKeyDictionary.h"
#import "PBXObject.h"
#import "PBXObject+PBXEncoding.h"


@implementation MullePBXArchiver

- (void) setArchiveVersion:(int) version
{
   archiveVersion_ = version;
}

- (void) setObjectVersion:(int) version;
{
   objectVersion_ = version;
}


+ (NSDictionary *) archivedPropertyListWithRootObject:(id) root
{
   MullePBXArchiver   *archiver;
   
   archiver = [[self new] autorelease];
   return( [archiver encodedRootObject:root]);
}


- (id) init
{
   archiveVersion_  = 1;
   objectVersion_   = 42;
   
   return( self);
}
   

- (void) dealloc
{
   [super dealloc];
}   
  

- (id) encodedObjectForKey:(NSString *) key
{
   return( [encodedObjects_ objectForKey:key]);
}


- (void) setEncodedObject:(id) obj
                   forKey:(NSString *) key
{
   [encodedObjects_ setObject:obj
                       forKey:key];
}
   

- (NSDictionary *) encodedRootObject:(id) root
{
   NSString              *key;
   NSMutableDictionary   *plist;
   NSMutableArray        *classes;
   NSDictionary          *pretty;
   
   plist   = [NSMutableDictionary dictionary];

   encodedObjects_ = [NSMutableDictionary dictionary];
   [root encodeWithPBXArchiver:self];
   pretty = [[[MulleSortedKeyDictionary alloc] initWithDictionary:encodedObjects_] autorelease];
   encodedObjects_ = nil;
   
   [plist setObject:pretty
             forKey:@"objects"];
   
   classes = [NSMutableArray array];

   [plist setObject:classes
             forKey:@"classes"];
   [plist setObject:[NSNumber numberWithInt:archiveVersion_]
             forKey:@"archiveVersion"];
   [plist setObject:[NSNumber numberWithInt:objectVersion_]
             forKey:@"objectVersion"];

   key = [root codecKey];
   [plist setObject:key
             forKey:@"rootObject"];
   
   return( plist);
}
   
@end
