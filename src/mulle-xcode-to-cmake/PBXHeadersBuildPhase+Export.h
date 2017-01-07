//
//  PBXHeadersBuildPhase+Export.h
//  mulle-xcode-to-cmake
//
//  Created by Nat! on 07.01.17.
//
//

#import "PBXObject.h"


@interface PBXHeadersBuildPhase (Export)

- (NSArray *) publicHeaders;
- (NSArray *) projectHeaders;
- (NSArray *) privateHeaders;

@end
