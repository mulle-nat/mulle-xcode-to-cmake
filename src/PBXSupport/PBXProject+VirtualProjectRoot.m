/*
   mulle-xcode-to-cmake
   
   $Id: PBXProject+VirtualProjectRoot.m,v 65099ebecdce 2011/11/30 23:33:12 nat $

   Created by Nat! on 19.06.11
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
#import "PBXProject+VirtualProjectRoot.h"

#import "PBXPathObject+HierarchyAndPaths.h"
#import "NSArray+FindStuff.h"


@implementation PBXTarget( VirtualProjectRoot)

- (NSString *) virtualProjectRoot
{
   PBXSourcesBuildPhase   *sources;
   NSEnumerator           *rover;
   PBXPathObject          *file;
   NSString               *path;
   NSArray                *common;
   NSArray                *components;
   unsigned int           i, n;
   unsigned int           m;
   
   sources = [[self buildPhases] objectWithIdenticalClass:[PBXSourcesBuildPhase class]];
   common = nil;

   rover = [[sources files] objectEnumerator];
   while( file = [rover nextObject])
   {
      path = [[file fileRef] sourceTreeRelativeFilesystemPath];
      components = [[path stringByDeletingLastPathComponent] pathComponents];
      if( ! common)
         common = components;
      else
      {
         n = [common count];
         m = [components count];
         if( n > m)
            n = m;
         for( i = 0; i < n; i++)
            if( ! [[common objectAtIndex:i] isEqualToString:[components objectAtIndex:i]])
               break;
         if( ! i)
            return( nil);
         if( i < n)
            common = [common subarrayWithRange:NSMakeRange( 0, i)];
      }
   }
   return( [NSString pathWithComponents:common]);
}


- (NSArray *) sourceDirectories
{
   PBXSourcesBuildPhase   *sources;
   NSEnumerator           *rover;
   PBXPathObject          *file;
   NSString               *path;
   NSString               *common;
   NSMutableSet           *set;
   
   set = [NSMutableSet set];

   common  = [self virtualProjectRoot];
   sources = [[self buildPhases] objectWithIdenticalClass:[PBXSourcesBuildPhase class]];

   rover = [[sources files] objectEnumerator];
   while( file = [rover nextObject])
   {
      path = [[file fileRef] sourceTreeRelativeFilesystemPath];
      path = [path substringFromIndex:[common length] + 1];
      path = [path stringByDeletingLastPathComponent];
      
      if( [path length])
         [set addObject:path];
   }
   return( [[set allObjects] sortedArrayUsingSelector:@selector( compare:)]);   
}

@end


@implementation PBXProject( VirtualProjectRoot)

- (NSDictionary *) virtualProjectRoots
{
   NSMutableDictionary   *result;
   NSEnumerator          *rover;
   NSString              *path;
   PBXTarget             *target;
   
   result = [NSMutableDictionary dictionary];
   
   rover = [[self targets] objectEnumerator];
   while( target = [rover nextObject])
   {
      path = [target virtualProjectRoot];
      if( ! path)
         path = @"";
      [result setObject:path
                 forKey:[target name]];
   }
   return( result);
}


- (NSArray *) sourceDirectories
{
   NSMutableSet     *result;
   NSEnumerator     *rover;
   PBXTarget        *target;
   NSArray          *dirs;
   
   result = [NSMutableSet set];
   
   rover = [[self targets] objectEnumerator];
   while( target = [rover nextObject])
   {
      dirs = [target sourceDirectories];
      [result addObjectsFromArray:dirs];
   }
   return( [result allObjects]);
}

@end
