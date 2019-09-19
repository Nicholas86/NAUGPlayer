//
//  NAUGraphPlayer.m
//  NAUGPlayer
//
//  Created by 泽娄 on 2019/9/18.
//  Copyright © 2019 泽娄. All rights reserved.
//

#import "NAUGraphPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "NAudioSession.h"
#import "NAudioUnit.h"

@implementation NAUGraphPlayer
{
    NSURL *_path;
    NAudioUnit *_audioUnit;
}

- (instancetype)initWithFilePath:(NSString *)path
{
    self = [super init];
    if (self) {
        [self createAudioSession];
        [self createAudioSessionInterruptedNotification];
        _path = [self urlWithString:path];
        [self createAudioUnit];
    }return self;
}

- (void)createAudioSession
{
    [[NAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback]; /// 只支持音频播放
    [[NAudioSession sharedInstance] setPreferredSampleRate:44100];
    [[NAudioSession sharedInstance] setActive:YES];
    [[NAudioSession sharedInstance] addRouteChangeListener];
}

- (void)createAudioUnit
{
    __weak typeof(self) weakSelf = self;
    _audioUnit = [[NAudioUnit alloc] initWithFilePath:_path];
    _audioUnit.progress = ^(UInt32 mDataByteSize) {
        if (mDataByteSize <= 0) {
            [weakSelf stop];
        }
    };
}

- (BOOL)play
{
    OSStatus status = AUGraphStart([_audioUnit augraph]);
    CheckStatus(status, @"Could not start AUGraph", YES);
    return YES;
}

- (void)stop
{
    Boolean isRunning = false;
    OSStatus status = AUGraphIsRunning([_audioUnit augraph], &isRunning);
    if (isRunning)
    {
        status = AUGraphStop([_audioUnit augraph]);
        CheckStatus(status, @"Could not stop AUGraph", YES);
    }
}

- (void)setInputSource:(BOOL)isAcc
{
    [_audioUnit setInputSource:isAcc];
}

- (double)getCurrentTime
{
    return [_audioUnit getCurrentTime];
}

#pragma mark - notification observer
// AudioSession 被打断的通知
- (void)createAudioSessionInterruptedNotification
{
    [self removeAudioSessionInterruptedNotification];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
}

- (void)removeAudioSessionInterruptedNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
}

- (void)onNotificationAudioInterrupted:(NSNotification *)sender
{
    AVAudioSessionInterruptionType interruptionType = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            [self stop];
            break;
        case AVAudioSessionInterruptionTypeEnded:
            [self play];
            break;
        default:
            break;
    }
}

- (NSURL *)urlWithString:(NSString *)path
{
    return [NSURL URLWithString:path];
}

- (void)dealloc
{
    [self removeAudioSessionInterruptedNotification];
}
@end
