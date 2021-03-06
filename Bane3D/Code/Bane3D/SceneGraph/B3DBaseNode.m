//
//  B3DBaseNode.m
//  Bane3D
//
//  Created by Andreas Hanft on 06.04.11.
//
//
//  Copyright (C) 2012 Andreas Hanft (talantium.net)
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

#import "B3DBaseNode.h"

#import "Bane3DEngine.h"
#import "B3DInputManager.h"
#import "B3DScene.h"
#import "B3DColor.h"
#import "B3DAssetManager.h"
#import "B3DAssetToken.h"
#import "B3DAssert.h"
#import "B3DTime.h"
#import "B3DBaseNode+Protected.h"


@interface B3DBaseNode ()
{
    @private
        GLKMatrix4              _transform;
        BOOL					_sceneGraphHierarchyDirty;
        BOOL                    _receivesTouchEvents;
}

@property (nonatomic, weak, readwrite)					Bane3DEngine*		engine;

@end


@implementation B3DBaseNode

#pragma mark - Dynamic Properties

@dynamic	visible;
@dynamic	transform;
@dynamic	absoluteTransform;
@dynamic	absolutePosition;
@dynamic	absoluteScale;
@dynamic	absoluteRotation;
@dynamic	receivesTouchEvents;
@dynamic	parentScene;
@dynamic	children;


#pragma mark - Con-/Destructor

// Designated initializer
- (id) init
{
	self = [super init];
	if (self)
	{
        _engine             = [Bane3DEngine entity];
        
		// Reset transformation matrix
		_transform          = GLKMatrix4Identity;
		
		_position           = GLKVector3Make(0.0f, 0.0f, 0.0f);
		_scale              = GLKVector3Make(1.0f, 1.0f, 1.0f);
		_rotation           = GLKQuaternionIdentity;
				
		// Properties
		_visible            = YES;
        _assetTokens        = [[NSMutableDictionary alloc] init];
		
		// Hierarchy
		_parentScene		= nil;
		_parentNode         = nil;
		_mutableChildren    = [[NSMutableSet alloc] init];
        _immutableChildren  = nil;
	}
	
	return self;
}


#pragma mark - Node Lifecycle

- (void) create
{
    [self initAssets];
	
    for (B3DBaseNode* node in _mutableChildren)
	{
		[node create];
	}
}

- (void) awake
{
	_transformationDirty = YES;
    _sceneGraphHierarchyDirty = YES;
    
    if (_awakeBlock)
    {
        self.awakeBlock(self);
    }
	
	for (B3DBaseNode* node in _mutableChildren)
	{
		[node awake];
	}
}

- (void) awakeWithBlock:(B3DAwakeBlock)awakeBlock
{
    self.awakeBlock = awakeBlock;
}

- (void) destroy
{
    for (B3DBaseNode* node in _mutableChildren)
	{
		[node destroy];
	}
}


#pragma mark - Asset Handling

- (void) initAssets
{
	// Use this method as a place to get the now readily loaded resources from
    // the asset manager. Every asset has an uniqe ID generated by its (file)name.
    // This is used to identify assets and enable, for example, asset sharing between
    // scenes.
    // Example:
	// self.texture = [[Bane3DEngine assetManager] assetForId:someTextureId];
    
    // Setting
    B3DAssetToken* token = nil;
    for (NSString* keyPath in [[_assetTokens allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)])
    {
        token = [_assetTokens objectForKey:keyPath];
//        LogDebug(@"Assigning asset %@ to keypath %@", token.uniqueIdentifier, keyPath);
        [self setValue:[[Bane3DEngine assetManager] assetForId:token.uniqueIdentifier]
            forKeyPath:keyPath];
    }
}

- (void) useAssetWithToken:(B3DAssetToken*)token atKeyPath:(NSString*)keyPath
{
    // Actually not needed but set keyPath in token for reference.
    token.keyPath = keyPath;
    [_assetTokens setObject:token forKey:keyPath];
}


#pragma mark - Update/Drawing

