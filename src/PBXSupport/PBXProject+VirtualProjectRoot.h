/*
   mulle-xcode-settings
   
   $Id: PBXProject+VirtualProjectRoot.h,v 888dcac8ab3c 2011/10/11 08:32:04 nat $

   Created by Nat! on 19.06.11
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
#import "PBXObject.h"


@interface PBXTarget( VirtualProjectRoot)

- (NSString *) virtualProjectRoot;
- (NSArray *) sourceDirectories;

@end


@interface PBXProject( VirtualProjectRoot)

- (NSDictionary *) virtualProjectRoots;
- (NSArray *) sourceDirectories;

@end
