/*
   mulle-xcode-settings
   
   $Id: PBXProjectProxy.m,v 02b5717ff65c 2011/12/02 12:57:47 nat $

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
#import "PBXProjectProxy.h"


@implementation PBXProjectProxy

- (id) init
{
   return( self);
}



- (NSMethodSignature *) methodSignatureForSelector:(SEL) sel
{
   NSMethodSignature   *signature;
   
   signature = [project_ methodSignatureForSelector:sel];
   if( signature)
      return( signature);
   return( [super methodSignatureForSelector:sel]);
}


- (void) forwardInvocation:(NSInvocation *) invocation
{
   [invocation invokeWithTarget:project_];
}


- (void) setProject:(PBXProject *) pbx
{  
   NSParameterAssert( [pbx isKindOfClass:[PBXProject class]]);
   
   project_ = pbx;
}

@end
