//
//  JWColorFrameView.m
//  JWColorHelper
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import "JWColorFrameView.h"

@implementation JWColorFrameView

@synthesize color=_color;

- (void)drawRect:(NSRect)dirtyRect
{
	[self.color setStroke];
	[NSBezierPath strokeRect:NSInsetRect(self.bounds, 0.5, 0.5)];
}

- (void)setColor:(NSColor *)color
{
	if (color != _color) {
		_color = color;
		[self setNeedsDisplay:YES];
	}
}


@end
