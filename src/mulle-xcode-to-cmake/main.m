/*
 mulle-xcode-to-cmake

 Created by Nat! on 7.1.17
 Copyright 2017 Mulle kybernetiK

 This file is part of mulle-xcode-to-cmake

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

#import "MullePBXArchiver.h"
#import "MullePBXUnarchiver.h"
#import "PBXObject.h"
#import "PBXHeadersBuildPhase+Export.h"
#import "PBXPathObject+HierarchyAndPaths.h"
#import "NSString+ExternalName.h"


static BOOL   verbose;
static BOOL   suppressBoilerplate;
static BOOL   suppressProject;
static BOOL   suppressFoundation;
static BOOL   suppressUIKit = YES;

static NSString  *hackPrefix = @"";

static NSMutableDictionary  *staticLibraries;
static NSMutableDictionary  *sharedLibraries;
static NSMutableSet         *headerDirectories;


static char   head_MacOSXBundleInfo[] =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
"<plist version=\"1.0\">\n"
"<dict>\n"
"   <key>CFBundleDevelopmentRegion</key>\n"
"   <string>English</string>\n"
"   <key>CFBundleExecutable</key>\n"
"   <string>${MACOSX_BUNDLE_EXECUTABLE_NAME}</string>\n"
"   <key>CFBundleGetInfoString</key>\n"
"   <string>${MACOSX_BUNDLE_INFO_STRING}</string>\n"
"   <key>CFBundleIconFile</key>\n"
"   <string>${MACOSX_BUNDLE_ICON_FILE}</string>\n"
"   <key>CFBundleIdentifier</key>\n"
"   <string>${MACOSX_BUNDLE_GUI_IDENTIFIER}</string>\n"
"   <key>CFBundleInfoDictionaryVersion</key>\n"
"   <string>6.0</string>\n"
"   <key>CFBundleLongVersionString</key>\n"
"   <string>${MACOSX_BUNDLE_LONG_VERSION_STRING}</string>\n"
"   <key>CFBundleName</key>\n"
"   <string>${MACOSX_BUNDLE_BUNDLE_NAME}</string>\n"
"   <key>CFBundleShortVersionString</key>\n"
"   <string>${MACOSX_BUNDLE_SHORT_VERSION_STRING}</string>\n"
"   <key>CFBundleSignature</key>\n"
"   <string>????</string>\n"
"   <key>CFBundleVersion</key>\n"
"   <string>${MACOSX_BUNDLE_BUNDLE_VERSION}</string>\n"
"   <key>NSHumanReadableCopyright</key>\n"
"   <string>${MACOSX_BUNDLE_COPYRIGHT}</string>\n";

static char   tail_MacOSXBundleInfo[] =
"</dict>\n"
"</plist>\n";

static void   addSharedLibrariesToFind( NSString *name, NSString *library)
{
   if( ! sharedLibraries)
      sharedLibraries = [NSMutableDictionary new];
   [sharedLibraries setObject:library
                       forKey:name];
}

static void   addStaticLibrariesToFind( NSString *name, NSString *library)
{
   if( ! staticLibraries)
      staticLibraries = [NSMutableDictionary new];
   [staticLibraries setObject:library
                       forKey:name];
}


static void   addHeaderDirectory( NSString *path)
{
   if( ! headerDirectories)
      headerDirectories = [NSMutableSet new];
   [headerDirectories addObject:path];
}


static void   usage()
{
   fprintf( stderr,
           "usage: mulle-xcode-to-cmake [options] <commands> <file.xcodeproj>\n"
           "\n"
           "Options:\n"
           ""
           "\t-b          : suppress boilerplate definitions\n"
           "\t-f          : suppress Foundation (implicitly added)\n"
           "\t-p          : suppress project\n"
           "\t-t <target> : target to export\n"
           "\t-u          : addd UIKIt\n"
           "\n"
           "Commands:\n"
           "\texport      : export CMakeLists.txt to stdout\n"
           "\tlist        : list targets\n"
           "\n"
           "Environment:\n"
           "\tVERBOSE     : dump some info to stderr\n"
         );

   exit( 1);
}


// https://stackoverflow.com/questions/1656410/strip-non-alphanumeric-characters-from-an-nsstring

static NSString   *makeMacroName( NSString *s)
{
   NSCharacterSet   *set;

   set = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
   s   = [[s componentsSeparatedByCharactersInSet:set] componentsJoinedByString:@"_"];

   s   = [NSString externalNameForInternalName:s
                                 separatorString:@"_"
                                      useAllCaps:YES];
   return( [s uppercaseString]);
}


static NSString   *quotedPathIfNeeded( NSString *s)
{
   NSCharacterSet   *set;
   
   if( hackPrefix)
      s = [hackPrefix stringByAppendingString:s];
   
   set = [NSCharacterSet whitespaceCharacterSet];
   if( [s rangeOfCharacterFromSet:set].length == 0)
      return( s);
   return( [NSString stringWithFormat:@"\"%@\"", s]);
}



static PBXTarget   *find_target_by_name( PBXProject *root, NSString *name)
{
   NSEnumerator   *rover;
   PBXTarget      *pbxtarget;

   rover = [[root targets] objectEnumerator];
   while( pbxtarget = [rover nextObject])
      if( [[pbxtarget name] isEqualToString:name])
         break;

   return( pbxtarget);
}


static NSArray   *all_target_names( PBXProject *root)
{
   return( [[root targets] valueForKey:@"name"]);
}


enum Command
{
   Export,
   List
};


static void  fail( NSString *format, ...)
{
   va_list   args;

   va_start( args, format);
   NSLogv( format, args);
   va_end( args);

   exit( 1);
}



static void   export_files( NSArray *files,
                            NSString *name,
                            enum Command cmd,
                            BOOL isHeader)
{
   NSEnumerator      *rover;
   PBXBuildFile      *file;
   PBXFileReference  *reference;
   NSString          *path;
   NSString          *dir;

   if( cmd == Export)
   {
      printf( "\nset( %s\n", [name UTF8String]);
   }

   rover = [files objectEnumerator];
   while( file = [rover nextObject])
   {
      reference = [file fileRef];
      path      = [reference sourceTreeRelativeFilesystemPath];
      if( ! path)
         path = [reference displayName]; // hack (should be path)
      else
         if( isHeader)
         {
            dir = [path stringByDeletingLastPathComponent];
            if( ! [dir length])
               dir = @".";  // needed when subdir does include
            addHeaderDirectory( dir);
         }
      printf( "%s\n", [quotedPathIfNeeded( path) UTF8String]);
   }

   if( cmd == Export)
      printf( ")\n");
}


static void   export_headers_phase( PBXHeadersBuildPhase *pbxphase,
                                   enum Command cmd,
                                   NSString *prefix)
{
   NSString  *name;

   name = @"PUBLIC_HEADERS";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   export_files( [pbxphase publicHeaders], name, cmd, YES);

   name = @"PROJECT_HEADERS";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   export_files( [pbxphase projectHeaders], name, cmd, YES);

   name = @"PRIVATE_HEADERS";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   export_files( [pbxphase privateHeaders], name, cmd, YES);
}


static void   export_sources_phase( PBXSourcesBuildPhase *pbxphase,
                                    enum Command cmd,
                                    NSString *prefix)
{
   NSString  *name;

   name = @"SOURCES";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   export_files( [pbxphase files], name, cmd, NO);
}


static void   export_resources_phase( PBXResourcesBuildPhase *pbxphase,
                                      enum Command cmd,
                                      NSString *prefix)
{
   NSString  *name;

   name = @"RESOURCES";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   export_files( [pbxphase files], name, cmd, NO);
}


// not proud of this.. :)
static void   collect_libraries( PBXFrameworksBuildPhase *pbxphase,
                                 BOOL isStatic)
{
   NSEnumerator      *rover;
   PBXBuildFile      *file;
   PBXFileReference  *reference;
   NSString          *path;
   NSString          *libraryName;

   rover = [[pbxphase files] objectEnumerator];
   while( file = [rover nextObject])
   {
      reference = [file fileRef];
      path      = [[reference path] lastPathComponent];
      path      = [path stringByDeletingPathExtension];
      if( [path hasPrefix:@"lib"])
         path = [path substringFromIndex:3];

      libraryName = makeMacroName( path);

      if( [[[reference path] pathExtension] isEqualToString:@"a"])
      {
         if( isStatic)
            addStaticLibrariesToFind( path, libraryName);
      }
      else
         if( ! isStatic)
         {
            addSharedLibrariesToFind( path, libraryName);
         }
   }
}


// not proud of this.. :)
static void   export_libraries( NSDictionary *libraries,
                                NSString *prefix,
                                BOOL isStatic)
{
   NSEnumerator      *rover;
   NSString          *path;
   NSString          *name;
   NSString          *libraryName;

   name = isStatic ? @"STATIC_DEPENDENCIES" : @"DEPENDENCIES";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];

   printf( "\nset( %s\n", [name UTF8String]);

   rover = [[[libraries allKeys] sortedArrayUsingSelector:@selector( compare:)] objectEnumerator];
   while( path = [rover nextObject])
   {
      libraryName = [libraries objectForKey:path];
      printf( "${%s_LIBRARY}\n", [libraryName UTF8String]);
   }

   printf( ")\n");
}


static void   export_find_libraries( NSDictionary *libraries)
{
   NSArray        *keys;
   NSEnumerator   *rover;
   NSString       *key;
   NSString       *library;

   keys = [[libraries allKeys] sortedArrayUsingSelector:@selector( compare:)];
   if( [keys count])
      printf( "\n");

   rover = [keys objectEnumerator];
   while( key = [rover nextObject])
   {
      library = [libraries objectForKey:key];
      printf( "find_library( %s_LIBRARY %s)\n", [library UTF8String], [key UTF8String]);
   }
}

static void   export_frameworks_phase( PBXFrameworksBuildPhase *pbxphase,
                                       enum Command cmd,
                                       NSString *prefix)
{
   collect_libraries( pbxphase, YES);
   collect_libraries( pbxphase, NO);

   export_find_libraries( staticLibraries);
   export_libraries( staticLibraries, prefix, YES);

   export_find_libraries( sharedLibraries);
   export_libraries( sharedLibraries, prefix, NO);
}


static void   export_phase( PBXBuildPhase *pbxphase,
                            enum Command cmd,
                            NSString *prefix)
{
   if( verbose)
      fprintf( stderr, "%s: %s\n", [NSStringFromClass( [pbxphase class]) UTF8String], [[pbxphase name] UTF8String]);

   if( [pbxphase isKindOfClass:[PBXHeadersBuildPhase class]])
   {
      export_headers_phase( (PBXHeadersBuildPhase *) pbxphase, cmd, prefix);
      return;
   }

   if( [pbxphase isKindOfClass:[PBXSourcesBuildPhase class]])
   {
      export_sources_phase( (PBXSourcesBuildPhase *) pbxphase, cmd, prefix);
      return;
   }

   if( [pbxphase isKindOfClass:[PBXResourcesBuildPhase class]])
   {
      export_resources_phase( (PBXResourcesBuildPhase *) pbxphase, cmd, prefix);
      return;
   }

   if( [pbxphase isKindOfClass:[PBXFrameworksBuildPhase class]])
   {
      export_frameworks_phase( (PBXFrameworksBuildPhase *) pbxphase, cmd, prefix);
      return;
   }
}


static void   add_implicit_frameworks_if_needed( PBXTarget *pbxtarget)
{
   BOOL       addFoundation;
   BOOL       addUIKit;
   NSString   *type;

   type = [[[pbxtarget productType] componentsSeparatedByString:@".product-type."] lastObject];

   addFoundation = suppressFoundation ? NO : YES;
   addUIKit      = suppressUIKit ? NO : YES;

   if( [type hasPrefix:@"library"])
   {
      addFoundation = NO;
      addUIKit = NO;
   }

   if( addFoundation)
      addSharedLibrariesToFind( @"Foundation", @"FOUNDATION");

   if( addUIKit)
      addSharedLibrariesToFind( @"UIKit", @"UI_KIT");
}


static void   file_exporter( PBXTarget *pbxtarget,
                             enum Command cmd,
                             BOOL multipleTargets)
{
   PBXBuildPhase   *phase;
   NSEnumerator    *rover;

   if( verbose)
      fprintf( stderr, "target: %s\n", [[pbxtarget name] UTF8String]);

   if( cmd == List)
   {
      printf( "%s\n", [[pbxtarget name] UTF8String]);
      return;
   }

   add_implicit_frameworks_if_needed( pbxtarget);

   rover = [[pbxtarget buildPhases] objectEnumerator];
   while( phase = [rover nextObject])
   {
      export_phase( phase, cmd, multipleTargets ? makeMacroName( [pbxtarget name]) : nil);
   }
}


static void   export_dependency( PBXTargetDependency *pbxdependency,
                                 enum Command cmd,
                                 PBXTarget *pbxtarget,
                                 NSArray *targets)
{
   PBXTarget *dsttarget;

   if( verbose)
      fprintf( stderr, "%s: %s\n", [NSStringFromClass( [pbxdependency class]) UTF8String], [[pbxdependency name] UTF8String]);

   if( cmd != Export)
      return;

   dsttarget = [pbxdependency target];
   if( ! dsttarget)
   {
      if( verbose)
         fprintf( stderr, "mulle-xcode-to-cmake: can not deal with %s using it's name\n", [[pbxdependency debugDescription] UTF8String]);
      return;
   }

   if( ! [targets containsObject:dsttarget])
   {
      fprintf( stderr, "mulle-xcode-to-cmake: can not export dependency to target %s as it is not exported\n", [[dsttarget name] UTF8String]);
      return;
   }

   printf( "\nadd_dependencies( %s %s)\n",
          [[pbxtarget name] UTF8String],
          [[dsttarget name] UTF8String]);
}


static void   print_prefixed_variable_expansion( NSString *name, NSString *prefix, BOOL flag)
{
   if( flag)
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   printf( "${%s}\n", [name UTF8String]);
}

static void   export_target_include_directories( char *s_target_name)
{
   NSEnumerator   *rover;
   NSString       *path;

   printf( "\n"
"target_include_directories( %s\n"
"   PUBLIC\n",
      s_target_name);

   rover = [[[headerDirectories allObjects] sortedArrayUsingSelector:@selector( compare:)] objectEnumerator];
   while( path = [rover nextObject])
      printf( "      %s\n", [quotedPathIfNeeded( path) UTF8String]);
   printf( ")\n");
}


static void   export_target_link_libraries( char *s_target_name, NSString *macroName, BOOL multipleTargets)
{
   NSString   *staticName;
   NSString   *name;
   char       *format;

   staticName = @"STATIC_DEPENDENCIES";
   if( multipleTargets)
      staticName = [NSString stringWithFormat:@"%@_%@", macroName, staticName];

   name = @"DEPENDENCIES";
   if( multipleTargets)
      name = [NSString stringWithFormat:@"%@_%@", macroName, name];

   if( ! suppressBoilerplate)
      format = "\ntarget_link_libraries( %s\n"
"${BEGIN_ALL_LOAD}\n"
"${%s}\n"
"${END_ALL_LOAD}\n"
"${%s}\n"
")\n";
   else
      format = "\ntarget_link_libraries( %s\n"
"${%s}\n"
"${%s}\n"
")\n";

   printf( format,
         s_target_name,
         [staticName UTF8String],
         [name UTF8String]);
}


enum TargetType
{
   StaticLibrary,
   SharedLibrary,
   Bundle,
   Framework,
   Tool,
   Application,
   Unknown
};


static enum TargetType   get_target_type( PBXTarget *pbxtarget)
{
   NSString   *fullType;
   NSString   *type;

   fullType = [pbxtarget productType];
   type     = [[fullType componentsSeparatedByString:@".product-type."] lastObject];

   if( [type isEqualToString:@"library.static"])
      return( StaticLibrary);
   if( [type hasPrefix:@"library"])
      return( SharedLibrary);
   if( [type hasPrefix:@"framework"])
      return( Framework);
   if( [type hasPrefix:@"bundle"])
      return( Bundle);
   if( [type hasPrefix:@"tool"])
      return( Tool);
   if( [type hasPrefix:@"application"])
      return( Application);

   fprintf( stderr, "mulle-xcode-to-cmake:unknown target type %s, assuming it's a kind of application\n", [fullType UTF8String]);
   return( Unknown);
}


static void   target_exporter( PBXTarget *pbxtarget,
                               enum Command cmd,
                               NSArray *targets)
{
   PBXTargetDependency   *dependency;
   NSEnumerator          *rover;
   NSString              *headersName;
   NSString              *resourcesName;
   NSString              *macroName;
   char                  *s_target_name;
   BOOL                  multipleTargets;
   enum TargetType       targetType;

   multipleTargets = [targets count] >= 2;

   s_target_name = [[pbxtarget name] UTF8String];
   if( verbose)
      fprintf( stderr, "target: %s\n", s_target_name);

   macroName   = makeMacroName( [pbxtarget name]);
   targetType = get_target_type( pbxtarget);

   switch( targetType)
   {
   case StaticLibrary :
      printf( "\n"
              "add_library( %s STATIC\n", s_target_name);
      break;

   case SharedLibrary :
   case Framework     :
      printf( "\n"
              "add_library( %s SHARED\n", s_target_name);
      break;

   default     :
      printf( "\n"
              "add_executable( %s MACOSX_BUNDLE\n", s_target_name);
   }

   print_prefixed_variable_expansion( @"SOURCES", macroName, multipleTargets);
   print_prefixed_variable_expansion( @"PUBLIC_HEADERS", macroName, multipleTargets);
   print_prefixed_variable_expansion( @"PROJECT_HEADERS", macroName, multipleTargets);
   print_prefixed_variable_expansion( @"PRIVATE_HEADERS", macroName, multipleTargets);

   printf( ")\n");

   export_target_include_directories( s_target_name);

   rover = [[pbxtarget dependencies] objectEnumerator];
   while( dependency = [rover nextObject])
      export_dependency( dependency, cmd, pbxtarget, targets);

   export_target_link_libraries( s_target_name, macroName, multipleTargets);

   headersName = @"PUBLIC_HEADERS";
   if( multipleTargets)
      headersName = [NSString stringWithFormat:@"%@_%@", macroName, headersName];

   resourcesName = @"RESOURCES";
   if( multipleTargets)
      resourcesName = [NSString stringWithFormat:@"%@_%@", macroName, resourcesName];

   switch( targetType)
   {
   case StaticLibrary :
   case SharedLibrary :
   case Framework :
   case Tool :
      break;

   default     :
      printf( "\n"
              "set_source_files_properties(\n"
"${%s}\n"
"   PROPERTIES\n"
"      MACOSX_PACKAGE_LOCATION\n"
"      Resources\n"
")\n",
         [resourcesName UTF8String]);
   }


   switch( targetType)
   {
   case Framework :
      printf( "\n"
"if (APPLE)\n"
"   set_target_properties( %s PROPERTIES\n"
"FRAMEWORK TRUE\n"
"FRAMEWORK_VERSION A\n"
"# MACOSX_FRAMEWORK_IDENTIFIER \"com.mulle-kybernetik.%s\"\n"
"# VERSION \"0.0.0\"\n"
"# SOVERSION  \"0.0.0\"\n"
"PUBLIC_HEADER \"${%s}\"\n"
"RESOURCE \"${%s}\"\n"
")\n"
"\n"
"   install( TARGETS %s DESTINATION \"Frameworks\")\n"
"endif()\n",
         s_target_name,
         s_target_name,
         [headersName UTF8String],
         [resourcesName UTF8String],
         s_target_name);
      break;

   case Application   :
   case Bundle        :
   case Unknown       :
      printf( "\n"
"if (APPLE)\n"
"   set_target_properties( %s PROPERTIES\n"
"MACOSX_BUNDLE_INFO_PLIST \"${CMAKE_CURRENT_SOURCE_DIR}/%s-Info.plist.in\"\n"
")\n"
"endif()\n",
         s_target_name,
         s_target_name);

      fprintf( stderr, "You can use this text as %s-Info.plist.in contents:\n"
"cat <<EOF > %s-Info.plist.in\n"
"%s", s_target_name,
      s_target_name,
      head_MacOSXBundleInfo);

      fprintf( stderr,
"   <key>CFBundlePackageType</key>\n"
"   <string>%s</string>\n", targetType == Bundle ? "BNDL" : "APPL");


      if( targetType == Application)
         fprintf( stderr,
"   <key>NSPrincipalClass</key>\n"
"   <string>NSApplication</string>\n"
"   <key>NSMainNibFile</key>\n"
"   <string>MainMenu</string>\n");

      fprintf( stderr, "%s"
"EOF\n",
         tail_MacOSXBundleInfo);

      break;

   case SharedLibrary :
   case StaticLibrary :
      printf( "\n"
"install( TARGETS %s DESTINATION \"lib\")\n"
"install( FILES ${%s} DESTINATION \"include/%s\")\n",
         s_target_name,
         [headersName UTF8String],
         s_target_name);
   default:
      break;
   }
}



static void   exporter( PBXProject *root,
                        enum Command cmd,
                        NSArray  *targetNames,
                        NSString *file)
{
   PBXTarget       *pbxtarget;
   NSEnumerator    *rover;
   BOOL            multipleTargets;
   NSString        *name;
   NSMutableArray  *targets;
   NSMutableArray  *others;

   targets = [NSMutableArray array];
   rover = [targetNames objectEnumerator];
   while( name = [rover nextObject])
   {
      pbxtarget = find_target_by_name( root, name);
      if( ! pbxtarget)
         fail( @"target \"%@\" not found", name);
      [targets addObject:pbxtarget];
   }

   multipleTargets = [targets count] > 1;

   if( cmd == Export)
   {
      if( ! suppressProject)
      {
         printf( "project( %s)\n", targets && ! multipleTargets
            ? [[targetNames lastObject] UTF8String] // tiny bug
            : [[[[file stringByDeletingLastPathComponent] lastPathComponent] stringByDeletingPathExtension] UTF8String]);
         //
         // cross platform wise 3.4 gave me the least trouble
         //
         printf( "\ncmake_minimum_required (VERSION 3.4)\n");
      }

      if( ! suppressBoilerplate)
      {
         printf( "\n"
"#\n"
"# mulle-bootstrap environment\n"
"#\n"
"\n"
"# check if compiling with mulle-bootstrap (works since 2.6)\n"
"\n"
"if( NOT MULLE_BOOTSTRAP_VERSION)\n"
"  include_directories( BEFORE SYSTEM\n"
"dependencies/include\n"
"addictions/include\n"
")\n"
"\n"
"  set( CMAKE_FRAMEWORK_PATH\n"
"dependencies/Frameworks\n"
"addictions/Frameworks\n"
"${CMAKE_FRAMEWORK_PATH}\n"
")\n"
"\n"
"  set( CMAKE_LIBRARY_PATH\n"
"dependencies/lib\n"
"addictions/lib\n"
"${CMAKE_LIBRARY_PATH}\n"
")\n"
"\n"
"endif()\n"
"\n");
      }

      if( ! suppressBoilerplate)
      {
         printf( "\n"
"#\n"
"# Platform specific definitions\n"
"#\n"
"\n"
"if( APPLE)\n"
"   # # CMAKE_OSX_SYSROOT must be set for CMAKE_OSX_DEPLOYMENT_TARGET (cmake bug)\n"
"   # if( NOT CMAKE_OSX_SYSROOT)\n"
"   #    set( CMAKE_OSX_SYSROOT \"/\" CACHE STRING \"SDK for OSX\" FORCE)   # means current OS X\n"
"   # endif()\n"
"   #\n"
"   # # baseline set to 10.6 for rpath\n"
"   # if( NOT CMAKE_OSX_DEPLOYMENT_TARGET)\n"
"   #   set(CMAKE_OSX_DEPLOYMENT_TARGET \"10.6\" CACHE STRING \"Deployment target for OSX\" FORCE)\n"
"   # endif()\n"
"\n"
"   set( CMAKE_POSITION_INDEPENDENT_CODE FALSE)\n"
"\n"
"   set( BEGIN_ALL_LOAD \"-all_load\")\n"
"   set( END_ALL_LOAD)\n"
"else()\n"
"   set( CMAKE_POSITION_INDEPENDENT_CODE TRUE)\n"
"\n"
"   if( WIN32)\n"
"   # windows\n"
"   else()\n"
"   # linux / gcc\n"
"      set( BEGIN_ALL_LOAD \"-Wl,--whole-archive\")\n"
"      set( END_ALL_LOAD \"-Wl,--no-whole-archive\")\n"
"   endif()\n"
"endif()\n");
      }
   }

   rover = [targets objectEnumerator];
   while( pbxtarget = [rover nextObject])
   {
      if( cmd == Export)
      {
         printf( "\n"
                "##\n"
                "## %s Files\n"
                "##\n", [[pbxtarget name] UTF8String]);
      }
      file_exporter( pbxtarget, cmd, multipleTargets);
   }

   // ugliness ensues...

   if( cmd == List)
      return;

   others = nil;
   rover = [targets objectEnumerator];
   while( pbxtarget = [rover nextObject])
   {
      if( cmd == Export && multipleTargets)
      {
         printf( "\n"
                "##\n"
                "## %s\n"
                "##\n", [[pbxtarget name] UTF8String]);
      }

      target_exporter( pbxtarget, cmd, targets);
   }
}


static NSString  *backupPathForPath( NSString *file)
{
   NSString  *ext;
   NSString  *dir;
   NSString  *name;

   dir  = [file stringByDeletingLastPathComponent];
   name = [file lastPathComponent];
   ext  = [name pathExtension];
   name = [name stringByDeletingPathExtension];
   name = [name stringByAppendingString:@"~"];
   name = [name stringByAppendingPathExtension:ext];
   file = [dir stringByAppendingPathComponent:name];
   return( file);
}


static void   writeStringToPath( NSString *s, NSString *file)
{
   NSString        *backupFile;
   NSFileManager   *manager;
   NSError         *error;

   backupFile = backupPathForPath( file);
   manager    = [NSFileManager defaultManager];

   [manager removeItemAtPath:backupFile
                       error:&error];
   if( ! [manager moveItemAtPath:file
                          toPath:backupFile
                           error:&error])
      fail( @"failed to backup %@", file);

   if( ! [s writeToFile:file
             atomically:YES
               encoding:NSUTF8StringEncoding
                  error:&error])
      fail( @"failed to write %@: %@", [error localizedFailureReason]);
}


static int   _main( int argc, const char * argv[])
{
   NSArray         *arguments;
   NSString        *configuration;
   NSString        *file;
   NSString        *s;
   NSString        *target;
   id              root;
   unsigned int    i, n;
   id              targetNames;

   configuration = nil;
   target        = nil;
   verbose       = getenv( "VERBOSE") ? YES : NO;
   targetNames   = nil;

   arguments = [[NSProcessInfo processInfo] arguments];
   n         = [arguments count];

   if( [arguments containsObject:@"-v"] || [arguments containsObject:@"--version"] || [arguments containsObject:@"-version"])
   {
      fprintf( stderr, "v%s\n", CURRENT_PROJECT_VERSION);
      return( 0);
   }

   if( [arguments containsObject:@"-h"] || [arguments containsObject:@"--help"] || [arguments containsObject:@"-help"])
      usage();

   file = [arguments lastObject];
   if( ! --n)
      usage();

   if( [[file pathExtension] isEqualToString:@"xcodeproj"])
      file = [file stringByAppendingPathComponent:@"project.pbxproj"];

   root = [MullePBXUnarchiver unarchiveObjectWithFile:&file];
   if( ! root)
      fail( @"File %@ is not a PBX (Xcode) file", file);

   for( i = 1; i < n; i++)
   {
      s = [arguments objectAtIndex:i];

      if( [s isEqualToString:@"-b"] ||
          [s isEqualToString:@"--no-boilerplate"])
      {
         suppressBoilerplate = YES;
         continue;
      }

      if( [s isEqualToString:@"-p"] ||
          [s isEqualToString:@"--no-project"])
      {
         suppressProject = YES;
         continue;
      }

      if( [s isEqualToString:@"-u"] ||
          [s isEqualToString:@"--add-uikit"])
      {
         suppressUIKit = NO;
         continue;
      }

      if( [s isEqualToString:@"-f"] ||
          [s isEqualToString:@"--no-foundation"])
      {
         suppressFoundation = YES;
         continue;
      }

      if( [s isEqualToString:@"--hack-paths"])
      {
         if( ++i >= n)
            usage();

         hackPrefix = [arguments objectAtIndex:i];
         continue;
      }

      if( [s isEqualToString:@"-t"] ||
          [s isEqualToString:@"-target"] ||
          [s isEqualToString:@"--target"])
      {
         if( ++i >= n)
            usage();

         target = [arguments objectAtIndex:i];
         if( ! targetNames)
            targetNames = [NSMutableArray array];
         [targetNames addObject:target];
         continue;
      }

      // commands
      if( ! targetNames)
         targetNames = all_target_names( root);

      if( [s isEqualToString:@"export"])
      {
         exporter( root, Export, targetNames, file);
         break;
      }

      if( [s isEqualToString:@"list"])
      {
         exporter( root, List, targetNames, file);
         break;
      }

      NSLog( @"unknown command %@", s);
      usage();
   }

   return( 0);
}


int   main( int argc, const char * argv[])
{
   NSAutoreleasePool   *pool;
   int                 rval;

   pool = [NSAutoreleasePool new];
   rval = _main( argc, argv);
   [pool release];
   return( rval);
}
