//
//  ViewController.m
//  NAUGPlayer
//
//  Created by 泽娄 on 2019/9/18.
//  Copyright © 2019 泽娄. All rights reserved.
//

#import "ViewController.h"
#import "utils/CommonUtil.h"
#import "NAUGraphPlayer.h"

@interface ViewController (){
    NAUGraphPlayer  *player;
}
@property(nonatomic, assign) BOOL   isAcc;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _isAcc = NO;
}

- (IBAction)start:(UIButton *)sender {
    
    NSLog(@"Play Music...");
    if(player) {
        [player stop];
    }
    
//    NSString *filePath = [CommonUtil bundlePath:@"MiAmor.mp3"];
    NSString *filePath = [CommonUtil bundlePath:@"MP3Sample.mp3"];
    
    //     NSString* filePath = [CommonUtil bundlePath:@"0fe2a7e9c51012210eaaa1e2b103b1b1.m4a"];
    
//    NSString* filePath = [CommonUtil bundlePath:@"CAFSample.caf"];

//    NSString* filePath = [CommonUtil bundlePath:@"M4ASample.m4a"];

    player = [[NAUGraphPlayer alloc] initWithFilePath:filePath];
    [player play];
}

- (IBAction)stop:(UIButton *)sender {
    NSLog(@"Stop Music...");
    [player stop];
}


@end
