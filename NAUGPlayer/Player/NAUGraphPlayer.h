//
//  NAUGraphPlayer.h
//  NAUGPlayer
//
//  Created by 泽娄 on 2019/9/18.
//  Copyright © 2019 泽娄. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NAUGraphPlayer : NSObject

- (instancetype)initWithFilePath:(NSString *)path;

- (BOOL)play;

- (void)stop;

- (void)setInputSource:(BOOL)isAcc;

- (double)getCurrentTime;

@end

NS_ASSUME_NONNULL_END
