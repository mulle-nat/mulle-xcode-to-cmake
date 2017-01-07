/*
   mulle-xcode-utility
   
   $Id: PBXPathObject+HierarchyAndPaths.h,v 65099ebecdce 2011/11/30 23:33:12 nat $

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
#import "PBXObject.h"


@interface PBXPathObject( HierarchyAndPaths)

- (BOOL) isVirtual;
- (BOOL) isGroupRelative;
- (BOOL) isInSourceTreeAndAbsolute;
- (BOOL) isSource;
- (BOOL) isAlias;

- (NSString *) absoluteSourceTreeFileSystemPath;

- (NSString *) absoluteFilesystemPath;
- (NSString *) sourceTreeRelativeFilesystemPath;
- (NSString *) _absoluteFilesystemPath;
- (NSString *) _sourceTreeRelativeFilesystemPath;

- (NSArray *) _sourceTreeRelativeFilesystemPathComponents;
- (NSArray *) _absoluteFilesystemPathComponents;
- (NSArray *) sourceTreeRelativeFilesystemPathComponents;
- (NSArray *) absoluteFilesystemPathComponents;

- (BOOL) isHeader;
- (NSString *) fileType;

- (PBXGroup *) parentGroup;

- (NSArray *) relativePathComponents;
- (NSString *) relativePath;

@end



@interface PBXFileReference( HierarchyAndPaths)

- (NSString *) fileType;

@end


@interface PBXGroup( HierarchyAndPaths)

- (NSArray *) allPossibleProjectHeaderDirectories;

- (id) childNamed:(NSString *) name;

@end

