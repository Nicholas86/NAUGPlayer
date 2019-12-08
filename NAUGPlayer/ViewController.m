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
@property (nonatomic , strong) CADisplayLink *mDispalyLink;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _isAcc = NO;
    self.mDispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    self.mDispalyLink.frameInterval = 5;
    [self.mDispalyLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (IBAction)start:(UIButton *)sender {
    
    NSLog(@"Play Music...");
    if(player) {
        [player stop];
    }
    
    NSString *filePath = [CommonUtil bundlePath:@"MiAmor.mp3"];
//    NSString *filePath = [CommonUtil bundlePath:@"MP3Sample.mp3"];
    
//    NSString* filePath = [CommonUtil bundlePath:@"0fe2a7e9c51012210eaaa1e2b103b1b1.m4a"];
    
//    NSString* filePath = [CommonUtil bundlePath:@"CAFSample.caf"];

//    NSString* filePath = [CommonUtil bundlePath:@"M4ASample.m4a"];

    player = [[NAUGraphPlayer alloc] initWithFilePath:filePath];
    [player play];
}

- (IBAction)stop:(UIButton *)sender
{
    NSLog(@"Stop Music...");
    [player stop];
}

- (void)updateFrame
{
    if (player) {
        self.currentTimeLabel.text = [NSString stringWithFormat:@"当前进度:%3d%%", (int)([player getCurrentTime] * 100)];
    }
}

@end
