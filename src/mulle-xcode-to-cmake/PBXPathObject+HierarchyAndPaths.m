/*
   mulle-xcode-utility
   
   $Id: PBXPathObject+HierarchyAndPaths.m,v 5e4718e4490d 2012/01/05 14:24:47 nat $

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
#import "PBXPathObject+HierarchyAndPaths.h"

#import "NSArray+Path.h"


@implementation PBXPathObject( HierarchyAndPaths)

// returns the absolute
- (BOOL) isVirtual
{
   return( [self objectForKey:@"name"] != nil && [self objectForKey:@"path"] == nil);
}


- (BOOL) isSource
{
   return( [[self fileType] hasPrefix:@"sourcecode."]);
}


- (BOOL) isInSourceTree:(NSString *) path
{
   NSString   *root;
   
   path = [path stringByStandardizingPath];
   if( ! [path length])
      return( NO);
   if( [path hasPrefix:@".."])
      return( NO);
   if( ! [path isAbsolutePath])
      return( YES);

   root = [[self project] absolutePath];
   return( [path hasPrefix:root]);
}


- (BOOL) isInSourceTree
{
   return( [self isInSourceTree:[self _sourceTreeRelativeFilesystemPath]]);
}


- (BOOL) isInSourceTreeAndAbsolute
{
   if( [self isGroupRelative])
      return( NO);
   return( [self isInSourceTree]);
}


- (BOOL) isGroupRelative
{
   NSString   *tree;

   tree = [self sourceTree];
   return( [tree isEqualToString:@"<group>"]);
}


- (BOOL) isAlias
{
   return( [self path] && [self name]);
}


- (NSString *) absoluteSourceTreeFileSystemPath
{
   NSString   *tree;
   PBXGroup   *rootGroup;
   PBXGroup   *parentGroup;
   
   tree = [self sourceTree];
   if( [tree isEqualToString:@"<absolute>"])
      return( @"/");
      
   rootGroup = [[self project] rootGroup];
   if( [tree isEqualToString:@"<group>"])
   {
      parentGroup = [self parentGroup];
      if( ! parentGroup)
         return( [[self project] absolutePath]);
      return( [parentGroup _absoluteFilesystemPath]);
   }
   
   if( [tree hasPrefix:@"<"])
   {
      NSLog( @"unknown sourceTree type \"%@\"", tree);
      return( nil);
   }
     
   //
   // TODO: others are environment variables
   // we would NEED to go through settings here
   // but it makes no sense, since they change 
   // depending on target and build style
   
   if( [tree isEqualToString:@"SOURCE_ROOT"])
   {
      return( [[self project] absolutePath]);    
   }
      
   return( nil);
}


- (NSString *) unresolvedFileSystemPath
{
   NSString   *tree;
   NSString   *path;
   
   tree = [self sourceTree];
   if( [tree isEqualToString:@"<absolute>"])
      return( [self _absoluteFilesystemPath]);
      
   if( [tree isEqualToString:@"<group>"])
      return( [self relativePath]);
   
   if( [tree hasPrefix:@"<"])
   {
      NSLog( @"unknown sourceTree type \"%@\"", tree);
      return( nil);
   }
     
   path = [self relativePath];
   if( ! path)
      return( nil);
      
   return( [NSString stringWithFormat:@"$(%@)/%@", tree, path]);
}


- (NSArray *) relativePathComponents
{
   NSArray   *dadComponents;
   NSArray   *pathComponents;
   NSString  *path;
   
   dadComponents = [[self parentGroup] relativePathComponents];

   path = [self path];
   if( ! path)
      return( dadComponents);
      
   pathComponents = [path pathComponents];
   if( dadComponents)
      pathComponents = [dadComponents arrayByAddingObjectsFromArray:pathComponents];
   pathComponents = [pathComponents standardizedPathComponents];

   return( pathComponents);
}

// usually relative
- (NSArray *) pathComponentsForMakefile
{
   NSString   *tree;
   NSString   *s;
   NSString   *seperator;
   id         components;
   
   tree = [self sourceTree];

   if( [tree isEqualToString:@"<absolute>"])
      return( [[self path] pathComponents]);
      
   //
   // TODO: others are environment variables
   // we would NEED to go through settings here
   // but it makes no sense, since they change 
   // depending on target and build style
   
   components = [self relativePathComponents];
   if( ! [components count])
      return( nil);
      
   if( [tree isEqualToString:@"<group>"])
      return( components);
   if( [tree isEqualToString:@"SOURCE_ROOT"])
      return( components);
   if( [tree hasPrefix:@"<"]) // ???
      return( components);

   seperator = @"";
   if( [tree isEqualToString:@"BUILT_PRODUCTS_DIR"])
      seperator = @"/";

   components = [[components mutableCopy] autorelease];
   s          = [NSString stringWithFormat:@"$(%@)%@%@", tree, seperator, [components objectAtIndex:0]];
   [components replaceObjectAtIndex:0
                         withObject:s];
   return( components);
}


- (NSString *) relativePath
{
   return( [[self relativePathComponents] componentsJoinedByString:@"."]);
}


- (NSArray *) _sourceTreeRelativeFilesystemPathComponents
{
   NSArray    *pathComponents;
   NSArray    *dadComponents;
   NSString   *path;
   PBXGroup   *dad;
   
   if( ! [self isGroupRelative])
      return( nil);

   dad  = [self parentGroup];
   path = [self path];
   NSParameterAssert( ! [path hasPrefix:@"/"]);
   
   pathComponents = [path pathComponents];
   dadComponents  = [dad _sourceTreeRelativeFilesystemPathComponents];
   if( dadComponents)
      pathComponents = [dadComponents arrayByAddingObjectsFromArray:pathComponents];
   
   if( ! pathComponents)
      pathComponents = [NSArray arrayWithObject:@"."];
   pathComponents = [pathComponents standardizedPathComponents];

   return( pathComponents);
}


- (NSArray *) sourceTreeRelativeFilesystemPathComponents
{
   if( [self isVirtual])
      return( nil);
   
   return( [self _sourceTreeRelativeFilesystemPathComponents]);
}



- (NSString *) sourceTreeRelativeFilesystemPath
{
   NSArray  *components;
   
   components = [self sourceTreeRelativeFilesystemPathComponents];
   if( ! components)
      return( nil);
      
   return( [NSString pathWithComponents:components]);
}


- (NSString *) _sourceTreeRelativeFilesystemPath
{
   NSArray  *components;
   
   components = [self _sourceTreeRelativeFilesystemPathComponents];
   if( ! components)
      return( nil);
   return( [NSString pathWithComponents:components]);
}


- (NSArray *) _absoluteFilesystemPathComponents
{
   NSString   *path;
   NSArray    *pathComponents;
   NSArray    *rootComponents;
   NSString   *rootPath;
   PBXGroup   *rootGroup;
   PBXProject   *project;
   
   project   = [self project];
   rootGroup = [project rootGroup];
   if( self == rootGroup)
      return( [[project absolutePath] pathComponents]);
   
   rootPath = [self absoluteSourceTreeFileSystemPath];
   // can happen, if file is rooted to SDKROOT f.e.
   if( ! rootPath)
      return( nil);
   
   rootComponents = [rootPath pathComponents]; 
   if( [self isVirtual])
      return( rootComponents);

   path           = [self path];
   pathComponents = [path pathComponents]; 
   NSParameterAssert( [path length]);
   
   pathComponents = [rootComponents arrayByAddingObjectsFromArray:pathComponents];
   pathComponents = [pathComponents standardizedPathComponents];
   
   return( pathComponents);
}


- (NSArray *) absoluteFilesystemPathComponents
{
   if( [self isVirtual])
      return( nil);

   return( [self _absoluteFilesystemPathComponents]);
}


- (NSString *) _absoluteFilesystemPath
{
   NSArray  *components;
   
   components = [self _absoluteFilesystemPathComponents];
   if( ! components)
      return( nil);
   return( [NSString pathWithComponents:components]);
}


- (NSString *) absoluteFilesystemPath
{
   NSArray  *components;
   
   components = [self absoluteFilesystemPathComponents];
   if( ! components)
      return( nil);
      
   return( [NSString pathWithComponents:components]);
}


- (void) appendProjectHeaderDirectoriesToSet:(NSMutableSet *) set
{
}


- (PBXGroup *) parentGroup
{
   return( [[[[self project] rootGroup] groupsToDescendant:self] lastObject]);
}


- (NSArray *) groupsToDescendant:(id) child
{
   NSParameterAssert( child);
   return( nil);
}


- (NSString *) fileType
{
   return( nil);
}


- (BOOL) isHeader
{
   NSString   *type;
   NSString   *ext;
   
   type = [self fileType];
   if( ! [type hasPrefix:@"sourcecode."])
      return( NO);
   ext = [type pathExtension];
   return( [ext hasPrefix:@"h"] && [ext length] <= 3);  // heurisitic
}


- (id) descendantWithRelativeFilesystemPath:(NSString *) path
{
   NSParameterAssert( [path isKindOfClass:[NSString class]]);

   if( [[self sourceTreeRelativeFilesystemPath] isEqualToString:path])
      return( self);
   return( nil);
}


- (NSArray *) descendantsWithAbsoluteFilesystemPath:(NSString *) path
{
   NSParameterAssert( [path isKindOfClass:[NSString class]]);

   if( [[self absoluteFilesystemPath] isEqualToString:path])
      return( [NSArray arrayWithObject:self]);
   return( nil);
}

@end


@implementation PBXGroup( HierarchyAndPaths)

- (BOOL) isHeader
{
   return( NO);
}


- (BOOL) isSource
{
   NSEnumerator   *rover;
   id             fileOrGroup;
   
   if( ! [self isInSourceTree])
      return( NO);
      
   rover = [[self children] objectEnumerator];
   while( fileOrGroup = [rover nextObject])
      if( [fileOrGroup isSource])
         return( YES);
   return( NO);
}


- (void) appendProjectHeaderDirectoriesToSet:(NSMutableSet *) set
{
   NSEnumerator   *rover;
   id             candidate;
   NSString       *path;
   
   rover = [[self children] objectEnumerator];
   while( candidate = [rover nextObject])
   {
      if( [candidate isHeader])
      {
         path = [candidate sourceTreeRelativeFilesystemPath];
         for(;;)
         {
            path = [path stringByDeletingLastPathComponent];
            if( [path length])
            {
               [set addObject:[@"." stringByAppendingPathComponent:path]];
               continue;
            }
            [set addObject:@"."];
            break;
         }
         continue;
      }
      
      [candidate appendProjectHeaderDirectoriesToSet:set];
   }
}


- (NSArray *) allPossibleProjectHeaderDirectories
{
   NSMutableSet   *set;
   
   set = [NSMutableSet set];
   [self appendProjectHeaderDirectoriesToSet:set];
   return( [[set allObjects] sortedArrayUsingSelector:@selector( compare:)]);
}


//
// will not include child
// will therefore only contain PBXGroup objects
//
- (NSArray *) groupsToDescendant:(id) descendant
{
   NSEnumerator     *rover;
   NSMutableArray   *result;
   NSArray          *tmp;
   id               candidate;

   if( self == descendant)
      return( nil);
      
   rover = [[self children] objectEnumerator];
   while( candidate = [rover nextObject])
   {
      if( candidate == descendant)
         return( [NSArray arrayWithObject:self]);

      tmp = [candidate groupsToDescendant:descendant];
      if( ! tmp)
         continue;
         
      result = [NSMutableArray arrayWithObject:self];
      [result addObjectsFromArray:tmp];
      return( result);
   }
   return( nil);
}

- (NSArray *) xcodeVirtualPathComponentsToDescendant:(id) descendant
{
   NSMutableArray    *pathComponents;
   NSEnumerator      *rover;
   PBXGroup          *group;
   NSString          *name;
   
   pathComponents = [NSMutableArray array];
   
   rover = [[self groupsToDescendant:descendant] objectEnumerator];
   while( group = [rover nextObject])
   {
      // "name" is virtual, we don't care
      name = [group xcodeVirtualName];
      if( [name length])
         [pathComponents addObjectsFromArray:[name pathComponents]];
   }
   return( [pathComponents standardizedPathComponents]);
}



- (id) childNamed:(NSString *) name
{
   NSEnumerator   *rover;
   id             child;
   
   rover = [[self children] objectEnumerator];
   while( child = [rover nextObject])
      if( [[child name] isEqualToString:name])
         break;
   return( child);
}


@end



@implementation PBXFileReference( HierarchyAndPaths)

/*
 for later...
file.h
file.cc
file.cp
file.cxx
file.cpp
file.CPP
file.c++
file.C
file.mm
file.M
file.hh
file.H
file.hp
file.hxx
file.hpp
file.HPP
file.h++
*/

- (NSString *) fileType
{
   NSString   *type;
   NSString   *extension;
   
   type = [self lastKnownFileType];
   if( type)
      return( type);
   
   extension = [[self path] pathExtension];
   if( [extension isEqualToString:@"h"])
      return( @"sourcecode.c.h");
   if( [extension isEqualToString:@"hpp"])
      return( @"sourcecode.c.hpp");
   if( [extension isEqualToString:@"c"])
      return( @"sourcecode.c.c");
   if( [extension isEqualToString:@"m"])
      return( @"sourcecode.c.objc");
   if( [extension isEqualToString:@"mm"])
      return( @"sourcecode.cpp.objcpp");
   if( [extension isEqualToString:@"cpp"])
      return( @"sourcecode.cpp.cpp");
   if( [extension isEqualToString:@"framework"])
      return( @"wrapper.framework");
   if( [extension isEqualToString:@"dylib"])
      return( @"compiled.mach-o.dylib");

   return( @"???");
}

@end
