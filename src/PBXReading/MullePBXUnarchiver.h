/*
   mulle-xcode-to-cmake
   
   $Id: MullePBXUnarchiver.h,v d1ceb40e3ad1 2011/06/22 19:43:12 nat $

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
#import <Foundation/Foundation.h>


@interface MullePBXUnarchiver : NSObject  
{
   int            archiveVersion_;
   int            objectVersion_;
   id             objectStorage_;
   NSDictionary   *infoStorage_;
   NSString       *rootKey_;

   NSMapTable     *reverseLookup_;
}

+ (id) unarchiveObjectWithFile:(NSString **) path;

- (NSDictionary *) infoForObject:(id) obj;
- (int) archiveVersion;
- (int) objectVersion;

@end
