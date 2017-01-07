/*
   mulle-xcode-to-cmake
   
   $Id: PBXTarget+HierarchyAndPaths.h,v 09f0aac0fd20 2011/12/01 21:56:01 nat $

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
#import "PBXObject.h"


@interface PBXTarget( HierarchyAndPaths)

// all fileRefs
- (NSArray *) headersMatchingSelector:(SEL) sel;
- (NSArray *) privateHeaders;
- (NSArray *) publicHeaders;
- (NSArray *) sourceFiles;
- (NSArray *) allSourceAndHeaderFiles;

// relative path names
- (NSArray *) subdirectories;

@end
