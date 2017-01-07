/*
   mulle-xcode-to-cmake
   
   $Id: NSString+KeyFromSetterSelector.h,v 59bf19ed19d2 2011/06/13 21:07:19 nat $

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
#import <Foundation/Foundation.h>


@interface NSString( KeyFromSetterSelector)

- (NSString *) keyWithRange:(NSRange) range;
- (NSString *) keyFromSetterKey;
+ (NSString *) keyFromSetterSelector:(SEL) sel;

@end
