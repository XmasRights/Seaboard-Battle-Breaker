//
//  GameScene.m
//  SeaboardBattleBreakout
//
//  Created by Christopher Fonseka on 13/12/2014.
//  Copyright (c) 2014 ROLI. All rights reserved.
//

#import "GameScene.h"
#import "Seaboard.h"
#import "MIDIMessage.h"

enum ColliderType
{
	ColliderCategoryBlock = 1,
	ColliderCategoryBall  = 2
};

@interface GameScene () <SKPhysicsContactDelegate, SeaboardDelegate>
{
	int noteValue;
	int pbOffset;
}

@property (nonatomic, retain) Seaboard* seaboard;

@end


@implementation GameScene

// MIDI Stuff
const int kStartOctave = 1;

// Boundry Information
const int kMIDILeft  = 48;
const int kMIDIRight = 72;

// Block Info
const CGFloat kBlockGridSize	= 16;
const CGFloat kBlockRatio		= 0.4;
const CGFloat kBlockGridMargin	= 1;

// Paddle Info
const CGFloat kPaddleWidth	= 120;
const CGFloat kPaddleHeight	= 14;
const CGFloat kPaddleInset	= 40;

// Ball Info
const CGFloat kBallRadius	= 6;
const CGFloat kBallVelocityX= 600;
const CGFloat kBallVelocityY= 600;

//======================================================================
#pragma mark Footer Guide
//======================================================================

//======================================================================
#pragma mark Blocks
//======================================================================

- (SKNode*)newBlock:(CGFloat)width :(CGFloat)height
{
	SKSpriteNode *block = [SKSpriteNode spriteNodeWithColor:[SKColor colorWithRed:57/255.0 green:127/255.0 blue:186/255.0 alpha:1.0] size:CGSizeMake(width, height)];
	block.name = @"Block";
	block.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:block.size];
	block.physicsBody.dynamic = false;
	block.physicsBody.categoryBitMask = ColliderCategoryBlock;
	
	[self addChild:block];
	return block;
}

- (void)addBlocks:(int)rows
{
	const CGFloat blockAreaWidth  = kBlockRatio * CGRectGetWidth(self.frame);
	const CGFloat blockAreaHeight = kBlockRatio * CGRectGetHeight(self.frame);
	
	const int xStart = (CGRectGetWidth(self.frame)  - blockAreaWidth)  / 2.f;
	const int yStart = (CGRectGetHeight(self.frame) - blockAreaHeight) / 2.f;
	
	const CGFloat blockWidth  = blockAreaWidth  / kBlockGridSize - kBlockGridMargin;
	const CGFloat blockHeight = blockAreaHeight / kBlockGridSize - kBlockGridMargin;
	
	for (CGFloat x = xStart; x < blockAreaWidth + xStart; x += blockWidth + kBlockGridMargin)
	{
		for (CGFloat y = yStart; y < blockAreaHeight + yStart; y += blockHeight + kBlockGridMargin)
		{
			SKNode *block = [self newBlock:blockWidth :blockHeight];
			block.position = CGPointMake(x, y);
		}
	}
}

- (void)blockTouched:(SKNode*) block
{
	[block removeFromParent];
}

//======================================================================
#pragma mark Paddle
//======================================================================

- (CGPoint)getStartPositionForPaddle:(int)identifier
{
	switch (identifier)
	{
		case 1: return CGPointMake(CGRectGetMidX(self.frame), kPaddleInset);
		case 2: return CGPointMake(CGRectGetMidX(self.frame), CGRectGetHeight(self.frame) - kPaddleInset);
		case 3: return CGPointMake(kPaddleInset, CGRectGetMidY(self.frame));
		case 4: return CGPointMake(CGRectGetWidth(self.frame) - kPaddleInset, CGRectGetMidY(self.frame));
	}
	return CGPointMake(0, 0);
}

- (CGSize)getSizeForPaddle:(int)identifier
{
	switch (identifier)
	{
		case 1: return CGSizeMake(kPaddleWidth, kPaddleHeight);
		case 2: return CGSizeMake(kPaddleWidth, kPaddleHeight);
		case 3: return CGSizeMake(kPaddleHeight, kPaddleWidth);
		case 4: return CGSizeMake(kPaddleHeight, kPaddleWidth);
	}
	return CGSizeMake(0, 0);
}

