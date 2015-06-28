//
//  JWHexColor.m
//  JWHexColor
//
//  Created by John Wong on 6/29/15.
//  Copyright (c) 2015 John Wong. All rights reserved.
//

#import "JWHexColor.h"
#import "JWColorFrameView.h"
#import "JWPlainColorWell.h"

NSString *const kJWColorHelperHighlightingDisabled   = @"JWColorHelperHighlightingDisabled";

@interface JWHexColor()

@property (nonatomic, strong, readwrite) NSBundle *bundle;

@end

@implementation JWHexColor

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource access
        self.bundle = plugin;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didApplicationFinishLaunchingNotification:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
        _selectedColorRange = NSMakeRange(NSNotFound, 0);
        
        _rgbaUIColorRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[\\s*UIColor\\s+colorWithRGB:\\s*(0x[0-9a-fA-F]*|[0-9]*)(\\s*alpha:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?)?\\s*\\]" options:0 error:NULL];
        _hexColorRegex = [NSRegularExpression regularExpressionWithPattern:@"HEXCOLOR\\(\\s*(0x[0-9a-fA-F]*|[0-9]*)\\s*\\)" options:0 error:NULL];
        _hexaColorRegex = [NSRegularExpression regularExpressionWithPattern:@"HEXCOLORA\\(\\s*(0x[0-9a-fA-F]*|[0-9]*)\\s*,\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\)" options:0 error:NULL];
    }
    return self;
}

- (void)didApplicationFinishLaunchingNotification:(NSNotification*)noti
{
    //removeObserver
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
    
    NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
    if (editMenuItem) {
        [[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *toggleColorHighlightingMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show Hex Colors Under Caret" action:@selector(toggleColorHighlightingEnabled:) keyEquivalent:@""];
        [toggleColorHighlightingMenuItem setTarget:self];
        [[editMenuItem submenu] addItem:toggleColorHighlightingMenuItem];
    }
    
    BOOL highlightingEnabled = ![[NSUserDefaults standardUserDefaults] boolForKey:kJWColorHelperHighlightingDisabled];
    if (highlightingEnabled) {
        [self activateColorHighlighting];
    }
}

#pragma mark - Preferences

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(toggleColorHighlightingEnabled:)) {
        BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kJWColorHelperHighlightingDisabled];
        [menuItem setState:enabled ? NSOffState : NSOnState];
        return YES;
    }
    return YES;
}

- (void)toggleColorHighlightingEnabled:(id)sender
{
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kJWColorHelperHighlightingDisabled];
    [[NSUserDefaults standardUserDefaults] setBool:!enabled forKey:kJWColorHelperHighlightingDisabled];
    if (enabled) {
        [self activateColorHighlighting];
    } else {
        [self deactivateColorHighlighting];
    }
}

- (void)activateColorHighlighting
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectionDidChange:) name:NSTextViewDidChangeSelectionNotification object:nil];
    if (!self.textView) {
        NSResponder *firstResponder = [[NSApp keyWindow] firstResponder];
        if ([firstResponder isKindOfClass:NSClassFromString(@"DVTSourceTextView")] && [firstResponder isKindOfClass:[NSTextView class]]) {
            self.textView = (NSTextView *)firstResponder;
        }
    }
    if (self.textView) {
        NSNotification *notification = [NSNotification notificationWithName:NSTextViewDidChangeSelectionNotification object:self.textView];
        [self selectionDidChange:notification];
        
    }
}

- (void)deactivateColorHighlighting
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextViewDidChangeSelectionNotification object:nil];
    [self dismissColorWell];
    //self.textView = nil;
}

#pragma mark - Text Selection Handling

