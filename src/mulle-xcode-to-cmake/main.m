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


static void   usage()
{
   fprintf( stderr,
           "usage: mulle-xcode-to-cmake [options] <commands> <file.xcodeproj>\n"
           "\n"
           "Options:\n"
           ""
           "\t-t <target> : target to export\n"
           "\t-b          : suppress boilerplate definitions\n"
           "\t-p          : suppress project\n"
           "\t-f          : suppress Foundation (implicitly added)\n"
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


static void   list_target_names( PBXProject *root)
{
   NSEnumerator   *rover;
   PBXTarget      *pbxtarget;
   
   printf( "Targets:\n");
   rover = [[root targets] objectEnumerator];
   while( pbxtarget = [rover nextObject])
      printf( "\t%s\n", [[pbxtarget name] UTF8String]);
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
      printf( "%s\n", [path UTF8String]);
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
   PBXBuildFile      *file;
   PBXFileReference  *reference;
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

   if( [pbxphase isKindOfClass:[PBXFrameworksBuildPhase class]])
   {
      export_frameworks_phase( (PBXFrameworksBuildPhase *) pbxphase, cmd, prefix);
      return;
   }
}


static void   add_foundation_if_needed( PBXTarget *pbxtarget)
{
   BOOL       addFoundation;
   NSString   *type;
   
   type = [[[pbxtarget productType] componentsSeparatedByString:@".product-type."] lastObject];
   
   addFoundation = suppressFoundation ? NO : YES;
   if( [type hasPrefix:@"library"])
      addFoundation = NO;
   
   if( addFoundation)
      addSharedLibrariesToFind( @"Foundation", @"FOUNDATION");
}


static void   file_exporter( PBXTarget *pbxtarget,
                             enum Command cmd,
                             BOOL all)
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
   
   add_foundation_if_needed( pbxtarget);
   
   rover = [[pbxtarget buildPhases] objectEnumerator];
   while( phase = [rover nextObject])
   {
      export_phase( phase, cmd, all ? makeMacroName( [pbxtarget name]) : nil);
   }
}


static void   export_dependency( PBXTargetDependency *pbxdependency,
                                 enum Command cmd,
                                 PBXTarget *pbxtarget)
{
   NSString  *dependencyCMakeName;
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
   
   printf( "\nadd_dependencies( %s %s);\n",
          [[pbxtarget name] UTF8String],
          [[dsttarget name] UTF8String]);
}


static void   print_prefixed_variable_expansion( NSString *name, NSString *prefix, BOOL flag)
{
   if( flag)
      name = [NSString stringWithFormat:@"%@_%@", prefix, name];
   printf( "${%s}\n", [name UTF8String]);
}


static void   target_exporter( PBXTarget *pbxtarget,
                               enum Command cmd,
                               BOOL all)
{
   PBXTargetDependency   *dependency;
   NSEnumerator          *rover;
   NSString              *name;
   NSString              *staticName;
   NSString              *type;
   NSString              *path;
   NSString              *macroName;
   char                  *format;
   
   if( verbose)
      fprintf( stderr, "target: %s\n", [[pbxtarget name] UTF8String]);
   
   macroName = makeMacroName( [pbxtarget name]);
   type      = [[[pbxtarget productType] componentsSeparatedByString:@".product-type."] lastObject];
   

   if( [type isEqualToString:@"library.static"])
   {
      printf( "\n"
              "add_library( %s STATIC\n", [[pbxtarget name] UTF8String]);
   }
   else
      if( [type hasPrefix:@"library"])
      {
         printf( "\n"
                 "add_library( %s SHARED\n", [[pbxtarget name] UTF8String]);
      }
      else
         if( [type hasPrefix:@"framework"])
         {
            printf( "\n"
                   "add_library( %s SHARED\n", [[pbxtarget name] UTF8String]);
         }
         else
         {
            printf( "\n"
                   "add_executable( %s\n", [[pbxtarget name] UTF8String]);
         }
   
   print_prefixed_variable_expansion( @"SOURCES", macroName, all);
   print_prefixed_variable_expansion( @"PUBLIC_HEADERS", macroName, all);
   print_prefixed_variable_expansion( @"PROJECT_HEADERS", macroName, all);
   print_prefixed_variable_expansion( @"PRIVATE_HEADERS", macroName, all);
   
   printf( ")\n");

   printf( "\n"
"target_include_directories( %s\n"
"   PUBLIC\n",
      [[pbxtarget name] UTF8String]);

   rover = [[[headerDirectories allObjects] sortedArrayUsingSelector:@selector( compare:)] objectEnumerator];
   while( path = [rover nextObject])
      printf( "      %s\n", [path UTF8String]);
   printf( ")\n");

  
   rover = [[pbxtarget dependencies] objectEnumerator];
   while( dependency = [rover nextObject])
      export_dependency( dependency, cmd, pbxtarget);
   
   staticName = @"STATIC_DEPENDENCIES";
   if( all)
      staticName = [NSString stringWithFormat:@"%@_%@", macroName, staticName];

   name = @"DEPENDENCIES";
   if( all)
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
         [[pbxtarget name] UTF8String],
         [staticName UTF8String],
         [name UTF8String]);
   
   name = @"PUBLIC_HEADERS";
   if( all)
      name = [NSString stringWithFormat:@"%@_%@", macroName, name];
   
   if( [type hasPrefix:@"framework"])
   {
      printf( "\n"
"if (APPLE)\n");

      if( ! suppressBoilerplate)
         printf(
"   set(BEGIN_ALL_LOAD \"-all_load\")\n"
"   set(END_ALL_LOAD)\n"
"\n");

         printf(
"   set_target_properties( %s PROPERTIES\n"
"FRAMEWORK TRUE\n"
"FRAMEWORK_VERSION A\n"
"# MACOSX_FRAMEWORK_IDENTIFIER \"com.mulle-kybernetik.%s\"\n"
"# VERSION \"0.0.0\"\n"
"# SOVERSION  \"0.0.0\"\n"
"PUBLIC_HEADER \"${%s}\"\n"
")\n"
"\n"
"   install( TARGETS %s DESTINATION \"Frameworks\")\n"
"endif()\n",
         [[pbxtarget name] UTF8String],
         [[pbxtarget name] UTF8String],
         [name UTF8String],
         [[pbxtarget name] UTF8String]);
   }
   else
      if( [type hasPrefix:@"library"])
      {
         printf( "\n"
"install( TARGETS %s DESTINATION \"lib\")\n"
"install( FILES ${%s} DESTINATION \"include/%s\")\n",
         [[pbxtarget name] UTF8String],
         [name UTF8String],
         [[pbxtarget name] UTF8String]);
      }
}



