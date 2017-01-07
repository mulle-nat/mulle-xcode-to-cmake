/*
   mulle-xcode-utility
   
   $Id: NSArray+Path.h,v 888dcac8ab3c 2011/10/11 08:32:04 nat $

   Created by Nat! on 10.1.11
   Copyright 2011 Mulle kybernetiK
   
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
#import <Foundation/Foundation.h>


@interface NSArray( Path)

- (NSArray *) standardizedPathComponents;
- (NSArray *) commonPathComponents:(NSArray *) other;
- (NSArray *) componentsByDeletingComponents:(NSArray *) other;
- (NSArray *) relativePathComponentsToRootComponents:(NSArray *) root;

// self : /a/y/z  other: /a  -> y/z
- (NSArray *) componentsByDeletingCommonLeadingPathComponents:(NSArray *) other;
- (NSArray *) componentsByDeletingCommonLeadingComponentsAndPrefixingRest:(NSArray *) other;

@end