- (void)selectionDidChange:(NSNotification *)notification
{
    if ([[notification object] isKindOfClass:NSClassFromString(@"DVTSourceTextView")] && [[notification object] isKindOfClass:[NSTextView class]]) {
        self.textView = (NSTextView *)[notification object];
        
        BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kJWColorHelperHighlightingDisabled];
        if (disabled) return;
        
        NSArray *selectedRanges = [self.textView selectedRanges];
        if (selectedRanges.count >= 1) {
            NSRange selectedRange = [[selectedRanges objectAtIndex:0] rangeValue];
            NSString *text = self.textView.textStorage.string;
            NSRange lineRange = [text lineRangeForRange:selectedRange];
            NSRange selectedRangeInLine = NSMakeRange(selectedRange.location - lineRange.location, selectedRange.length);
            NSString *line = [text substringWithRange:lineRange];
            
            NSRange colorRange = NSMakeRange(NSNotFound, 0);
            JWColorType colorType = JWColorTypeNone;
            NSColor *matchedColor = [self colorInText:line selectedRange:selectedRangeInLine type:&colorType matchedRange:&colorRange];
            
            if (matchedColor) {
                NSColor *backgroundColor = [self.textView.backgroundColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
                CGFloat r = 1.0; CGFloat g = 1.0; CGFloat b = 1.0;
                [backgroundColor getRed:&r green:&g blue:&b alpha:NULL];
                CGFloat backgroundLuminance = (r + g + b) / 3.0;
                
                NSColor *strokeColor = (backgroundLuminance > 0.5) ? [NSColor colorWithCalibratedWhite:0.2 alpha:1.0] : [NSColor whiteColor];
                
                self.selectedColorType = colorType;
                self.colorWell.color = matchedColor;
                self.colorWell.strokeColor = strokeColor;
                
                self.selectedColorRange = NSMakeRange(colorRange.location + lineRange.location, colorRange.length);
                NSRect selectionRectOnScreen = [self.textView firstRectForCharacterRange:self.selectedColorRange];
                NSRect selectionRectInWindow = [self.textView.window convertRectFromScreen:selectionRectOnScreen];
                NSRect selectionRectInView = [self.textView convertRect:selectionRectInWindow fromView:nil];
                NSRect colorWellRect = NSMakeRect(NSMaxX(selectionRectInView) - 49, NSMinY(selectionRectInView) - selectionRectInView.size.height - 2, 50, selectionRectInView.size.height + 2);
                self.colorWell.frame = NSIntegralRect(colorWellRect);
                [self.textView addSubview:self.colorWell];
                self.colorFrameView.frame = NSInsetRect(NSIntegralRect(selectionRectInView), -1, -1);
                
                self.colorFrameView.color = strokeColor;
                
                [self.textView addSubview:self.colorFrameView];
            } else {
                [self dismissColorWell];
            }
        } else {
            [self dismissColorWell];
        }
    }
}

- (void)dismissColorWell
{
    if (self.colorWell.isActive) {
        [self.colorWell deactivate];
        [[NSColorPanel sharedColorPanel] orderOut:nil];
    }
    [self.colorWell removeFromSuperview];
    [self.colorFrameView removeFromSuperview];
    self.selectedColorRange = NSMakeRange(NSNotFound, 0);
    self.selectedColorType = JWColorTypeNone;
}

- (void)colorDidChange:(id)sender
{
    if (self.selectedColorRange.location == NSNotFound) {
        return;
    }
    NSString *colorString = [self colorStringForColor:self.colorWell.color withType:self.selectedColorType];
    if (colorString) {
        [self.textView.undoManager beginUndoGrouping];
        [self.textView insertText:colorString replacementRange:self.selectedColorRange];
        [self.textView.undoManager endUndoGrouping];
    }
}

#pragma mark - View Initialization

- (JWPlainColorWell *)colorWell
{
    if (!_colorWell) {
        _colorWell = [[JWPlainColorWell alloc] initWithFrame:NSMakeRect(0, 0, 50, 30)];
        [_colorWell setTarget:self];
        [_colorWell setAction:@selector(colorDidChange:)];
    }
    return _colorWell;
}

- (JWColorFrameView *)colorFrameView
{
    if (!_colorFrameView) {
        _colorFrameView = [[JWColorFrameView alloc] initWithFrame:NSZeroRect];
    }
    return _colorFrameView;
}

#pragma mark - Color String Parsing

