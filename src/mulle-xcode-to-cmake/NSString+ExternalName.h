//
//  NSString+ExternalName.h
//  mulle-xcode-to-cmake
//
//  Created by Nat! on 07.01.17.
//
//

#import <Foundation/Foundation.h>

@interface NSString (ExternalName)

- (NSString *) makeExternalNameFromInternalNameWithSeparatorString:(NSString *) sep
                                                        useAllCaps:(BOOL) allCaps;
@end
