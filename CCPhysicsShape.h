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

#define GRID_SIZE 32

typedef enum {
	ShapeSquare     = 1,
	ShapeHalfSquare, // square of 16x16
	ShapeRect_32x14, // rectangle of 32x14 (this is the Sperm)
	ShapeRect_32x20, // rectangle of 32x20
	ShapeCircle,     // circle of 16px of radius
	ShapeTR_L45,     // right 45deg triangle
	ShapeTR_R45,     // left 45deg triangle
} CollisionShapeType;

extern CGPoint ShapeHalfWidths[];

enum {
	kCollideNone = 0,
	kCollideAxis,
	kCollideOther
};

@interface CCPhysicsShape : CCNode {
	// collision shape, should have an associated collision function
	CollisionShapeType collisionType_;
	// internal tile type (user data)
	uint8_t tileType_;
	// whether or not to inform our parent (CCNode) when we change our position
	// this should be false for the dynamic object, since they inform on the
	// integrate function
	BOOL reportMovesToParent_;
	// we use this to calculate velocity and verlet integration
	CGPoint oldPos_;
	// half widths. These are taken from the static list. Should not be
	// modified by hand
	CGPoint hw_;
}

@property (nonatomic,readwrite) CollisionShapeType collisionType;
@property (nonatomic,readonly) CGPoint hw;

+ (CCPhysicsShape *)shapeWithCollisionType:(CollisionShapeType)collisionType;
- (id)initWithCollisionType:(CollisionShapeType)collisionType;
- (CGFloat)speed;

/*
 * process collision
 * 
 * we pass the collisionShape and the tile object, because when colliding
 * with the world boundaries, collisionShape is 0 and object is nil, so
 * we can't infer that from the object itself.
 * 
 * This will call the specific calculation function for the shape type of
 * the receiving object.
 */
- (void)collideWith:(CollisionShapeType)type object:(CCPhysicsShape *)obj projection:(CGPoint)p;

/*
 * execute collision
 * 
 * this is called after the projection and normal were calculated. This will change
 * velocity according to the physics (adding friction and bounce)
 */
- (void)collisionWithObject:(CCPhysicsShape *)obj projection:(CGPoint)proj normal:(CGPoint)d;

/*
 * final collision callback
 * 
 * this is called after the solver and after the execution. In case you need to do something
 */
- (void)collidedWithObject:(CCPhysicsShape *)obj;
@end


@interface CCPhysicsDynamicShape : CCPhysicsShape {
	CGPoint gravity_;
}

+ (CCPhysicsDynamicShape *)shapeWithPosition:(CGPoint)pos collisionType:(CollisionShapeType)collisionType;
- (id)initWithPosition:(CGPoint)pos collisionType:(CollisionShapeType)collisionType;

/*
 * verlet integration
 * 
 * on static objects this do nothing. On dynamic objects it calculates the position
 */
- (void)integrate;

/*
 * update what you need here, this is run just before integration
 */
- (void)update;
@end
