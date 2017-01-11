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


#pragma mark Types

enum Command
{
   Export,
   List
};


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


#pragma mark - Static Strings

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



#pragma mark - Global Configuration

static BOOL   verbose;
static BOOL   alwaysPrefix;
static BOOL   dualLibrary;
static BOOL   suppressBoilerplate;
static BOOL   suppressProject;
static BOOL   suppressFoundation;
static BOOL   suppressUIKit = YES;

static NSString  *hackPrefix = @"";
static NSString  *standaloneSuffix = nil;


#pragma mark - Global Storage

static NSMutableDictionary  *staticLibraries;
static NSMutableDictionary  *sharedLibraries;
static NSMutableSet         *headerDirectories;


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

#pragma mark - Usage

static void   usage()
{
   fprintf( stderr,
           "usage: mulle-xcode-to-cmake [options] <commands> <file.xcodeproj>\n"
           "\n"
           "Options:\n"
           ""
           "\t-a          : always prefix cmake variables with target\n"
           "\t-b          : suppress boilerplate definitions\n"
           "\t-d          : create static and shared library\n"
           "\t-f          : suppress Foundation (implicitly added)\n"
           "\t-p          : suppress project\n"
           "\t-s <suffix> : create standalone test library (framework/shared)\n"
           "\t-t <target> : target to export\n"
           "\t-u          : add UIKIt\n"
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


#pragma mark - Utilities

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


static void  fail( NSString *format, ...)
{
   va_list   args;

   va_start( args, format);
   NSLogv( format, args);
   va_end( args);

   exit( 1);
}


#pragma mark - Print

static void   print_boilerplate( void)
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
          "set( DEPENDENCIES_DIR dependencies)\n"
          "set( ADDICTIONS_DIR addictions)\n"
          "\n"
          "endif()\n"
          "\n");
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


static void   print_files_header_comment( NSString *name)
{
   printf( "\n"
           "\n"
           "##\n"
           "## %s Files\n"
           "##\n", [name UTF8String]);
}


static void   print_target_header_comment( NSString *name)
{
   printf( "\n"
           "\n"
           "##\n"
           "## %s\n"
           "##\n", [name UTF8String]);
}


static void   print_paths( NSArray *paths,
                           NSString *name)
{
   NSEnumerator      *rover;
   NSString          *path;
   
   printf( "\n"
          "set( %s\n", [name UTF8String]);

   rover = [[paths sortedArrayUsingSelector:@selector( compare:)] objectEnumerator];
   while( path = [rover nextObject])
      printf( "%s\n", [quotedPathIfNeeded( path) UTF8String]);

   printf( ")\n");
}


static void   print_files( NSArray *files,
                           NSString *name,
                           enum Command cmd,
                           BOOL isHeader)
{
   NSEnumerator      *rover;
   NSMutableArray    *paths;
   NSString          *dir;
   NSString          *path;
   PBXBuildFile      *file;
   PBXFileReference  *reference;
   
   paths = [NSMutableArray array];
   
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

      [paths addObject:path];
   }
   
   print_paths( paths, name);
}



static NSString  *generate_library_variablename( NSString *prefix, BOOL isStatic)
{
   NSString   *name;
   
   name = isStatic ? @"STATIC_DEPENDENCIES" : @"DEPENDENCIES";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   return( name);
}


static void   print_libraries( NSArray *libraries,
                              NSString *prefix,
                              BOOL isStatic)
{
   NSEnumerator      *rover;
   NSString          *path;
   NSString          *name;
   
   name = generate_library_variablename( prefix, isStatic);
   
   printf( "\nset( %s\n", [name UTF8String]);
   
   rover = [[libraries sortedArrayUsingSelector:@selector( compare:)] objectEnumerator];
   while( path = [rover nextObject])
   {
      printf( "${%s_LIBRARY}\n", [path UTF8String]);
   }
   
   printf( ")\n");
}



static void   print_find_library( NSDictionary *libraries)
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
      printf( "find_library( %s_LIBRARY %s)\n",
               [library UTF8String], [key UTF8String]);
   }
}


static void   print_prefixed_variable_expansion( char *name, char *prefix, BOOL flag)
{

if( flag)
   {
      name = printf( "${%s_%s}\n", prefix, name);
      return;
   }
   printf( "${%s}\n", name);
}


#pragma mark - PrintContext

struct printcontext
{
   PBXTarget             *pbxtarget;
   char                  *s_target_name;
   enum TargetType       targetType;
   
   NSString              *macroName;
   char                  *s_macro_name;
   
   BOOL                  multipleTargets;
};


