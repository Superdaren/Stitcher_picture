//
//  PixelSeamFinder.m
//  Stitcher
//
//  Created by yglin on 17/4/5.
//  Copyright © 2017年 ymtx. All rights reserved.
//

#import "PixelSeamFinder.h"

#define kBitsPerComponent (8)
#define kBitsPerPixel (32)
#define kPixelChannelCount (4)

#define KRoi (80)
#define KOffSet (65)
#define KPixelOffSet (40)
#define Kscale (0.5)

@implementation PixelSeamFinder

/**
 * 根据要拼接的图片和拼接类型找到对应的拼接点
 * imageArray     要拼接的数据
 * stitcherType   拼接的类型(竖拼,横拼,自动拼接)
 */
+ (void)findInImages:(NSMutableArray<SFImage *> *)imageArray withStitcherType:(StitcherType) stitcherType completion:(void (^)(NSArray<SFMatchesPair *> *, StitcherOrderType orderType, NSError *))completion {

    CGFloat time1 = CACurrentMediaTime();
    
    NSMutableArray *matchesPairArr = [NSMutableArray array];
    StitcherOrderType orderType = StitcherOrderForwardType;
    
    if (imageArray.count < 2) {
        completion(nil,orderType,nil);
        return;
    }
    
    if (stitcherType == StitcherAutoType) {        // 如果是自动拼接的要先判断下是正序排还是倒序排列
        SFMatchesPair *firstMatchesPair = [self findMatchesPairWithFirstImage:imageArray[0] secondImage:imageArray[1] index:1];
        SFMatchesPair *secondMatchesPair = [self findMatchesPairWithFirstImage:imageArray[1] secondImage:imageArray[0] index:1];
        if (firstMatchesPair.secondImageSeam.point.y < secondMatchesPair.secondImageSeam.point.y) {
            orderType = StitcherOrderBackType;
        }
    }
    
    if (orderType == StitcherOrderForwardType) {
        for (int i = 1; i < imageArray.count; i ++) {
            SFMatchesPair *matchesPair = [self findMatchesPairWithFirstImage:imageArray[i - 1] secondImage:imageArray[i] index:i];
            [matchesPairArr addObject:matchesPair];
        }
    } else {
        NSArray<SFImage *> *imageArray1 = [imageArray.reverseObjectEnumerator allObjects];
        for (int i = 1; i < imageArray.count; i ++) {
            SFMatchesPair *matchesPair = [self findMatchesPairWithFirstImage:imageArray1[i - 1] secondImage:imageArray1[i] index:i];
            [matchesPairArr addObject:matchesPair];
        }
    }
    
    CGFloat time2 = CACurrentMediaTime();
    CGFloat time = time2 - time1;
    NSLog(@"spend time  = %f", time);
    completion(matchesPairArr,orderType,nil);
}

/**
 * 对比两张图片寻找到拼接的点
 * firstImage    第一张图片
 * secondImage   第二张图片
 * index         图片拼接到对应位置的索引
 */
