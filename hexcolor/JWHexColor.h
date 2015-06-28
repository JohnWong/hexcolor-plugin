//
//  JWHexColor.h
//  JWHexColor
//
//  Created by John Wong on 6/29/15.
//  Copyright (c) 2015 John Wong. All rights reserved.
//

#import <AppKit/AppKit.h>

typedef enum JWColorType {
    
    JWColorTypeNone = 0,
    JWColorTypeUIRGB,				//[UIColor colorWithRGB:0xf5f5f9]
    JWColorTypeUIRGBA,				//[UIColor colorWithRGB:0xf5f5f9 alpha:0.5]
    JWColorTypeHEXRGB,				//HEXCOLOR(0xf5f5f9)
    JWColorTypeHEXRGBA,				//HEXCOLORA(0xf5f5f9, 0.5)
    
} JWColorType;

@class JWHexColor, JWColorFrameView, JWPlainColorWell;

static JWHexColor *sharedPlugin;

@interface JWHexColor : NSObject {
    NSRegularExpression *_rgbaUIColorRegex;
    NSRegularExpression *_hexColorRegex;
    NSRegularExpression *_hexaColorRegex;
}

@property (nonatomic, strong) JWPlainColorWell *colorWell;
@property (nonatomic, strong) JWColorFrameView *colorFrameView;
@property (nonatomic, strong) NSTextView *textView;
@property (nonatomic, assign) NSRange selectedColorRange;
@property (nonatomic, assign) JWColorType selectedColorType;
@property (nonatomic, strong, readonly) NSBundle* bundle;

+ (instancetype)sharedPlugin;
- (id)initWithBundle:(NSBundle *)plugin;
- (void)dismissColorWell;
- (void)activateColorHighlighting;
- (void)deactivateColorHighlighting;
- (NSColor *)colorInText:(NSString *)text selectedRange:(NSRange)selectedRange type:(JWColorType *)type matchedRange:(NSRangePointer)matchedRange;
- (NSString *)colorStringForColor:(NSColor *)color withType:(JWColorType)colorType;
- (double)dividedValue:(double)value withDivisorRange:(NSRange)divisorRange inString:(NSString *)text;

@end