static void   printcontext_target_include_directories( struct printcontext *ctxt)
{
   NSEnumerator   *rover;
   NSString       *path;
   
   printf( "\n"
          "target_include_directories( %s\n"
          "   PUBLIC\n",
          ctxt->s_target_name);
   
   rover = [[[headerDirectories allObjects] sortedArrayUsingSelector:@selector( compare:)] objectEnumerator];
   while( path = [rover nextObject])
      printf( "      %s\n", [quotedPathIfNeeded( path) UTF8String]);
   printf( ")\n");
}


static void   _printcontext_target_link_libraries( struct printcontext *ctxt,
                                                   NSString *staticName,
                                                   NSString *name)
{
   char   *format;

   if( ! suppressBoilerplate)
      format = "\n"
      "target_link_libraries( %s\n"
      "${BEGIN_ALL_LOAD}\n"
      "${%s}\n"
      "${END_ALL_LOAD}\n"
      "${%s}\n"
      ")\n";
   else
      format = "\n"
      "target_link_libraries( %s\n"
      "${%s}\n"
      "${%s}\n"
      ")\n";
   
   printf( format,
          ctxt->s_target_name,
          [staticName UTF8String],
          [name UTF8String]);
}


static void   printcontext_target_link_libraries( struct printcontext *ctxt)
{
   NSString   *staticName;
   NSString   *name;
   
   if( ctxt->targetType == StaticLibrary)
      return;
   
   staticName = @"STATIC_DEPENDENCIES";
   if( ctxt->multipleTargets)
      staticName = [NSString stringWithFormat:@"%@_%@", ctxt->macroName, staticName];
   
   name = @"DEPENDENCIES";
   if( ctxt->multipleTargets)
      name = [NSString stringWithFormat:@"%@_%@", ctxt->macroName, name];
   
   _printcontext_target_link_libraries( ctxt, staticName, name);
}


static void   printcontext_add_dependencies( struct printcontext *ctxt,
                                             PBXTargetDependency *pbxdependency,
                                             NSArray *targets)
{
   PBXTarget *dsttarget;
   
   if( verbose)
      fprintf( stderr, "%s: %s\n", [NSStringFromClass( [pbxdependency class]) UTF8String], [[pbxdependency name] UTF8String]);
   
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
   
   printf( "\n"
          "add_dependencies( %s %s)\n",
          [[ctxt->pbxtarget name] UTF8String],
          [[dsttarget name] UTF8String]);
}


static void   printcontext_target_dependencies( struct printcontext *ctxt,
                                                NSArray *targets)
{
   NSEnumerator          *rover;
   PBXTargetDependency   *dependency;

   rover = [[ctxt->pbxtarget dependencies] objectEnumerator];
   while( dependency = [rover nextObject])
      printcontext_add_dependencies( ctxt, dependency, targets);
}


static void   printcontext_source_files_properties( struct printcontext *ctxt)
{
   NSString  *resourcesName;

   switch( ctxt->targetType)
   {
   case StaticLibrary :
   case SharedLibrary :
   case Framework     :
   case Tool          :
      return;
   }
   
   resourcesName = @"RESOURCES";
   if( ctxt->multipleTargets)
      resourcesName = [NSString stringWithFormat:@"%@_%@", ctxt->macroName, resourcesName];
   
   printf( "\n"
          "set_source_files_properties(\n"
          "${%s}\n"
          "   PROPERTIES\n"
          "      MACOSX_PACKAGE_LOCATION\n"
          "      Resources\n"
          ")\n",
          [resourcesName UTF8String]);
}


static void   printcontext_target_properties( struct printcontext *ctxt)
{
   NSString   *headersName;
   NSString   *resourcesName;
   
   headersName = @"PUBLIC_HEADERS";
   if( ctxt->multipleTargets)
      headersName = [NSString stringWithFormat:@"%@_%@", ctxt->macroName, headersName];

   resourcesName = @"RESOURCES";
   if( ctxt->multipleTargets)
      resourcesName = [NSString stringWithFormat:@"%@_%@", ctxt->macroName, resourcesName];

   switch( ctxt->targetType)
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
                ctxt->s_target_name,
                ctxt->s_target_name,
                [headersName UTF8String],
                [resourcesName UTF8String],
                ctxt->s_target_name);
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
                ctxt->s_target_name,
                ctxt->s_target_name);
         
         fprintf( stderr, "You can use this text as %s-Info.plist.in contents:\n"
                 "cat <<EOF > %s-Info.plist.in\n"
                 "%s",
                 ctxt->s_target_name,
                 ctxt->s_target_name,
                 head_MacOSXBundleInfo);
         
         fprintf( stderr,
                 "   <key>CFBundlePackageType</key>\n"
                 "   <string>%s</string>\n",
                  ctxt->targetType == Bundle ? "BNDL" : "APPL");
         
         
         if( ctxt->targetType == Application)
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
                ctxt->s_target_name,
                [headersName UTF8String],
                ctxt->s_target_name);
      default:
         break;
   }
}


