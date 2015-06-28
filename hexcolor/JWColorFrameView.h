//
//  JWColorFrameView.h
//  JWColorHelper
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import <Cocoa/Cocoa.h>

@interface JWColorFrameView : NSView {

	NSColor *_color;
}

@property (nonatomic, strong) NSColor *color;

@end
