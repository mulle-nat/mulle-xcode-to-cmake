//
//  PBXHeadersBuildPhase+Export.m
//  mulle-xcode-to-cmake
//
//  Created by Nat! on 07.01.17.
//
//

#import "PBXHeadersBuildPhase+Export.h"

@implementation PBXHeadersBuildPhase (Export)

- (NSArray *) headersMatchingPublic:(BOOL) public
                            private:(BOOL) private;
{
   NSMutableArray   *array;
   NSEnumerator     *rover;
   PBXBuildFile     *file;
   
   array = [NSMutableArray array];
   rover = [[self files] objectEnumerator];
   while( file = [rover nextObject])
   {
      if( [file isPublic] != public)
         continue;
      if( [file isPrivate] != private)
         continue;
      [array addObject:file];
   }
   
   return( array);
}


- (NSArray *) publicHeaders
{
   return( [self headersMatchingPublic:YES
                               private:NO]);
}


- (NSArray *) projectHeaders
{
   return( [self headersMatchingPublic:NO
                               private:NO]);
}


- (NSArray *) privateHeaders
{
   return( [self headersMatchingPublic:NO
                               private:YES]);
}

@end
