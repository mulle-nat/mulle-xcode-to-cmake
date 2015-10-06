/*
   mulle-xcode-settings
   
   $Id: PBXObject+PBXEncoding.m,v 22d35ece68c9 2011/01/11 15:22:39 nat $

   Created by Nat! on 08.1.11
   Copyright 2011 Mulle kybernetiK
   
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
#import "PBXObject+PBXEncoding.h"

#import "MullePBXArchiver.h"


@implementation NSObject( PBXEncoding)

- (id) encodeWithPBXArchiver:(MullePBXArchiver *) archiver
{
   return( self);
}

@end


@implementation NSArray( PBXEncoding)

- (id) encodeWithPBXArchiver:(MullePBXArchiver *) archiver
{
   NSMutableArray  *array;
   NSEnumerator    *rover;
   id              obj;
   
   array = [NSMutableArray array];
   rover = [self objectEnumerator];
   while( obj = [rover nextObject])
      [array addObject:[obj encodeWithPBXArchiver:archiver]];

   return( array);
}

@end


@implementation NSDictionary( PBXEncoding)

- (id) encodeWithPBXArchiver:(MullePBXArchiver *) archiver
{
   NSMutableDictionary  *dictionary;
   NSEnumerator         *rover;
   NSString             *key;
   id                   value;
   
   dictionary = [NSMutableDictionary dictionary];
   
   rover = [self keyEnumerator];
   while( key = [rover nextObject])
   {
      value = [self objectForKey:key];
      [dictionary setObject:[value encodeWithPBXArchiver:archiver]
                     forKey:key];
   }
   return( dictionary);
}

@end


@implementation PBXObject( PBXEncoding)

- (id) encodeWithPBXArchiver:(MullePBXArchiver *) archiver
{
   NSEnumerator         *rover;
   NSString             *key;
   NSMutableDictionary  *encoded;
   NSString             *encodeKey;
   id                   value;
   
   encodeKey = [self codecKey];
   if( [archiver encodedObjectForKey:encodeKey])
      return( encodeKey);
      
   encoded = [NSMutableDictionary dictionary];
   [archiver setEncodedObject:encoded
                       forKey:encodeKey];
   
   rover = [info_ keyEnumerator];
   while( key = [rover nextObject])
   {  
      value = [info_ objectForKey:key];
      value = [value encodeWithPBXArchiver:archiver];
      [encoded setObject:value
                  forKey:key];
   }
   return( encodeKey);
}

@end
