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


#import "CCPhysicsContainer.h"

// 32 * 50 = 1600 px
#define MAX_COLS  50
#define MAX_ROWS  10

@interface CCPhysicsContainer (Private)
- (void)addObjectToGrid:(CCPhysicsShape *)obj;
- (int)checkCollisionsInCell:(tHashCellItem *)item forObject:(CCPhysicsShape *)obj outProjection:(CGPoint *)p outTile:(CCPhysicsShape **)tile;
@end

#define CHECK_COLLISION_IN_CELL(x,y) do {                          \
	if ((x) >= 0 && (x) < maxCols_ && (y) >=0 && (y) < maxRows_) { \
		CGPoint p;                                                 \
		CCPhysicsShape *shape = nil;                               \
		NSUInteger cell = (x)*maxRows_ + (y);                      \
		tHashCellItem *item = nil;                                 \
		HASH_FIND_INT(tileGrid_, &cell, item);                     \
		if (item && [self checkCollisionsInCell:item               \
									  forObject:obj                \
								  outProjection:&p                 \
										outTile:&shape]) {         \
			[obj collideWith:shape.collisionType                   \
					  object:shape                                 \
				  projection:p];                                   \
		}                                                          \
	}                                                              \
} while(0);

#define SECURE_APPEND_IN_CELL(x,y,o) do {                          \
	NSUInteger cell = (x)*maxRows_ + (y);                          \
	tHashCellItem *item = nil;                                     \
	HASH_FIND_INT(tileGrid_, &cell, item);                         \
	if (!item) {                                                   \
		item = (tHashCellItem *)malloc(sizeof(tHashCellItem));     \
		memset(item, 0, sizeof(tHashCellItem));                    \
		item->cell = cell;                                         \
		item->items = ccArrayNew(5);                               \
		HASH_ADD_INT(tileGrid_, cell, item);                       \
	}                                                              \
	if (!ccArrayContainsObject(item->items, o))                    \
		ccArrayAppendObject(item->items, o);                       \
} while(0);

@implementation CCPhysicsContainer
+ (CCPhysicsContainer *)containerWithBounds:(CGRect)bounds {
	return [[[CCPhysicsContainer alloc] initWithBounds:bounds] autorelease];
}

- (id)initWithBounds:(CGRect)bounds {
	if ((self = [super init])) {
		tileGrid_ = nil;
		bounds_ = bounds;
		
		maxRows_ = bounds_.size.height / GRID_SIZE;
		maxCols_ = bounds_.size.width / GRID_SIZE;
		dynamicObjects_ = ccArrayNew(10);
	}
	return self;
}

- (id)init {
	CGSize size = [[CCDirector sharedDirector] winSize];
	CGRect bounds = {CGPointZero, size};
	// by default, init with the bounds of the director's window
	if ((self = [self initWithBounds:bounds])) {
	}
	return self;
}

- (id)addChild:(CCNode *)child dynamic:(BOOL)dynamic {
	return [self addChild:child z:child.zOrder tag:child.tag dynamic:dynamic];
}

- (id)addChild:(CCNode *)child z:(int)z dynamic:(BOOL)dynamic {
	return [self addChild:child z:z tag:child.tag dynamic:dynamic];
}

- (id)addChild:(CCNode*)child z:(int)z tag:(int)tag dynamic:(BOOL)dynamic {
	NSAssert([child isKindOfClass:[CCPhysicsShape class]], @"CCPhysicsContainer can only hold Tiles");
	[super addChild:child z:z tag:tag];
	
	// add the object to the grid
	[self updateTileGridForTile:(CCPhysicsShape *)child];
	if (dynamic) {
		ccArrayEnsureExtraCapacity(dynamicObjects_, 1);
		// just a weak ref, since children_ array holds them tight :-P
		ccArrayAppendObject(dynamicObjects_, child);
	}
	return child;
}

- (id)addChild:(CCNode*)child z:(int)z tag:(int)tag {
	// by default add a static node
	return [self addChild:child z:z tag:tag dynamic:NO];
}

- (void)addObjectToGrid:(CCPhysicsShape *)obj {
	NSInteger cx, cy;
	CGPoint tp = obj.position;
	
	// add the center
	cx = tp.x / GRID_SIZE;
	cy = tp.y / GRID_SIZE;
	SECURE_APPEND_IN_CELL(cx, cy, obj)
	// add the four corners
	// top left
	cx = (tp.x - obj.hw.x) / GRID_SIZE;
	cy = (tp.y + obj.hw.y) / GRID_SIZE;
	SECURE_APPEND_IN_CELL(cx, cy, obj)
	// top right
	cx = (tp.x + obj.hw.x) / GRID_SIZE;
	cy = (tp.y + obj.hw.y) / GRID_SIZE;
	SECURE_APPEND_IN_CELL(cx, cy, obj)
	// bottom left
	cx = (tp.x - obj.hw.x) / GRID_SIZE;
	cy = (tp.y - obj.hw.y) / GRID_SIZE;
	SECURE_APPEND_IN_CELL(cx, cy, obj)
	// bottom right
	cx = (tp.x + obj.hw.x) / GRID_SIZE;
	cy = (tp.y - obj.hw.y) / GRID_SIZE;
	SECURE_APPEND_IN_CELL(cx, cy, obj)
}

