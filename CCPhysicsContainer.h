/*
 * CCPhysics for cocos2d - http://www.gamesforfood.com
 *
 * Copyright (c) 2010 Rolando Abarca M.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */


#import <Foundation/Foundation.h>
#import "cocos2d.h"
#import "CCPhysicsShape.h"
#include "uthash.h"

// add HASH_ITER if it's not there
#ifndef HASH_ITER
#define HASH_ITER(hh,head,el,tmp)                                               \
for((el)=(head),(tmp)=(head)?(head)->hh.next:NULL;                              \
el; (el)=(tmp),(tmp)=(tmp)?(tmp)->hh.next:NULL) 
#endif

typedef struct _hashCellItem {
	NSUInteger cell;   // key
	ccArray *items;
	UT_hash_handle hh;
} tHashCellItem;

@interface CCPhysicsContainer : CCNode {
	tHashCellItem *tileGrid_;
	ccArray *dynamicObjects_;
	NSUInteger maxRows_;
	NSUInteger maxCols_;
	CGRect bounds_;
}
+ (CCPhysicsContainer *)containerWithBounds:(CGRect)bounds;
- (id)initWithBounds:(CGRect)bounds;
- (id)addChild:(CCNode *)child dynamic:(BOOL)dynamic;
- (id)addChild:(CCNode *)child z:(int)z dynamic:(BOOL)dynamic;
- (id)addChild:(CCNode *)child z:(int)z tag:(int)tag dynamic:(BOOL)dynamic;
// updates collision grid
- (void)updateTileGridForTile:(CCPhysicsShape *)tile;
// checks for collision in the near grid
- (void)checkCollisionsFor:(CCPhysicsShape *)tile;
// do a little dance... make a little physics
- (void)simulate;
@end