- (void) update
{
    if (_sceneGraphHierarchyDirty)
	{
		_immutableChildren = [_mutableChildren allObjects];
		_sceneGraphHierarchyDirty = NO;
	}
    
    if (_updateLoopBlock)
    {
        self.updateLoopBlock(self, [B3DTime deltaTime]);
    }
    
    for (B3DBaseNode* node in _immutableChildren)
    {
        if (node.isVisible)
        {
            [node update];
        }
    }
}

- (void) draw
{
    if (_transformationDirty)
    {
        // Update the transformation matrix of node, done here since only needed 
        // when really drawing a node!
        [self updateMatrix];
        _transformationDirty = NO;
    }
    
    for (B3DBaseNode* node in _immutableChildren)
    {
        if (node.isVisible)
        {
            [node draw];
        }
    }
}

- (void) updateWithBlock:(B3DUpdateLoopBlock)updateLoopBlock
{
    self.updateLoopBlock = updateLoopBlock;
}


#pragma mark - Scene Graph

#pragma mark > Visibility

- (void) setVisible:(BOOL)visible
{
	_visible = visible;
}

- (BOOL) isVisible
{
	if (!_parentScene)
	{
		return NO;
	}
	
	return (_visible && _parentScene.isVisible);
}

#pragma mark > Sorting

- (NSComparisonResult) compareByZValueDescending:(B3DBaseNode*)otherNode
{
	float selfZ = abs(self.absolutePosition.z);
	float otherZ = abs(otherNode.absolutePosition.z);
	if (selfZ < otherZ)
	{
		return NSOrderedDescending;
	}
	else if (selfZ > otherZ)
	{
		return NSOrderedAscending;
	}
	else
	{
		return NSOrderedSame;
	}
}

- (NSComparisonResult) compareByZValueAscending:(B3DBaseNode<B3DTouchResponder>*)otherNode
{
	float selfZ = abs(self.absolutePosition.z);
	float otherZ = abs(otherNode.absolutePosition.z);
	if (selfZ < otherZ)
	{
		return NSOrderedAscending;
	}
	else if (selfZ > otherZ)
	{
		return NSOrderedDescending;
	}
	else
	{
		return NSOrderedSame;
	}
}

#pragma mark > Altering Hierarchy

- (void) addSubNode:(B3DBaseNode*)node
{
	[B3DAssert that:(node != self) errorMessage:@"Adding Node to self as child!"];
	
	[_mutableChildren addObject:node];
	node.parentNode = self;
	node.parentScene = _parentScene;
    
    _sceneGraphHierarchyDirty = YES;
}


- (BOOL) removeSubNode:(B3DBaseNode*)node
{
	// Is given node a child of this node?
	if ([_mutableChildren containsObject:node])
	{
		node.parentNode = nil;
		node.parentScene = nil;
		[_mutableChildren removeObject:node];
        
        _sceneGraphHierarchyDirty = YES;
		
		return YES;
	}
	else
	{
		return NO;
	}
}

- (BOOL) removeFromParentNode
{
	if (_parentNode)
	{
		return [_parentNode removeSubNode:self];
	}
	
	return NO;
}

- (B3DScene*) parentScene
{
	return _parentScene;
}

- (void) setParentScene:(B3DScene*)scene
{
	if (_parentScene)
	{
		[_parentScene lazyCleanUpNode:self];
	}
	
	if (scene)
	{
		[scene lazyInitNode:self];
	}
	
	_parentScene = scene;

	for (B3DBaseNode* node in _mutableChildren)
	{
		node.parentScene = scene;
	}
}

- (NSSet*) children
{
	return [[NSSet alloc] initWithSet:_mutableChildren];
}


#pragma mark - Manipulation

- (void) setPosition:(GLKVector3)position
{
    _position = position;
    _transformationDirty = YES;
}

- (void) setRotation:(GLKQuaternion)rotation
{
    _rotation = rotation;
    _transformationDirty = YES;
}

- (void) setScale:(GLKVector3)scale
{
    _scale = scale;
    _transformationDirty = YES;
}

- (GLKVector3) absolutePosition
{
	if (_parentNode)
	{
		return GLKVector3Add(_parentNode.absolutePosition, _position);
	}
	else
	{
		return _position;
	}
}

