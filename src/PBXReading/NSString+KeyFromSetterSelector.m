/*
   mulle-xcode-settings
   
   $Id: NSString+KeyFromSetterSelector.m,v 1b2480a5bc96 2011/06/13 21:20:00 nat $

   Created by Nat! on 08.1.11
   Copyright 2011 Mulle kybernetiK
   
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
#import "NSString+KeyFromSetterSelector.h"


@implementation NSString( KeyFromSetterSelector)

- (NSString *) keyWithRange:(NSRange) range
{
   unichar   *buf; 

   buf = (unichar *) [[NSMutableData dataWithLength:range.length * sizeof( unichar)] mutableBytes];
   [self getCharacters:buf
                 range:range];

   if( range.location)
      if( buf[ 0] >= 'A' && buf[ 0] <= 'Z')
         buf[ 0] += 'a' - 'A';
   return( [NSString stringWithCharacters:buf
                                   length:range.length]);
}

- (NSString *) keyFromSetterKey
{
   NSParameterAssert( [self hasSuffix:@":"]);
   NSParameterAssert( [self hasPrefix:@"set"]);
   
   return( [self keyWithRange:NSMakeRange( 3, [self length] - 4)]);
}


+ (NSString *) keyFromSetterSelector:(SEL) sel
{
   return( [NSStringFromSelector( sel) keyFromSetterKey]);
}

@end