static void   printcontext_add_library( struct printcontext *ctxt,
                                        unsigned int bits)
{
   switch( ctxt->targetType)
   {
      case StaticLibrary :
         printf( "\n"
                "add_library( %s STATIC\n", ctxt->s_target_name);
         break;
         
      case SharedLibrary :
      case Framework     :
         printf( "\n"
                "add_library( %s SHARED\n", ctxt->s_target_name);
         break;
         
      default     :
         printf( "\n"
                "add_executable( %s MACOSX_BUNDLE\n", ctxt->s_target_name);
   }
   
   if( bits & 1)
      print_prefixed_variable_expansion( "SOURCES", ctxt->s_macro_name, ctxt->   multipleTargets);
   if( bits & 2)
      print_prefixed_variable_expansion( "PUBLIC_HEADERS", ctxt->s_macro_name, ctxt->multipleTargets);
   if( bits & 4)
      print_prefixed_variable_expansion( "PROJECT_HEADERS", ctxt->s_macro_name, ctxt->multipleTargets);
   if( bits & 8)
      print_prefixed_variable_expansion( "PRIVATE_HEADERS", ctxt->s_macro_name, ctxt->multipleTargets);
   
   printf( ")\n");
}


static void  printcontext_export_target( struct printcontext *ctxt,
                                        NSArray *targets)
{
   printcontext_add_library( ctxt, -1);
   printcontext_target_include_directories( ctxt);
   printcontext_target_dependencies( ctxt, targets);
   printcontext_target_link_libraries( ctxt);
   printcontext_source_files_properties( ctxt);
   printcontext_target_properties( ctxt);
}


#pragma mark - Exporter

//
// TODO: https://stackoverflow.com/questions/22278381/cmake-add-library-followed-by-install-library-destination?rq=1
//
static void   export_target( PBXTarget *pbxtarget,
                             NSArray *targets)
{
   struct printcontext   ctxt;
   struct printcontext   ctxt2;
   struct printcontext   ctxt3;
   NSString              *name;
   NSString              *s;
   NSString              *sharedName;
   BOOL                  multipleTargets;
   
   name = [pbxtarget name];
   
   multipleTargets      = alwaysPrefix ? YES : [targets count] >= 2;
   ctxt.pbxtarget       = pbxtarget;
   ctxt.multipleTargets = multipleTargets;
   ctxt.s_target_name   = [name UTF8String];
   ctxt.macroName       = makeMacroName( name);
   ctxt.s_macro_name    = [ctxt.macroName UTF8String];
   ctxt.targetType      = get_target_type( pbxtarget);

   if( verbose)
      fprintf( stderr, "target: %s\n", ctxt.s_target_name);

   if( (ctxt.targetType != SharedLibrary && ctxt.targetType != Framework) &&
       ! dualLibrary && ! standaloneSuffix)
   {
      print_target_header_comment( name);
      printcontext_export_target( &ctxt, targets);
      return;
   }

   if( ! dualLibrary && ! standaloneSuffix)
   {
      print_target_header_comment( name);
      printcontext_export_target( &ctxt, targets);
      return;
   }

   // if we convert to standalone, print static library first
   // then print shared library, that depends on static
   
   ctxt2 = ctxt;
   ctxt3 = ctxt;
   
   ctxt.targetType      = StaticLibrary;
   printcontext_export_target( &ctxt, targets);
   
   if( dualLibrary)
   {
      sharedName = [name stringByAppendingString:@"_shared"];

      ctxt3.targetType    = SharedLibrary;
      ctxt3.s_target_name = [sharedName UTF8String];


      // emit another add_library for shared
      print_target_header_comment( sharedName);
      printcontext_add_library( &ctxt3, 1);

      printf( "\n"
              "set_target_properties( %s\n"
              "   PROPERTIES\n"
              "   OUTPUT_NAME %s)\n"
              ")\n",
              ctxt3.s_target_name,
              ctxt.s_target_name);

      printf( "\n"
             "install( TARGETS %s DESTINATION \"lib\")\n",
             ctxt3.s_target_name);
   }

   if( ! standaloneSuffix)
      return;
   
   sharedName = [name stringByAppendingString:standaloneSuffix];
   
   ctxt2.multipleTargets = YES;
   ctxt2.s_target_name   = [sharedName UTF8String];
   ctxt2.macroName       = makeMacroName( sharedName);
   ctxt2.s_macro_name    = [ctxt2.macroName UTF8String];

   print_files_header_comment( sharedName);
   
   printf( "\n"
           "set( %s_SOURCES\n"
           "# add a dummy file here for cmake and the linker to be happy\n"
           ")\n",
           ctxt2.s_macro_name);

   print_libraries( [NSArray arrayWithObject:name], ctxt2.macroName, YES);
   
   s = generate_library_variablename( multipleTargets ? ctxt.macroName : nil, NO);
   s = [NSString stringWithFormat:@"${%@}", s];
   print_libraries( [NSArray arrayWithObject:s], ctxt2.macroName, NO);
   
   print_target_header_comment( sharedName);
   printcontext_add_library( &ctxt2, 1);
   
   printf( "\n"
          "add_dependencies( %s %s)\n",
          ctxt2.s_target_name,
          ctxt.s_target_name);
   
   printcontext_target_link_libraries( &ctxt2);
   
   printf( "\n"
           "install( TARGETS %s DESTINATION \"lib\")\n",
          ctxt2.s_target_name);
}