- (void)addPaddles
{
	for (int i = 1; i <= 4; i++)
	{
		SKSpriteNode *paddle = [SKSpriteNode spriteNodeWithColor:[SKColor greenColor] size:[self getSizeForPaddle:i]];
		paddle.name = [NSString stringWithFormat:@"Paddle%d", i];
		paddle.position = [self getStartPositionForPaddle:i];
		paddle.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:paddle.size];
		paddle.physicsBody.dynamic = false;
		[self addChild:paddle];
	}
}

- (SKNode*)paddleNode:(int)identifier
{
	return [self childNodeWithName:[NSString stringWithFormat:@"Paddle%d",identifier]];
}

//======================================================================
#pragma mark Ball
//======================================================================

- (void)addBall
{
	SKShapeNode *ball = [SKShapeNode node];
	ball.name = @"Ball";
	ball.position = CGPointMake(CGRectGetMidX(self.frame),
								CGRectGetMaxY(self.frame));
	
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathAddArc(path, nil, 0, 0, kBallRadius, 0, M_PI * 2.0, true);
	ball.path = path;
	ball.fillColor = [SKColor yellowColor];
	ball.strokeColor = [SKColor clearColor];
	
	ball.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:kBallRadius];
	ball.physicsBody.affectedByGravity = false;
	ball.physicsBody.velocity = CGVectorMake(kBallVelocityX, kBallVelocityY);
	ball.physicsBody.friction = 0;
	ball.physicsBody.restitution = 1;
	ball.physicsBody.linearDamping = 0;
	ball.physicsBody.allowsRotation = false;
	ball.physicsBody.usesPreciseCollisionDetection = true;
	ball.physicsBody.categoryBitMask = ColliderCategoryBall;
	ball.physicsBody.contactTestBitMask = ColliderCategoryBlock;
	
	[self addChild:ball];
}

- (SKNode*)ballNode
{
	return [self childNodeWithName:@"Ball"];
}

//======================================================================
#pragma mark Game Mechanics
//======================================================================

- (void)didBeginContact:(SKPhysicsContact *)contact
{
	SKPhysicsBody *firstBody;
	SKPhysicsBody *secondBody;
	
	if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask)
	{
		firstBody = contact.bodyA;
		secondBody = contact.bodyB;
	}
	else
	{
		firstBody = contact.bodyB;
		secondBody = contact.bodyA;
	}
	
	if (firstBody.categoryBitMask & ColliderCategoryBlock)
	{
		if (secondBody.categoryBitMask & ColliderCategoryBall)
		{
			[self blockTouched:firstBody.node];
		}
	}
}

- (void)gameOver
{
	[[self ballNode] removeFromParent];
}

- (void)didSimulatePhysics
{
	if ([self ballNode] != nil &&
		[self ballNode].position.y < (kBallRadius * 2.0))
	{
		[self gameOver];
	}
}

//======================================================================
#pragma mark Seaboard Code
//======================================================================


- (void)seaboardDidGetMIDIMessage:(MIDIMessage *)message
{
	if (message.messageType == MIDIMessageTypeNoteOn)
	{
		noteValue = message.noteNo;
//		[self movePaddle:[self getPaddleForMidiNote:noteValue]];
	}
	else if (message.messageType == MIDIMessageTypePitchBend)
	{
		pbOffset = message.pitchbend;
//		[self movePaddle:[self getPaddleForMidiNote:noteValue]];
	}
}


//======================================================================
#pragma mark Class Setup
//======================================================================

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self)
	{
		noteValue = 0;
		pbOffset = 0;
		
		_seaboard = [[Seaboard alloc] init];
		
		self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
		self.physicsBody.friction = 0.0;
		self.physicsWorld.contactDelegate = self;
		
		[self addBlocks:6];
		[self addPaddles];

		
		_seaboard.delegate = self;
		[_seaboard connect];
		
		self.backgroundColor = [SKColor colorWithRed:50/255.0 green:61/255.0 blue:71/255.0 alpha:1.0];
	}
	return self;
}

-(void)mouseDown:(NSEvent *)theEvent {
	if ([self ballNode] == nil)
	{
		[self addBall];
	}
}

-(void)update:(CFTimeInterval)currentTime {
	/* Called before each frame is rendered */
}

@end
