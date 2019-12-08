//
//  NAudioUnit.h
//  NAudioUnit
//
//  Created by 泽娄 on 2019/9/18.
//  Copyright © 2019 泽娄. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal)
{
    if(status != noErr)
    {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';

        if(isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
            NSLog(@"%@: %s", message, fourCC);
        else
            NSLog(@"%@: %d", message, (int)status);

        if(fatal)
            exit(-1);
    }
}

typedef void(^Progress)(UInt32 mDataByteSize);

@interface NAudioUnit : NSObject

@property (nonatomic, copy) Progress progress;

- (instancetype)initWithFilePath:(NSURL *)path;

- (AUGraph )augraph;

- (void)setInputSource:(BOOL)isAcc;

- (double)getCurrentTime;

@end

NS_ASSUME_NONNULL_END