- (GLKVector3) absoluteScale
{
	if (_parentNode)
	{
		return GLKVector3Multiply(_parentNode.absoluteScale, _scale);
	}
	else
	{
		return _scale;
	}
}

- (GLKQuaternion) absoluteRotation
{
	if (_parentNode)
	{
		return GLKQuaternionMultiply(_parentNode.absoluteRotation, _rotation);
	}
	else
	{
		return _rotation;
	}
}

- (GLKMatrix4) transform
{	
	return _transform;
}

- (GLKMatrix4) absoluteTransform
{
	if (_parentNode)
	{
		return GLKMatrix4Multiply(_parentNode.absoluteTransform, _transform);
	}
	else
	{
		return _transform;
	}
}

- (void) updateMatrix
{
    // The order of multiplication is important to ensure
    // correct accumulation of transformations!
    // _transform = ident * pos * rot * scale;
    
    GLKMatrix4 position = GLKMatrix4MakeTranslation(_position.x, _position.y, _position.z);
    GLKMatrix4 rotation = GLKMatrix4Multiply(position, GLKMatrix4MakeWithQuaternion(_rotation));
    _transform          = GLKMatrix4Multiply(rotation, GLKMatrix4MakeScale(_scale.x, _scale.y, _scale.z));
}

- (void) setPositionToX:(GLfloat)xPos andY:(GLfloat)yPos andZ:(GLfloat)zPos
{
	_position = GLKVector3Make(xPos, yPos, zPos);
    _transformationDirty = YES;
}

- (void) translateBy:(GLKVector3)translation
{
	_position = GLKVector3Add(_position, translation);
    _transformationDirty = YES;
}

- (void) translateByX:(GLfloat)xTrans andY:(GLfloat)yTrans andZ:(GLfloat)zTrans
{
	_position = GLKVector3Add(_position, GLKVector3Make(xTrans, yTrans, zTrans));
    _transformationDirty = YES;
}

- (void) setRotationToAngleX:(GLfloat)xAngle andY:(GLfloat)yAngle andZ:(GLfloat)zAngle
{
    GLKQuaternion quadRot = GLKQuaternionIdentity;
    if (xAngle != 0.0f)
    {
        quadRot = GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(xAngle), 1.0f, 0.0f, 0.0f);
    }
    
    if (yAngle != 0.0f)
    {
        quadRot = GLKQuaternionMultiply(quadRot, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(yAngle), 0.0f, 1.0f, 0.0f));
    }
    
    if (zAngle != 0.0f)
    {
        quadRot = GLKQuaternionMultiply(quadRot, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(zAngle), 0.0f, 0.0f, 1.0f));
    }
    
    _rotation = quadRot;    
    _transformationDirty = YES;
}

- (void) setRotationToAngle:(GLfloat)angle byAxisX:(GLfloat)xAxis andY:(GLfloat)yAxis andZ:(GLfloat)zAxis
{
    _rotation = GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(angle), xAxis, yAxis, zAxis);
    _transformationDirty = YES;
}

- (void) rotateBy:(GLKVector3)rotation
{
	[self rotateByX:rotation.x andY:rotation.y andZ:rotation.z];
}

// Expects euler angles
- (void) rotateByX:(GLfloat)xRot andY:(GLfloat)yRot andZ:(GLfloat)zRot
{
    // TODO: Check if this rotation algo is still mostly correct :)
    
    if (xRot != 0.0f)
    {
        _rotation = GLKQuaternionMultiply(_rotation, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(xRot), 1.0f, 0.0f, 0.0f));
    }
    
    if (yRot != 0.0f)
    {
        _rotation = GLKQuaternionMultiply(_rotation, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(yRot), 0.0f, 1.0f, 0.0f));
    }
    
    if (zRot != 0.0f)
    {
        _rotation = GLKQuaternionMultiply(_rotation, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(zRot), 0.0f, 0.0f, 1.0f));
    }
    
    _transformationDirty = YES;
    
    // Older version, kept for reference
    
