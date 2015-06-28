//
//  JWPlainColorWell.h
//  JWColorHelper
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import <Cocoa/Cocoa.h>

@interface JWPlainColorWell : NSColorWell {

	NSColor *_strokeColor;
}

@property (nonatomic, strong) NSColor *strokeColor;

@end
