/*
   mulle-xcode-to-cmake
   
   $Id: PBXObject.m,v cf43ff7e1447 2011/12/19 16:28:31 nat $

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
#import "PBXObject.h"

#import "MullePBXUnarchiver.h"
#import "NSString+KeyFromSetterSelector.h"
#import "NSString+LeadingDotExpansion.h"


@implementation PBXObject

- (id) init
{
   NSLog( @"ur doin it rrrong");
   abort();
   return( 0);
}
   
   
- (id) initWithProject:(PBXProject *) pbx
{
   [super init];
   
   project_ = pbx;
   
   info_ = [NSMutableDictionary new];
   [self setIsa:NSStringFromClass( [self class])];
   
   return( self);
}


- (id) initWithPBXUnarchiver:(MullePBXUnarchiver *) coder
                     project:(PBXProject *) pbx
{
   [self initWithProject:pbx];
   
   info_ = [[coder infoForObject:self] mutableCopy];

   return( self);
}


- (void) dealloc
{
   [codecKey_ release];
   [info_ release];
   [super dealloc];
}


- (NSUInteger) count
{
   return( [info_ count]);
}


- (id) objectForKey:(NSString *) key
{
   return( [info_ objectForKey:key]);
}


- (void) setObject:(id) value
            forKey:(NSString *) key
{
   [info_ setObject:value
             forKey:key];
}


- (void) removeObjectForKey:(NSString *) key
{
   [info_ removeObjectForKey:key];
}


- (NSEnumerator *) keyEnumerator
{
   return( [info_ keyEnumerator]);
}


- (PBXProject *) project
{
   NSParameterAssert( project_);
   return( project_);
}


- (NSString *) name
{
   NSString  *s;
   
   s = [self objectForKey:@"name"];
   if( ! s)
   {
      s = [[self class] description];
      if( [s hasPrefix:@"PBX"])
         s = [s substringFromIndex:3];
   }
   return( s);
}


- (NSString *) displayName
{
   return( [self name]);
}


- (NSString *) description
{
   return( [info_ description]);
}


- (NSString *) debugDescription
{
   return( [NSString stringWithFormat:@"<%@ %p (%@)>",
         [self class], self, [self displayName]]);
}

// cheap..

- (NSMethodSignature *) methodSignatureForSelector:(SEL) aSelector
{
   NSString  *s;
   
   s = NSStringFromSelector( aSelector);
   if( [s hasSuffix:@":"])
   {
      if( [s hasPrefix:@"set"])  // this is probably a stumper ;)
         return( [NSObject instanceMethodSignatureForSelector:@selector( forwardInvocation:)]);
      return( nil);
   }
   return( [NSObject instanceMethodSignatureForSelector:@selector( self)]);
}


- (void) forwardInvocation:(NSInvocation *) anInvocation
{
   NSString   *key;
   id         value;
   
   key = NSStringFromSelector( [anInvocation selector]);
   if( [key hasSuffix:@":"] && [key hasPrefix:@"set"])
   {
      [anInvocation getArgument:&value
                        atIndex:2];
      key = [key keyFromSetterKey];
      if( ! value)
         [info_ removeObjectForKey:key];
      else
         [info_ setObject:value
                   forKey:key];
      return;
   }
   
   value = [self objectForKey:key];
   [anInvocation setReturnValue:&value];
}


- (NSString *) codecKey
{
   if( ! codecKey_)
      codecKey_ = [[[NSProcessInfo processInfo] globallyUniqueString] retain];
   return( codecKey_);
}


- (void) setCodecKey:(NSString *) s
{
   NSParameterAssert( ! codecKey_);
   codecKey_ = [s copy];
}


// yet another kludge, fails if key is usually known but nil
- (id) valueForKey:(NSString *) key
{
   id   value;
   
   value = [self objectForKey:key];
   if( value)
      return( value);
      
   return( [super valueForKey:key]);
}

@end


@implementation PBXPathObject

- (NSString *) debugDescription
{
   return( [NSString stringWithFormat:@"<%@ %p: \"%@\">", [self class], self, [self displayName]]);
}


- (NSString *) xcodeVirtualName
{
   NSString  *s;
   
   s = [self name];
   if( s)
      return( s);
   s = [self path];
   return( s);
}


- (NSString *) path
{
   return( [self objectForKey:@"path"]);
}


- (NSString *) name
{
   return( [self objectForKey:@"name"]);
}


- (NSString *) displayName
{
   return( [self xcodeVirtualName]);
}

@end


@implementation PBXFileReference 

- (BOOL) includeInIndex
{
   return( [[self objectForKey:@"includeInIndex"] intValue]);
}


- (NSComparisonResult) compare:(id) other
{
   return( [[self makefileDescription] compare:[other makefileDescription]]);
}


- (BOOL) fileTypeHasPrefix:(NSString *) prefix
{
   return( [[self fileType] hasPrefix:prefix]);
}

@end


@implementation PBXBuildFile

- (int) headerType
{
   NSDictionary  *settings;
   NSArray       *attributes;
   
   settings   = [self objectForKey:@"settings"];
   attributes = [settings objectForKey:@"ATTRIBUTES"];
   if( [attributes containsObject:@"Private"])
      return( -1);
   if( [attributes containsObject:@"Public"])
      return( 1);
   return( 0);
}


- (BOOL) isPrivate
{
   return( [self headerType] < 0);
}


- (BOOL) isPublic
{
   return( [self headerType] > 0);
}

@end


@implementation PBXGroup 

- (NSString *) debugDescription
{
   NSString  *children;
   
   children = [[self subgroups] valueForKey:@"displayName"];
   return( [NSString stringWithFormat:@"<%@ %p: \"%@\" (%@)>", [self class], self, [self displayName], children]);
}

@end


@implementation PBXVariantGroup 

// hacks for Makefile production removed (so something will be broken there)
//- (NSString *) sourceTreeRelativeFilesystemPath(PBXGroup *) group
//{
//   return( [[[self children] mulleFirstObject] relativeFilesystemPathgroup]);
//}
//
//
//- (NSString *) absolutePathToRootGroup:(PBXGroup *) group
//{
//   return( [[[self children] mulleFirstObject] absolutePathToRootGroup:group]);
//}

@end


@implementation PBXContainerItemProxy 

- (void) forwardInvocation:(NSInvocation *) anInvocation
{
   id   value;
   
   value = [self objectForKey:@"containerPortal"];
   [anInvocation invokeWithTarget:value];
}

@end


@implementation PBXBuildPhase 

- (unsigned int) buildActionMask
{
   return( [[self objectForKey:@"buildActionMask"] intValue]);
}

- (BOOL) runOnlyForDeploymentPostprocessing
{
   return( [[self objectForKey:@"runOnlyForDeploymentPostprocessing"] boolValue]);
}

@end


@implementation PBXFrameworksBuildPhase 
@end


@implementation PBXHeadersBuildPhase
@end


@implementation PBXCopyFilesBuildPhase 
@end


@implementation PBXShellScriptBuildPhase 
@end


@implementation PBXResourcesBuildPhase 
@end


@implementation PBXRezBuildPhase 
@end


@implementation PBXSourcesBuildPhase 
@end


@implementation PBXObjectWithConfigurationList

- (void) dealloc
{
   [settingsCache_ release];
   [super dealloc];
}


- (NSArray *) buildConfigurations
{
   return( [[self buildConfigurationList] buildConfigurations]);
}

@end


@implementation PBXTargetDependency
@end


@implementation PBXTarget
@end


@implementation PBXNativeTarget 
@end


@implementation PBXAggregateTarget 
@end


@implementation XCVersionGroup
@end


@implementation XCBuildConfiguration 
@end


@implementation XCConfigurationList 

- (BOOL) defaultConfigurationIsVisible
{
   return( [[self objectForKey:@"defaultConfigurationIsVisible"] boolValue]);
}

@end


@implementation PBXReferenceProxy 
@end


@implementation PBXProject 

- (BOOL) hasScannedForEncodings
{
   return( [[self objectForKey:@"hasScannedForEncodings"] boolValue]);
}


- (PBXGroup *) rootGroup
{
   return( [self mainGroup]);
}


- (NSString *) absolutePath
{
   NSString   *path;
   
   if( ! absolutePath_)
   {
      path = path_;
     
      path = [path stringByResolvingWithWorkingDirectory];
      path = [path stringByExpandingTildeInPath];
      path = [path stringByStandardizingPath];
      path = [path stringByResolvingSymlinksInPath];

      absolutePath_ = [path copy];
   }
   return( absolutePath_);
}


- (void) setPath:(NSString *) path
{
   path_ = [path copy];
}


- (NSString *) path;
{
   return( path_);
}

@end
