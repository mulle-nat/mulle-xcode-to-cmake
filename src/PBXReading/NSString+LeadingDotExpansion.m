/*
   mulle-xcode-utility

   $Id: NSString+LeadingDotExpansion.m,v 034ba733529c 2011/12/15 22:30:44 nat $

   Created by Nat! on 26.12.10.
   Copyright 2010 Mulle kybernetiK

   This file is part of mulle-xcode-utility.

   mulle-xcode-utility is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   mulle-xcode-utility is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with mulle-xcode-utility.  If not, see <http://www.gnu.org/licenses/>.
 */
#import "NSString+LeadingDotExpansion.h"


@implementation NSString( LeadingDotExpansion)

- (NSString *) stringByResolvingWithWorkingDirectory
{
   NSArray      *components;
   NSString     *path;
   NSString     *first;
   id           result;
   
   components = [self pathComponents];
   first      = [components objectAtIndex:0];
   
   if( ! [first isEqualToString:@"."] && ! [first isEqualToString:@".."])
      return( self);

   path   = [[[NSFileManager new] autorelease] currentDirectoryPath];
   result = [[[path pathComponents] mutableCopy] autorelease];
   [result addObjectsFromArray:components]; // will have trailing "." but thats OK
   return( [NSString pathWithComponents:result]);
}

@end
