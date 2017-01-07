/*
   mulle-xcode-to-cmake
   
   $Id: PBXTarget+HierarchyAndPaths.m,v 5e4718e4490d 2012/01/05 14:24:47 nat $

   Created by Nat! on 01.12.11.
   Copyright (C) 2011 Mulle kybernetiK 
   
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
#import "PBXTarget+HierarchyAndPaths.h"

#import "NSArray+FindStuff.h"
#import "NSArray+FilterStuff.h"


@implementation PBXTarget( HierarchyAndPaths)

//
// only concerned about the target subset of sources
// and headers
// 
- (NSArray *) headersMatchingSelector:(SEL) sel
{
   NSArray               *files;
   NSArray               *fileRefs;
   PBXHeadersBuildPhase  *phase;
   
   phase    = [[self buildPhases] objectWithIdenticalClass:[PBXHeadersBuildPhase class]];
   files    = [phase files];
   if( sel)
      files = [files objectsMatchingSelector:sel];
   fileRefs = [files valueForKey:@"fileRef"];

   return( fileRefs);
}


- (NSArray *) privateHeaders
{
   return( [self headersMatchingSelector:@selector( isPrivate)]);
}


- (NSArray *) publicHeaders
{
   return( [self headersMatchingSelector:@selector( isPublic)]);
}


- (NSArray *) sourceFiles
{
   NSArray               *files;
   NSArray               *fileRefs;
   PBXSourcesBuildPhase  *phase;
   
   phase    = [[self buildPhases] objectWithIdenticalClass:[PBXSourcesBuildPhase class]];
   files    = [phase files];
   fileRefs = [files valueForKey:@"fileRef"];

   return( fileRefs);
}


- (NSArray *) allSourceAndHeaderFiles
{
   NSMutableArray   *fileRefs;
   
   fileRefs = [NSMutableArray array];
   [fileRefs addObjectsFromArray:[self headersMatchingSelector:0]];
   [fileRefs addObjectsFromArray:[self sourceFiles]];
   [fileRefs sortUsingSelector:@selector( compare:)];

   return( fileRefs);
}


- (NSArray *) subdirectories
{
   NSArray        *fileRefs;
   NSArray        *dirNames;
   NSArray        *fileNames;
   NSMutableSet   *uniqued;
   NSSet          *set;
   NSUInteger     n;
   
   fileRefs  = [self allSourceAndHeaderFiles];
   fileNames = [fileRefs valueForKey:@"makefileDescription"];
   dirNames  = [fileNames valueForKey:@"stringByDeletingLastPathComponent"];
   
   //
   // if we have ./foo/bar/x.h we want ./foo and ./foo/bar so an include
   // with "bar/x.h" also works, so we give an elaborate list
   //
   uniqued = [NSMutableSet set];
   
   for(;;)
   {
      set = [NSSet setWithArray:dirNames];
      n   = [set count];
      if( n == 0)
         break;
      if( n == 1 && [[set anyObject] isEqualToString:@""])
         break;

      [uniqued addObjectsFromArray:dirNames];
      dirNames = [dirNames valueForKey:@"stringByDeletingLastPathComponent"];
   }
   
   [uniqued removeObject:@""];
   return( [uniqued allObjects]);
}

@end
