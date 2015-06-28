//
//  NSObject_Extension.m
//  JWIconfont
//
//  Created by John Wong on 6/28/15.
//  Copyright (c) 2015 John Wong. All rights reserved.
//


#import "NSObject_Extension.h"
#import "JWHexColor.h"

@implementation NSObject (Xcode_Plugin_Template_Extension)

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[JWHexColor alloc] initWithBundle:plugin];
        });
    }
}
@end
