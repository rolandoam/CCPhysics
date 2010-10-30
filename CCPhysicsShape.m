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

#import "CCPhysicsShape.h"
#import "CCPhysicsContainer.h"

// 1 is full bounce
#define BOUNCE    0.2f
#define FRICTION  0.05f
// 0 is full drag, 1 is no drag
#define DRAG      0.99999f

#pragma mark Collision Resolver Functions
// there should be one function for each CollisionShapeType

int ProjAABB_ShapeFull(CCPhysicsShape *obj, CGPoint p, CCPhysicsShape *shape) {
	CGFloat l = sqrtf(p.x * p.x + p.y * p.y);
	[obj collisionWithObject:shape projection:p normal:ccpMult(p, 1/l)];
	// FIXME
	// this is not working ok - the idea of this is to make other dynamic
	// objects be able to push another object
	/*
	if ([shape isKindOfClass:[CCPhysicsDynamicShape class]]) {
		[shape collisionWithObject:obj projection:p normal:ccpMult(p, -1/l)];
	}
	*/
	return kCollideAxis;
}

int ProjAABB_ShapeCircle(CCPhysicsShape *obj, CGPoint p, CCPhysicsShape *shape) {
	return kCollideNone;
}

int ProjAABB_ShapeTR_L45(CCPhysicsShape *obj, CGPoint p, CCPhysicsShape *shape) {
	return kCollideNone;
}

int ProjAABB_ShapeTR_R45(CCPhysicsShape *obj, CGPoint p, CCPhysicsShape *shape) {
	return kCollideNone;
}

int (*AABBSolverList[])(CCPhysicsShape *, CGPoint, CCPhysicsShape *) = {
	ProjAABB_ShapeFull, // World Boundaries
	ProjAABB_ShapeFull,
	ProjAABB_ShapeFull,
	ProjAABB_ShapeFull,
	ProjAABB_ShapeFull,
};

CGPoint ShapeHalfWidths[] = {
	{0,0},
	{GRID_SIZE/2, GRID_SIZE/2},
	{GRID_SIZE/4, GRID_SIZE/4},
	{GRID_SIZE/2, 7},
	{GRID_SIZE/2, 10},
};


@implementation CCPhysicsShape

@synthesize hw=hw_, collisionType=collisionType_;

+ (CCPhysicsShape *)shapeWithCollisionType:(CollisionShapeType)collisionType {
	return [[[CCPhysicsShape alloc] initWithCollisionType:collisionType] autorelease];
}

- (id)initWithCollisionType:(CollisionShapeType)collisionType {
	if ((self = [super init])) {
		collisionType_ = collisionType;
		reportMovesToParent_ = YES;
		
		// default halfwidths
		hw_ = ShapeHalfWidths[collisionType];
	}
	return self;
}

- (CGFloat)speed {
	return ccpDistance(position_, oldPos_);
}

- (void)setPosition:(CGPoint)newPosition {
	[super setPosition:newPosition];
	// let our parent know about our new position, so he can update the grid
	if (reportMovesToParent_)
		[(CCPhysicsContainer *)self.parent addObjectToGrid:self];
}

- (void)collideWith:(CollisionShapeType)type object:(CCPhysicsShape *)obj projection:(CGPoint)p {
	// here we call a specific solver for each tile type
	// this is the solver for AABB vs Tile
	
	(*AABBSolverList[obj.collisionType])(self, p, obj);
	[self collidedWithObject:obj];
}

- (void)collisionWithObject:(CCPhysicsShape *)obj projection:(CGPoint)proj normal:(CGPoint)d {
	// here we should calculate the new velocity
	// having a projection and a surface normal
	CGPoint v = ccpSub(position_, oldPos_);
	CGPoint p = position_;
	CGPoint o = oldPos_;
	
	CGFloat dp = ccpDot(v, d);
	CGPoint nv = ccpMult(d, dp); // normal velocity
	CGPoint tv = ccpSub(v, nv);  // tan velocity
	
	CGPoint f = CGPointZero, b = CGPointZero;
	if (dp < 0) {
		f = ccpMult(tv, FRICTION);
		b = ccpMult(nv, 1+BOUNCE);
	}
	
	p = ccpAdd(p, proj);
	CGPoint b_plus_f = ccpAdd(f, b);
	o = ccpAdd(o, ccpAdd(proj, b_plus_f));
	
	position_ = p;
	oldPos_ = o;	
}

- (void)collidedWithObject:(CCPhysicsShape *)obj {
}

- (void)draw {
	glColor4ub(0, 0, 0xff, 0xff);
	glLineWidth(2.0f);
	
	CGPoint points[4];
	points[0] = ccp(-hw_.x,  hw_.y);
	points[1] = ccp( hw_.x,  hw_.y);
	points[2] = ccp( hw_.x, -hw_.y);
	points[3] = ccp(-hw_.x, -hw_.y);
	
	ccDrawPoly(points, 4, YES);
}
@end



@implementation CCPhysicsDynamicShape
+ (CCPhysicsDynamicShape *)shapeWithPosition:(CGPoint)pos collisionType:(CollisionShapeType)collisionType {
	return [[[CCPhysicsDynamicShape alloc] initWithPosition:pos collisionType:collisionType] autorelease];
}

- (id)initWithPosition:(CGPoint)pos collisionType:(CollisionShapeType)collisionType {
	if ((self = [super initWithCollisionType:collisionType])) {
		// we need to set the pos and old pos
		oldPos_ = pos;
		self.position = pos;
		// subclasses need to set a specific shape!
		collisionType_ = collisionType;
		// usually, dynamic shapes do not report moves to parent
//		reportMovesToParent_ = YES;
		// each object has different gravity
		// this allows us to have "gravity centers"
		gravity_ = ccp(0.0f, -0.2);
	}
	return self;
}

// Verlet integration
- (void)integrate {
	CGPoint p = position_;
	CGPoint o = oldPos_;
	
	NSAssert(collisionType_, @"No collision type!!");
	oldPos_ = position_;
	// integrate
	// p = p + (p - o)*DRAG + gravity
	p = ccpAdd(p, ccpAdd(ccpMult(ccpSub(p, o), DRAG), gravity_));
	
	// we need to call CCNode's set position
	[self setPosition:p];
}

// override on subclasses
- (void)update {
}

// draw with different color
- (void)draw {
	glColor4ub(0xff, 0, 0xff, 0xff);
	glLineWidth(2.0f);
	
	CGPoint points[4];
	points[0] = ccp(-hw_.x,  hw_.y);
	points[1] = ccp( hw_.x,  hw_.y);
	points[2] = ccp( hw_.x, -hw_.y);
	points[3] = ccp(-hw_.x, -hw_.y);
	
	ccDrawPoly(points, 4, YES);
}
@end
