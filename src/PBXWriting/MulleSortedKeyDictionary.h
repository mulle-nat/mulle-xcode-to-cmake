/*
   mulle-xcode-settings
   
   $Id: MulleSortedKeyDictionary.h,v 22d35ece68c9 2011/01/11 15:22:39 nat $

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
#import <Foundation/Foundation.h>


@interface MulleSortedKeyDictionary : NSDictionary 
{
   NSArray        *keys_;
   NSDictionary   *dictionary_;
}

- (id) initWithDictionary:(NSDictionary *) dictionary;

@end
