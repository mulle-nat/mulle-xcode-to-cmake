/*
   mulle-xcode-settings
   
   $Id: PBXObject.h,v d8d6586b7d91 2011/12/30 15:04:32 nat $

   Created by Nat! on 26.12.10.
   Copyright 2010 Mulle kybernetiK
   
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
#import <Foundation/Foundation.h>


@class MullePBXUnarchiver;
@class PBXProject;


@interface PBXObject : NSObject 
{
   NSMutableDictionary   *info_;
   NSString              *codecKey_;
   PBXProject            *project_; 
}

- (id) initWithProject:(PBXProject *) pbx;
- (id) initWithPBXUnarchiver:(MullePBXUnarchiver *) coder
                     project:(PBXProject *) pbx;
- (void) setCodecKey:(NSString *) key;
- (NSString *) codecKey;
- (id) objectForKey:(NSString *) key;
- (void) setObject:(id) value
            forKey:(NSString *) key;
- (PBXProject *) project;
- (NSString *) name;

@end


@class PBXFileReference;


@interface PBXPathObject : PBXObject

- (NSString *) path;
- (NSString *) sourceTree;
- (NSString *) displayName;
- (PBXFileReference *) fileRef; // ??
- (NSString *) xcodeVirtualName; 

@end


@interface PBXFileReference : PBXPathObject 

- (NSString *) explicitFileType;
- (BOOL) includeInIndex;
- (NSString *) fileEncoding;
- (NSString *) lastKnownFileType;
- (NSString *) makefileDescription;

@end


@class PBXProject;


@interface PBXGroup : PBXPathObject
{
}

- (NSArray *) children;
 
@end


// 
// basically a localized resource
//
@interface PBXVariantGroup : PBXGroup 

- (NSArray *) children;
- (NSString *) sourceTree;

@end


@interface PBXContainerItemProxy : PBXGroup
@end


@interface PBXBuildFile : PBXObject 

- (NSDictionary *) settings;
- (PBXFileReference *) fileRef;

- (BOOL) isPrivate;
- (BOOL) isPublic;

@end


@interface PBXBuildPhase : PBXObject 

- (unsigned int) buildActionMask;
- (BOOL) runOnlyForDeploymentPostprocessing;
- (NSArray *) files;

@end

           
@interface PBXCopyFilesBuildPhase : PBXBuildPhase 

- (NSString *) dstPath;
- (NSString *) dstSubfolderSpec;

@end


@interface PBXFrameworksBuildPhase : PBXBuildPhase 
@end


@interface PBXHeadersBuildPhase : PBXBuildPhase 
@end


@interface PBXShellScriptBuildPhase : PBXBuildPhase 

- (NSString *) shellPath;
- (NSString *) shellScript;
- (NSArray *) outputPaths;
- (NSArray *) inputPaths;

@end


@interface PBXResourcesBuildPhase : PBXBuildPhase 
@end


@interface PBXSourcesBuildPhase : PBXBuildPhase 
@end


@interface PBXRezBuildPhase : PBXBuildPhase 
@end


@interface XCBuildConfiguration : PBXObject 

- (NSDictionary *) buildSettings;
- (PBXFileReference *) baseConfigurationReference;

@end


@interface XCVersionGroup : PBXPathObject
@end


@interface XCConfigurationList : PBXObject 

- (NSArray *) buildConfigurations;
- (BOOL) defaultConfigurationIsVisible;
- (NSString *) defaultConfigurationName;

@end


@interface PBXObjectWithConfigurationList : PBXObject
{
   id    settingsCache_;
}

- (XCConfigurationList *) buildConfigurationList;
- (NSArray *) buildConfigurations;

@end


@interface PBXTargetDependency : PBXObject

@end


@interface PBXTarget : PBXObjectWithConfigurationList

// all made with "forwarding"
- (NSArray *) buildPhases;
- (NSArray *) buildRules;
- (NSArray *) dependencies;
- (NSString *) productInstallPath;
- (NSString *) productName;
- (id) productReference;
- (id) productType;

@end


@interface PBXNativeTarget : PBXTarget 
@end


@interface PBXAggregateTarget : PBXTarget 
@end

//
// a reference to another XCode project
//
@interface PBXReferenceProxy : PBXPathObject

- (NSString *) remoteRef;
- (NSString *) fileType;

@end


@interface PBXProject : PBXObjectWithConfigurationList 
{
   NSString  *path_;
   NSString  *absolutePath_;
}
- (NSString *) compatibilityVersion;
- (BOOL) hasScannedForEncodings;
- (id) rootGroup;
- (id) productRefGroup;
- (NSString *) projectDirPath;
- (NSString *) projectRoot;
- (NSArray *) targets;

- (void) setPath:(NSString *) path;
- (NSString *) path;
- (NSString *) absolutePath;

@end