static void   export_headers_phase( PBXHeadersBuildPhase *pbxphase,
                                    enum Command cmd,
                                    NSString *prefix)
{
   NSString  *name;
   
   name = @"PUBLIC_HEADERS";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   print_files( [pbxphase publicHeaders], name, cmd, YES);
   
   name = @"PROJECT_HEADERS";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   print_files( [pbxphase projectHeaders], name, cmd, YES);
   
   name = @"PRIVATE_HEADERS";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   print_files( [pbxphase privateHeaders], name, cmd, YES);
}


static void   export_sources_phase( PBXSourcesBuildPhase *pbxphase,
                                   enum Command cmd,
                                   NSString *prefix)
{
   NSString  *name;
   
   name = @"SOURCES";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   print_files( [pbxphase files], name, cmd, NO);
}


static void   export_resources_phase( PBXResourcesBuildPhase *pbxphase,
                                      enum Command cmd,
                                      NSString *prefix)
{
   NSString  *name;
   
   name = @"RESOURCES";
   if( [prefix length])
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   print_files( [pbxphase files], name, cmd, NO);
}


static void   collect_libraries( PBXFrameworksBuildPhase *pbxphase,
                                BOOL isStatic)
{
   NSEnumerator       *rover;
   NSString           *libraryName;
   NSString           *path;
   PBXBuildFile       *file;
   PBXFileReference   *reference;
   
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


static void   export_frameworks_phase( PBXFrameworksBuildPhase *pbxphase,
                                       enum Command cmd,
                                       NSString *prefix)
{
   collect_libraries( pbxphase, YES);
   collect_libraries( pbxphase, NO);
   
   print_find_library( staticLibraries);
   print_libraries( [staticLibraries allValues], prefix, YES);
   
   print_find_library( sharedLibraries);
   print_libraries( [sharedLibraries allValues], prefix, NO);
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


static void   exporter( PBXProject *root,
                        enum Command cmd,
                        NSArray  *targetNames,
                        NSString *file)
{
   BOOL             multipleTargets;
   NSEnumerator     *rover;
   NSMutableArray   *others;
   NSMutableArray   *targets;
   NSString         *name;
   PBXTarget        *pbxtarget;

   targets = [NSMutableArray array];
   rover = [targetNames objectEnumerator];
   while( name = [rover nextObject])
   {
      pbxtarget = find_target_by_name( root, name);
      if( ! pbxtarget)
      {
         fail( @"target \"%@\" not found", name);
         return;
      }
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
         print_boilerplate();
   }

   rover = [targets objectEnumerator];
   while( pbxtarget = [rover nextObject])
   {
      if( cmd == Export)
         print_files_header_comment( [pbxtarget name]);
      file_exporter( pbxtarget, cmd, multipleTargets);
   }

   // ugliness ensues...

   if( cmd == List)
      return;

   others = nil;
   rover = [targets objectEnumerator];
   while( pbxtarget = [rover nextObject])
      export_target( pbxtarget, targets);
}


# pragma mark - main

static int   _main( int argc, const char * argv[])
{
   NSArray        *arguments;
   NSString       *configuration;
   NSString       *file;
   NSString       *s;
   NSString       *target;
   id             root;
   id             targetNames;
   unsigned int   i, n;

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

      if( [s isEqualToString:@"-a"] ||
          [s isEqualToString:@"--always-prefix"])
      {
         alwaysPrefix = YES;
         continue;
      }

      if( [s isEqualToString:@"-b"] ||
          [s isEqualToString:@"--no-boilerplate"])
      {
         suppressBoilerplate = YES;
         continue;
      }

      if( [s isEqualToString:@"-d"] ||
         [s isEqualToString:@"--dual"])
      {
         dualLibrary = YES;
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
      
      if( [s isEqualToString:@"-p"] ||
          [s isEqualToString:@"--no-project"])
      {
         suppressProject = YES;
         continue;
      }

      if( [s isEqualToString:@"-s"] ||
          [s isEqualToString:@"--standalone"])
      {
         if( ++i >= n)
            usage();
         
         standaloneSuffix = [arguments objectAtIndex:i];
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
      

      if( [s isEqualToString:@"-u"] ||
          [s isEqualToString:@"--add-uikit"])
      {
         suppressUIKit = NO;
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
