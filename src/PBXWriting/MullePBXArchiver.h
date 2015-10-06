/*
   mulle-xcode-settings
   
   $Id: MullePBXArchiver.h,v 22d35ece68c9 2011/01/11 15:22:39 nat $

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


@interface MullePBXArchiver : NSObject 
{
   int            archiveVersion_;
   int            objectVersion_;

@private   
   NSMutableDictionary  *encodedObjects_;  // ephemeral non/retained
}

- (void) setArchiveVersion:(int) version;
- (void) setObjectVersion:(int) version;

+ (NSDictionary *) archivedPropertyListWithRootObject:(id) root;
- (NSDictionary *) encodedRootObject:(id) root;

// only used during serialization
- (id) encodedObjectForKey:(NSString *) key;
- (void) setEncodedObject:(id) obj
                   forKey:(NSString *) key;
@end