+ (SFMatchesPair *)findMatchesPairWithFirstImage:(SFImage *) firstImage secondImage:(SFImage *) secondImage index:(int) index {
    //获取BitmapData
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    //    UIImage *firstImageS = [self scaleImage:firstImage.image scale:Kscale];
    //    UIImage *secondImageS = [self scaleImage:secondImage.image scale:Kscale];
    CGImageRef firstImgRef = firstImage.image.CGImage;
    CGImageRef SecondImgRef = secondImage.image.CGImage;
    CGFloat width = CGImageGetWidth(firstImgRef);
    CGFloat firstH = CGImageGetHeight(firstImgRef);
    CGFloat secondH = CGImageGetHeight(SecondImgRef);
    
    CGContextRef firstContext = CGBitmapContextCreate (NULL,
                                                       width,
                                                       firstH,
                                                       kBitsPerComponent,        //每个颜色值8bit
                                                       width*kPixelChannelCount, //每一行的像素点占用的字节数，每个像素点的ARGB四个通道各占8个bit
                                                       colorSpace,
                                                       kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(firstContext, CGRectMake(0, 0, width, firstH), firstImgRef);
    unsigned char *firstBitmapData = CGBitmapContextGetData (firstContext);
    
    CGContextRef secondContext = CGBitmapContextCreate (NULL,
                                                        width,
                                                        secondH,
                                                        kBitsPerComponent,        //每个颜色值8bit
                                                        width*kPixelChannelCount, //每一行的像素点占用的字节数，每个像素点的ARGB四个通道各占8个bit
                                                        colorSpace,
                                                        kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(secondContext, CGRectMake(0, 0, width, secondH), SecondImgRef);
    unsigned char *secondBitmapData = CGBitmapContextGetData (secondContext);
    
    int tabBarH = [self findTabBarHeightWithFirstBitMap:firstBitmapData secondBitMap:secondBitmapData width:width firstH:firstH secondH:secondH];
    
    //NSLog(@"--------------tabBarH%i", tabBarH);
    
    NSArray *pointArr = [self getPointWithFirstBitMap:firstBitmapData secondBitMap:secondBitmapData tabHeight:tabBarH width:width firstH:firstH secondH:secondH];
    
    SFSeam *seam1 = [[SFSeam alloc] init];
    seam1.imgIndex = index - 1;
    seam1.point = CGPointMake(0, [pointArr[0] floatValue]);
    
    SFSeam *seam2 = [[SFSeam alloc] init];
    seam2.imgIndex = index;
    seam2.point = CGPointMake(0, [pointArr[1] floatValue]);
    
    SFMatchesPair *ocMatchesPair = [[SFMatchesPair alloc] init];
    ocMatchesPair.firstImageSeam = seam1;
    ocMatchesPair.secondImageSeam = seam2;
    ocMatchesPair.pairIndex = index;
    
    CGContextRelease(firstContext);
    CGContextRelease(secondContext);
    //    CGImageRelease(firstImgRef);
    //    CGImageRelease(SecondImgRef);
    //    CGImageRelease(SecondImgRef);      //第二个不能释放,防止产生坏内存
    
    return ocMatchesPair;
}

/**
 * 根据两张图片的bitmap,匹配两张图片的拼接point
 * firstBitmap    第一张图片bitmap
 * secondBitmap   第二张图片bitmap
 * tabBarH        第一张图片的tabBar高度
 * width          两张图片的宽度
 * firstH         第一张图片的高度
 * secondH        第二张图片的高度
 */
+ (NSArray *)getPointWithFirstBitMap:(unsigned char *) firstBitmap secondBitMap:(unsigned char *) secondBitmap tabHeight:(int) tabBarH width:(CGFloat) width firstH:(int) firstH secondH:(int) secondH  {
    
    BOOL isMatchPixel = false;
    NSMutableArray *point = [NSMutableArray array];
    [point addObject:@(firstH - tabBarH - 1)];
    [point addObject:@(0)];
    
    //    CGFloat minH = firstH < secondH ? firstH : secondH;       //采用高度小的来循环，防止高度高的地址溢出
    
    for (int i = tabBarH + KRoi; i > tabBarH; i -= 2) {
        if ([point[1] floatValue] != 0) {               // 已经找到终止循环
            break;
        }
        if (i - tabBarH < 20) {                      //匹配长度要大于100
            break;
        }
        for (int h = 0; h < secondH - tabBarH - KRoi; h ++) {      //第二张图片从上往下循环到tabbar + KRoi区域
            if ([point[1] floatValue] != 0) {           // 已经找到终止循环
                break;
            }
            for (int w = 0; w < width; w += KOffSet) {
                int FirstIndex = w + width * (firstH - i);
                int SecondIndex = w + (width * h);
                
                isMatchPixel = [self isMatchPixelWithFirstBitMap:firstBitmap secondBitMap:secondBitmap FirstIndex:FirstIndex secondIndex:SecondIndex];
                if (!isMatchPixel) {
                    break;
                }
                
                if (w + KOffSet > width) {
                    //NSLog(@"---------height=%i, %i", h, i);
                    isMatchPixel = [self checkPixelWithFirstBitMap:firstBitmap secondBitMap:secondBitmap tabHeight:tabBarH width:width firstH:firstH secondH:secondH firstH:i secondH:h];
                    if (isMatchPixel) {
                        [point removeAllObjects];
                        [point addObject:@(firstH - tabBarH - 1)];
                        [point addObject:@(h + i - tabBarH)];
                        break;
                    }
                }
            }
        }
    }
    
    return point;
}

/**
 * 根据两张图片的已经对比的相同的拼接缝处开始对比
 * firstBitmap    第一张图片bitmap
 * secondBitmap   第二张图片bitmap
 * tabBarH        第一张图片的tabBar高度
 * width          两张图片的宽度
 * firstH         第一张图片的高度
 * secondH        第二张图片的高度
 * firstSeamH     第一张图片从firstSeamH高度开始匹配
 * secondSeamH    第二张图片从secondSeamH高度开始匹配
 */
+ (BOOL) checkPixelWithFirstBitMap:(unsigned char *) firstBitmap secondBitMap:(unsigned char *) secondBitmap tabHeight:(int) tabBarH width:(CGFloat) width firstH:(int) firstH secondH:(int) secondH  firstH:(int) firstSeamH secondH:(int) secondSeamH {
    
    BOOL isMatchPixel = true;
    for (int h = firstSeamH; h > tabBarH; h --) {
        if (secondSeamH + firstSeamH - h >= secondH) {        //循环到第二张图片到底部的时候就停止,否则会越界
            break;
        }
        if (!isMatchPixel) {                         //不匹配直接终止循环
            break;
        }
        for (int w = 0; w < width; w += KOffSet) {
            int FirstIndex = w + width * (firstH - h);
            int SecondIndex = w + width * (secondSeamH + firstSeamH - h + 1);
            //NSLog(@"------------%i", SecondIndex);
            
            isMatchPixel = [self isMatchPixelWithFirstBitMap:firstBitmap secondBitMap:secondBitmap FirstIndex:FirstIndex secondIndex:SecondIndex];
            if (!isMatchPixel) {
                isMatchPixel = false;
                break;
            }
        }
    }
    
    return isMatchPixel;
}

/**
 * 判断两个像素点是否一样
 * firstBitmap    第一张图片bitmap
 * secondBitmap   第二张图片bitmap
 * firstIndex     第一个像素点的位置
 * secondBitmap   第二个像素点的位置
 */
+ (BOOL) isMatchPixelWithFirstBitMap:(unsigned char *) firstBitmap secondBitMap:(unsigned char *) secondBitmap FirstIndex:(int) firstIndex secondIndex:(int) secondIndex {
    unsigned char firstPixel[kPixelChannelCount] = {0};
    unsigned char secondPixel[kPixelChannelCount] = {0};
    int offSet = KPixelOffSet;
    int r1 = 0;
    int b1 = 0;
    int g1 = 0;
    int r2 = 0;
    int b2 = 0;
    int g2 = 0;
    int r = 0;
    int g = 0;
    int b = 0;
    
    //NSLog(@"-------%i", firstIndex);
    memcpy(firstPixel, firstBitmap + kPixelChannelCount * firstIndex, kPixelChannelCount);
    memcpy(secondPixel, secondBitmap + kPixelChannelCount * secondIndex, kPixelChannelCount);
    
    r1 = firstPixel[0];
    b1 = firstPixel[1];
    g1 = firstPixel[2];
    
    r2 = secondPixel[0];
    b2 = secondPixel[1];
    g2 = secondPixel[2];
    
    r = r1 - r2;
    g = g1 - g2;
    b = b1 - b2;
    r = abs(r);
    g = abs(g);
    b = abs(b);
    
    if (r < offSet && g < offSet && b < offSet) {
        //NSLog(@"-----r=%i",g);
        return true;
    }
    
    return false;
}

/**
 * 寻找tabbar的高度
 * firstBitmap    第一张图片bitmap
 * secondBitmap   第二张图片bitmap
 * width          两张图片的宽度
 * firstH         第一个张图片的高度
 * secondH        第二个张图片的高度
 */
+ (CGFloat)findTabBarHeightWithFirstBitMap:(unsigned char *) firstBitmap secondBitMap:(unsigned char *) secondBitmap width:(CGFloat) width firstH:(CGFloat) firstH secondH:(CGFloat) secondH {
    
    int tabBarH = 0;
    BOOL isMatchPixel = false;
    
    CGFloat minH = firstH < secondH ? firstH : secondH;       //采用高度小的来循环，防止高度高的地址溢出
    
    for (int h = 0; h < minH / 5; h += 2) {
        if (tabBarH != 0) {
            break;
        }
        for (int w = 0; w < width; w += KOffSet) {
            int firstIndex = firstH * width - (w + width * h);
            int secondIndex = secondH * width - (w + width * h);
            
            isMatchPixel = [self isMatchPixelWithFirstBitMap:firstBitmap secondBitMap:secondBitmap FirstIndex:firstIndex secondIndex:secondIndex];
            
            if (!isMatchPixel) {
                tabBarH = h + 1;
                break;
            }
        }
    }
    return tabBarH;
}

/**
 * 寻找navBar的高度(此方法暂时没有用)
 * firstBitmap    第一张图片bitmap
 * secondBitmap   第二张图片bitmap
 * width          两张图片的宽度
 * firstH         第一个张图片的高度
 * secondH        第二个张图片的高度
 */
+ (CGFloat)findNavBarHeightWithFirstBitMap:(unsigned char *) firstBitmap secondBitMap:(unsigned char *) secondBitmap width:(CGFloat) width Height:(CGFloat) height {
    
    int navBarH = 0;
    BOOL isMatchPixel = false;
    
    for (int h = 0; h < height; h ++) {
        if (navBarH != 0) {
            break;
        }
        for (int w = 0; w < width; w += KOffSet) {
            int index = w + width * h;
            
            isMatchPixel = [self isMatchPixelWithFirstBitMap:firstBitmap secondBitMap:secondBitmap FirstIndex:index secondIndex:index];
            
            if (!isMatchPixel) {
                navBarH = h;
            }
        }
    }
    return navBarH;
}

@end