//    GLKQuaternion quadRot = GLKQuaternionIdentity;
//    if (xRot != 0.0f)
//    {
//        quadRot = GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(xRot), 1.0f, 0.0f, 0.0f);
//    }
//    
//    if (yRot != 0.0f)
//    {
//        quadRot = GLKQuaternionMultiply(quadRot, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(yRot), 0.0f, 1.0f, 0.0f));
//    }
//    
//    if (zRot != 0.0f)
//    {
//        quadRot = GLKQuaternionMultiply(quadRot, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(zRot), 0.0f, 0.0f, 1.0f));
//    }
//    
//    _rotation = GLKQuaternionMultiply(_rotation, quadRot);
    
    
    // Oldest version without checks
    
//    GLKQuaternion quadRotX = GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(xRot), 1.0f, 0.0f, 0.0f);
//    GLKQuaternion quadRotXY = GLKQuaternionMultiply(quadRotX, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(yRot), 0.0f, 1.0f, 0.0f));
//    GLKQuaternion quadRotXYZ = GLKQuaternionMultiply(quadRotXY, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(zRot), 0.0f, 0.0f, 1.0f));
//    _rotation = GLKQuaternionMultiply(_rotation, quadRotXYZ);
}

- (void) rotateByAngle:(GLfloat)angle aroundX:(GLfloat)xAxis andY:(GLfloat)yAxis andZ:(GLfloat)zAxis
{
    _rotation = GLKQuaternionMultiply(_rotation, GLKQuaternionMakeWithAngleAndAxis(GLKMathDegreesToRadians(angle), xAxis, yAxis, zAxis));
    _transformationDirty = YES;
}

- (void) rotateByAngle:(GLfloat)angle aroundAxis:(GLKVector3)axisVector
{
    [self rotateByAngle:angle aroundX:axisVector.v[0] andY:axisVector.v[1] andZ:axisVector.v[2]];
}

- (void) setScaleUniform:(GLfloat)unifor_scale
{
    _scale = GLKVector3Make(unifor_scale, unifor_scale, unifor_scale);
    _transformationDirty = YES;
}

- (void) setScaleToX:(GLfloat)xScale andY:(GLfloat)yScale andZ:(GLfloat)zScale
{
    _scale = GLKVector3Make(xScale, yScale, zScale);
    _transformationDirty = YES;
}


#pragma mark - Touch

- (BOOL) isReceivingTouchEvents
{
	return _receivesTouchEvents;
}

- (void) setReceivesTouchEvents:(BOOL)receive
{
	_receivesTouchEvents = receive;
	
	// If we change reveiving state while we are in a scene graph
	// an the scene is also visible, we directly communicate with
	// the input manager and (un)register us.
	// All other cases are handled by the scene itself we are connected
	// to when it becomes visible/unloaded or when we connect during
	// runtime.
	if (_parentScene && [_parentScene isVisible])
	{
		if (_receivesTouchEvents)
		{
			[[B3DInputManager sharedManager] registerForTouchEvents:self];
		}
		else
		{
			[[B3DInputManager sharedManager] unregisterForTouchEvents:self];
		}		
	}
}


#pragma mark - Misc

- (void) viewportDidChangeTo:(CGRect)viewport
{
	for (B3DBaseNode* node in _immutableChildren)
	{
		[node viewportDidChangeTo:viewport];
	}
}

- (void) print
{
	B3DBaseNode* parent = self.parentNode;
	NSMutableString* depth = [[NSMutableString alloc] initWithString:@""];
	while (parent)
	{
		[depth appendString:@"\t"];
		parent = parent.parentNode;
	}
	
	LogDebug(@"%@%@%@", depth, ([depth length] > 0 ? @"|-> " : @""), [self description]);
	
	for (B3DBaseNode* node in self.children)
	{
		[node print];
	}
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"%@ @ {%.2f, %.2f, %.2f} {%.2f, %.2f, %.2f}", (_name ? _name : @"Node"), _position.x, _position.y, _position.z, self.absolutePosition.x, self.absolutePosition.y, self.absolutePosition.z];
}


@end