- (void)updateTileGridForTile:(CCPhysicsShape *)tile {
	NSAssert(tile.parent == self, @"This tile does not belong to me!");
	[self addObjectToGrid:tile];
}

- (void)checkCollisionsFor:(CCPhysicsShape *)obj {
	NSInteger colx, coly;
	CGPoint tp = obj.position;
	
	colx = tp.x / GRID_SIZE;
	coly = tp.y / GRID_SIZE;
	
	// check world boundaries
	CGPoint w = ccp(GRID_SIZE/2, 7.0f); // halfwidths of the tile
	CGPoint d = ccp(0 - (tp.x - w.x), 0 - (tp.y - w.y));
	
	// test x
	if (bounds_.origin.x < d.x) {
		// collide with XMIN
		[obj collideWith:0 object:nil projection:ccp(d.x,0)];
	} else {
		d.x = (tp.x + w.x) - maxCols_ * GRID_SIZE;
		if (0 < d.x) {
			// collid with XMAX
			[obj collideWith:0 object:nil projection:ccp(-d.x,0)];
		}
	}
	
	// test y
	if (bounds_.origin.y < d.y) {
		// collide with YMIN
		[obj collideWith:0 object:nil projection:ccp(0,d.y)];
	} else {
		d.y = (tp.y + w.y) - maxRows_ * GRID_SIZE;
		if (0 < d.y) {
			// collide with YMAX
			[obj collideWith:0 object:nil projection:ccp(0,-d.y)];
		}
	}
	
	// check on the neighbour cells
	CHECK_COLLISION_IN_CELL(colx - 1, coly + 1);
	CHECK_COLLISION_IN_CELL(colx    , coly + 1);
	CHECK_COLLISION_IN_CELL(colx + 1, coly + 1);
	CHECK_COLLISION_IN_CELL(colx - 1, coly    );
	CHECK_COLLISION_IN_CELL(colx    , coly    );
	CHECK_COLLISION_IN_CELL(colx + 1, coly    );
	CHECK_COLLISION_IN_CELL(colx - 1, coly - 1);
	CHECK_COLLISION_IN_CELL(colx    , coly - 1);
	CHECK_COLLISION_IN_CELL(colx + 1, coly - 1);
}

- (void)simulate {
	CCPhysicsDynamicShape *obj;
	
	// update -> integrate -> check for collisions
	CCARRAYDATA_FOREACH(dynamicObjects_, obj) {
		[obj update];
		[obj integrate];
		[self checkCollisionsFor:obj];
	}	
}

- (int)checkCollisionsInCell:(tHashCellItem *)item forObject:(CCPhysicsShape *)obj outProjection:(CGPoint *)p outTile:(CCPhysicsShape **)tile {
	CGPoint op = obj.position;
	CGPoint dp, penetration, tp, tw;
	
	// iterate over all objects in the cell
	CCPhysicsShape *t;	
	CCARRAYDATA_FOREACH(item->items, t) {
		// skip if t == obj
		if (obj != t) {
			// tile halfwidths
			tw = ShapeHalfWidths[t.collisionType];
			
			// tile position in points
			tp = t.position;
			
			// delta between object and tile
			dp = ccpSub(op, tp);
			
			// penetration = (tw + ow) - abs(dp)
			penetration = ccpSub(ccpAdd(tw, obj.hw), ccp(fabs(dp.x), fabs(dp.y)));
			if (0 < penetration.x) {
				if (0 < penetration.y) {
					// object colliding with tile
					if (penetration.x < penetration.y) {
						// project in x
						if (dp.x < 0) {
							// project to the left
							p->x = -penetration.x;
						} else {
							// project to the right
							p->x = penetration.x;
						}
						p->y = 0;
					} else {
						// project in y
						if (dp.y < 0) {
							// project up
							p->y = -penetration.y;
						} else {
							// project down
							p->y = penetration.y;
						}
						p->x = 0;
					}
					return YES;
				}
			}
		}
	}
	return kCollideNone;
}

- (void)dealloc {
	// free grid and each ccArray within
	tHashCellItem *current, *tmp;
	HASH_ITER(hh, tileGrid_, current, tmp) {
		HASH_DEL(tileGrid_, current);
		ccArrayFree(current->items);
		free(current);
	}
	ccArrayFree(dynamicObjects_);
	[super dealloc];
}
@end