- (NSColor *)colorInText:(NSString *)text selectedRange:(NSRange)selectedRange type:(JWColorType *)type matchedRange:(NSRangePointer)matchedRange
{
    __block NSColor *foundColor = nil;
    __block NSRange foundColorRange = NSMakeRange(NSNotFound, 0);
    __block JWColorType foundColorType = JWColorTypeNone;
    
    [_rgbaUIColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSRange colorRange = [result range];
        if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
            NSString *typeIndicator = [text substringWithRange:[result rangeAtIndex:0]];
            if ([typeIndicator rangeOfString:@"alpha:"].location != NSNotFound) {
                foundColorType = JWColorTypeUIRGBA;
            } else {
                foundColorType = JWColorTypeUIRGB;
            }
            
            // [UIColor colorWithRGB:0xf5f5f9 alpha:1.0];
            unsigned int rgbValue;
            NSScanner* scanner = [NSScanner scannerWithString:[text substringWithRange:[result rangeAtIndex:1]]];
            [scanner scanHexInt:&rgbValue];
            
            double alpha = 1.0;
            if ([result rangeAtIndex:3].location != NSNotFound) {
                alpha = [[text substringWithRange:[result rangeAtIndex:3]] doubleValue];
                alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:4] inString:text];
            }
            foundColor = [NSColor colorWithCalibratedRed:((rgbValue & 0xFF0000) >> 16) / 255.0 green:((rgbValue & 0xFF00) >> 8) / 255.0 blue:(rgbValue & 0xFF) / 255.0 alpha:alpha];
            foundColorRange = colorRange;
            *stop = YES;
        }
    }];
    
    if (!foundColor) {
        [_hexColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSRange colorRange = [result range];
            if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
                foundColorType = JWColorTypeHEXRGB;
                
                // HEXCOLOR(0xf5f5f9)
                unsigned int rgbValue;
                NSScanner* scanner = [NSScanner scannerWithString:[text substringWithRange:[result rangeAtIndex:1]]];
                [scanner scanHexInt:&rgbValue];
                foundColor = [NSColor colorWithCalibratedRed:((rgbValue & 0xFF0000) >> 16) / 255.0 green:((rgbValue & 0xFF00) >> 8) / 255.0 blue:(rgbValue & 0xFF) / 255.0 alpha:1.0];
                foundColorRange = colorRange;
                *stop = YES;
            }
        }];
    }
    
    if (!foundColor) {
        [_hexaColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSRange colorRange = [result range];
            if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
                foundColorType = JWColorTypeHEXRGBA;
                
                // HEXCOLORA(0xff0000, 0.5)
                unsigned int rgbValue;
                NSScanner* scanner = [NSScanner scannerWithString:[text substringWithRange:[result rangeAtIndex:1]]];
                [scanner scanHexInt:&rgbValue];
                double alpha = 1.0;
                if ([result rangeAtIndex:2].location != NSNotFound) {
                    alpha = [[text substringWithRange:[result rangeAtIndex:2]] doubleValue];
                    alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:3] inString:text];
                }
                foundColor = [NSColor colorWithCalibratedRed:((rgbValue & 0xFF0000) >> 16) / 255.0 green:((rgbValue & 0xFF00) >> 8) / 255.0 blue:(rgbValue & 0xFF) / 255.0 alpha:alpha];
                foundColorRange = colorRange;
                *stop = YES;
            }
        }];
    }
    
    if (foundColor) {
        if (matchedRange != NULL) {
            *matchedRange = foundColorRange;
        }
        if (type != NULL) {
            *type = foundColorType;
        }
        return foundColor;
    }
    
    return nil;
}

- (double)dividedValue:(double)value withDivisorRange:(NSRange)divisorRange inString:(NSString *)text
{
    if (divisorRange.location != NSNotFound) {
        double divisor = [[[text substringWithRange:divisorRange] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/ "]] doubleValue];
        if (divisor != 0) {
            value /= divisor;
        }
    }
    return value;
}

- (NSString *)colorStringForColor:(NSColor *)color withType:(JWColorType)colorType
{
    NSString *colorString = nil;
    CGFloat red = -1.0; CGFloat green = -1.0; CGFloat blue = -1.0; CGFloat alpha = -1.0;
    color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    red = round(red * 255);
    green = round(green * 255);
    blue = round(blue * 255);
    if (red >= 0) {
        if (self.selectedColorType == JWColorTypeUIRGB) {
            colorString = [NSString stringWithFormat:@"[UIColor colorWithRGB:0x%02x%02x%02x]", (int)red, (int)green, (int)blue];
        } else if (self.selectedColorType == JWColorTypeUIRGBA) {
            colorString = [NSString stringWithFormat:@"[UIColor colorWithRGB:0x%02x%02x%02x alpha:%.3f]", (int)red, (int)green, (int)blue, alpha];
        } else if (self.selectedColorType == JWColorTypeHEXRGB) {
            colorString = [NSString stringWithFormat:@"HEXCOLOR(0x%02x%02x%02x)", (int)red, (int)green, (int)blue];
        } else if (self.selectedColorType == JWColorTypeHEXRGBA) {
            colorString = [NSString stringWithFormat:@"HEXCOLORA(0x%02x%02x%02x, %.3f)", (int)red, (int)green, (int)blue, alpha];
        }
    }
    return colorString;
}

#pragma mark -

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
