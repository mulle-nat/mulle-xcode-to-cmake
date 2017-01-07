/*
   mulle-xcode-utility
   
   $Id: NSArray+Path.m,v 65099ebecdce 2011/11/30 23:33:12 nat $

   Created by Nat! on 10.1.11
   Copyright 2011 Mulle kybernetiK
   
   This file is part of mulle-xcode-utility.

   mulle-xcode-utility is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   mulle-xcode-utility is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with mulle-xcode-utility.  If not, see <http://www.gnu.org/licenses/>.
*/
#import "NSArray+Path.h"


@implementation NSArray( Path)

- (NSArray *) standardizedPathComponents
{
   NSMutableArray   *array;
   NSEnumerator     *rover;
   NSString         *s;
   
   array = [NSMutableArray array];
   rover = [self objectEnumerator];
   while( s = [rover nextObject])
   {
      if( [s isEqualToString:@"."])
         continue;
      if( [s isEqualToString:@".."])
      {
         if( [array count] && ! [[array lastObject] isEqualToString:@".."])
         {
            [array removeLastObject];
            continue;
         }
      }
      [array addObject:s];
   }

   if( [array count] == 0 && [self count] != 0)
      [array addObject:@"."];

   return( array);
}


- (NSArray *) componentsByDeletingComponents:(NSArray *) other
{
   unsigned int   i, n;
   unsigned int   m;
   NSString       *a;
   NSString       *b;

   n = [self count];
   m = [other count];
   if( m > n)
      return( nil);
   if( ! m)
      return( self);
      
   for( i = 0; i < m; i++)  // sic
   {
      a = [self objectAtIndex:i];
      b = [other objectAtIndex:i];
      if( ! [a isEqualToString:b]) 
         return( nil);
   }
   return( [self subarrayWithRange:NSMakeRange( i, n - i)]);
}


//
// [ a, b ] : [ a ]    -> [ b ]
// [ a, b ] : [ b ]    -> [ a, b ]
// [ a, b ] : [ c ]    -> [ a, b ]
// [ a, b ] : [ a, c ] -> [ b ]
// [ a, b ] : [ ]      -> [ a, b ]
// [ a, b ] : nil      -> [ a, b ]

- (NSArray *) componentsByDeletingCommonLeadingPathComponents:(NSArray *) other
{
   unsigned int   i, n;
   unsigned int   m;
   NSString       *a;
   NSString       *b;
  
   n = [self count];
   m = [other count];
   if( m > n)
      return( nil);
   if( ! m)
      return( self);
         
   for( i = 0; i < m; i++)  // sic
   {
      a = [self objectAtIndex:i];
      b = [other objectAtIndex:i];
      if( ! [a isEqualToString:b]) 
         break;
   }
   
   return( [self subarrayWithRange:NSMakeRange( i, n - i)]);
}


//
// [ a, b ] : [ a ]    -> [ b ]
// [ a, b ] : [ b ]    -> [ b, a, b ]
// [ a, b ] : [ c ]    -> [ c, a, b ]
// [ a, b ] : [ a, c ] -> [ c, b ]
// [ a, b ] : [ ]      -> [ a, b ]
// [ a, b ] : nil      -> [ a, b ]

- (NSArray *) componentsByDeletingCommonLeadingComponentsAndPrefixingRest:(NSArray *) other
{
   unsigned int   i, n;
   unsigned int   m;
   NSString       *a;
   NSString       *b;
   NSArray        *prefix;
   NSArray        *rest;
   
   n = [self count];
   m = [other count];
   if( m > n)
      return( nil);
   if( ! m)
      return( self);
         
   for( i = 0; i < m; i++)  // sic
   {
      a = [self objectAtIndex:i];
      b = [other objectAtIndex:i];
      if( ! [a isEqualToString:b]) 
         break;
   }
   
   prefix = [other subarrayWithRange:NSMakeRange( i, m - i)];
   rest   = [self subarrayWithRange:NSMakeRange( i, n - i)];
   
   return( [prefix arrayByAddingObjectsFromArray:rest]);
}


//
// just a hack for reconnect...
//
- (NSArray *) pathComponentsByCombiningCommonPathComponents:(NSArray *) other
{
   NSString       *component;
   unsigned int   n;
   unsigned int   m;
   unsigned int   memo;
   unsigned int   k, l;
   id             components;
   
   components = [NSMutableArray array];
   
   n = [other count];
   m = [self count];
   l = m > n ? n : m;
   
   for( k = 0; k < l; k++)
   {
      component = [self objectAtIndex:k];
      [components addObject:component];
      if( ! [component isEqualToString:[other objectAtIndex:k]])
         break;
   }  
   memo = k;
   for( k = memo; k < n; k++)
      [components addObject:@".."];
   for( k = memo; k < m; k++)
      [components addObject:[self objectAtIndex:k]];
   
   return( components);
}


// basically should turn
//  /a/b/c/d with root /a/b/x/y/z into -> ../../../c/d
// so /a/b/x/y/z/../../../c/d is equivalent to /a/b/c/d
//
- (NSArray *) relativePathComponentsToRootComponents:(NSArray *) root
{
   NSString       *component;
   unsigned int   n;
   unsigned int   m;
   unsigned int   memo;
   unsigned int   k, l;
   id             components;
   
   components = [NSMutableArray array];
   
   n = [root count];
   m = [self count];
   l = m > n ? n : m;
   
   for( k = 0; k < l; k++)
   {
      component = [self objectAtIndex:k];
      NSParameterAssert( ! [component isEqualToString:@".."]);
      NSParameterAssert( ! [component isEqualToString:@"."]);
       
      if( ! [component isEqualToString:[root objectAtIndex:k]])
         break;
   }  
   memo = k;
   for( ;k < n; k++)
      [components addObject:@".."];
   k = memo;
   for( ;k < m; k++)
      [components addObject:[self objectAtIndex:k]];
   
   return( components);
}


- (NSArray *) commonPathComponents:(NSArray *) other
{
   unsigned int   i, n;
   unsigned int   m;
   NSString       *a;
   NSString       *b;

   n = [self count];
   m = [other count];
   if( m < n)
      n = m;
   if( ! n)
      return( self);
      
   for( i = 0; i < n; i++)  
   {
      a = [self objectAtIndex:i];
      b = [other objectAtIndex:i];
      if( ! [a isEqualToString:b]) 
         break;
   }
   return( [self subarrayWithRange:NSMakeRange( 0, i)]);
}

@end