static void   exporter( PBXProject *root,
                        enum Command cmd,
                        NSString *target,
                        NSString *file)
{
   PBXTarget                        *pbxtarget;
   PBXObjectWithConfigurationList   *obj;
   NSEnumerator                     *rover;

   if( cmd == Export)
   {
      if( ! suppressProject)
      {
         printf( "project( %s)\n", target
            ? [target UTF8String]
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
"   # \n"
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

   if( target)
   {
      pbxtarget = find_target_by_name( root, target);
      if( ! pbxtarget)
         fail( @"target \"%@\" not found", target);
      file_exporter( pbxtarget, cmd, NO);
   }
   else
   {
      rover = [[root targets] objectEnumerator];
      while( pbxtarget = [rover nextObject])
      {
         if( cmd == Export)
         {
            printf( "\n"
                   "##\n"
                   "## %s Files\n"
                   "##\n", [[pbxtarget name] UTF8String]);
         }
         file_exporter( pbxtarget, cmd, YES);
      }
   }
   
   // ugliness ensues...
   
   if( cmd == List)
      return;

   if( target)
   {
      pbxtarget = find_target_by_name( root, target);
      if( ! pbxtarget)
         fail( @"target \"%@\" not found", target);
      target_exporter( pbxtarget, cmd, NO);
   }
   else
   {
      rover = [[root targets] objectEnumerator];
      while( pbxtarget = [rover nextObject])
      {
         if( cmd == Export)
         {
            printf( "\n"
                   "##\n"
                   "## %s\n"
                   "##\n", [[pbxtarget name] UTF8String]);
         }
         target_exporter( pbxtarget, cmd, YES);
      }
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
   NSDictionary    *plist;
   NSString        *backupFile;
   NSString        *configuration;
   NSString        *file;
   NSString        *key;
   NSString        *old;
   NSString        *s;
   NSString        *target;
   NSString        *value;
   id              root;
   unsigned int    i, n;
   BOOL            allTargets;
   
   configuration = nil;
   target        = nil;
   allTargets    = NO;
   verbose       = getenv( "VERBOSE") ? YES : NO;
   
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

      if( [s isEqualToString:@"-f"] ||
          [s isEqualToString:@"--no-foundation"])
      {
         suppressFoundation = YES;
         continue;
      }

      if( [s isEqualToString:@"-t"] ||
          [s isEqualToString:@"-target"] ||
          [s isEqualToString:@"--target"])
      {
         if( ++i >= n)
            usage();
         
         target = [arguments objectAtIndex:i];
         continue;
      }
      
      // commands
      if( [s isEqualToString:@"export"])
      {
         exporter( root, Export, target, file);
         continue;
      }

      if( [s isEqualToString:@"list"])
      {
         exporter( root, List, target, file);
         continue;
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
