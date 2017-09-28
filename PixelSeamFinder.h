//
//  PixelSeamFinder.h
//  Stitcher
//
//  Created by yglin on 17/4/5.
//  Copyright © 2017年 ymtx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFImage.h"
#import "SFMatchesPair.h"
#import "STStitchManager.h"

typedef NS_ENUM(NSInteger, StitcherOrderType) {
    StitcherOrderForwardType = 1,
    StitcherOrderBackType = 2,
};

@interface PixelSeamFinder : NSObject

+ (void)findInImages:(NSArray<SFImage *> *)imageArray withStitcherType:(StitcherType) stitcherType completion:(void (^)(NSArray<SFMatchesPair *>* result, StitcherOrderType orderType, NSError *error))completion;

@end
