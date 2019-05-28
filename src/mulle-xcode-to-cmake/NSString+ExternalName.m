//
//  NSString+ExternalName.m
//  mulle-xcode-to-cmake
//
//  Created by Nat! on 07.01.17.
//
//

#import "NSString+ExternalName.h"

@implementation NSString (ExternalName)

+ (NSString *) externalNameForInternalName:(NSString *) s
                           separatorString:(NSString *) sep
                                useAllCaps:(BOOL) allCaps
{
   NSRange          range;
   NSCharacterSet   *set;
   NSUInteger     len;
   NSString         *sub;
   NSMutableString  *result;

   if( [s rangeOfString:@"MulleObjC"].length)
      s = [[s componentsSeparatedByString:@"MulleObjC"] componentsJoinedByString:@"MulleObjc"];
   if( [s rangeOfString:@"BSDFoundation"].length)
      s = [[s componentsSeparatedByString:@"BSDFoundation"] componentsJoinedByString:@"BsdFoundation"];
   if( [s rangeOfString:@"OSFoundation"].length)
      s = [[s componentsSeparatedByString:@"OSFoundation"] componentsJoinedByString:@"OsFoundation"];

   result = [NSMutableString string];
   set    = [NSCharacterSet uppercaseLetterCharacterSet];

   len = [s length];
   while( len > 1)
   {
      range = [[s substringFromIndex:1] rangeOfCharacterFromSet:set];
      if( range.length == 0)
         break;
      sub = [s substringWithRange:NSMakeRange( 0, range.location + 1)];
      if( allCaps)
         sub = [sub uppercaseString];
      else
         sub = [sub lowercaseString];

      [result appendString:sub];
      if( ! (len -= range.location + 1))
         return( result);

      if( range.location != 0)
         [result appendString:sep];
      s = [s substringFromIndex:range.location + 1];
   }

   [result appendString:s];
   return( result);
}

@end
