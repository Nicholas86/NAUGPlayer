//
//  NAudioUnit.m
//  NAudioUnit
//
//  Created by 泽娄 on 2019/9/18.
//  Copyright © 2019 泽娄. All rights reserved.
//

#import "NAudioUnit.h"

#define OUTPUT_BUS (0)

#define kInputBus 1
#define kOutputBus 0

const uint32_t CONST_BUFFER_SIZE = 0x10000;

@implementation NAudioUnit
{
    AUGraph                                     mPlayerGraph;
    AUNode                                      mPlayerNode;
    AudioUnit                                   mPlayerUnit;
    
    AUNode                                      mSplitterNode;
    AudioUnit                                   mSplitterUnit;
    
    AUNode                                      mAccMixerNode;
    AudioUnit                                   mAccMixerUnit;
    
    AUNode                                      mVocalMixerNode;
    AudioUnit                                   mVocalMixerUnit;
    
    AUNode                                      mPlayerIONode;
    AudioUnit                                   mPlayerIOUnit;
    NSURL *_playPath;
    
    /// 另外一种方式
    AudioUnit audioUnit;
    AudioStreamBasicDescription audioFileFormat;
    AudioStreamBasicDescription outputFormat;
    ExtAudioFileRef exAudioFile;
    
    SInt64 readedSize; // 已读的frame数量
    UInt64 totalSize; // 总的Frame数量

    AudioBufferList *buffList;
    
    AudioConverterRef audioConverter;
}

- (instancetype)initWithFilePath:(NSURL *)path
{
    self = [super init];
    if (self) {
        _playPath = path;
        [self readeFile]; // 一定先readFile
        // [self initializePlayGraph];
    }return self;
}

- (void)createAudioUnit
{
    /*
    OSStatus status = noErr;
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    NSAssert(!status, @"AudioComponentInstanceNew error");
    */
    
    
    //1:构造AUGraph
    OSStatus status = noErr;
    status = NewAUGraph(&mPlayerGraph);
    CheckStatus(status, @"Could not create a new AUGraph", YES);
    
    //2-1:添加IONode
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    status = AUGraphAddNode(mPlayerGraph, &ioDescription, &mPlayerIONode);
    CheckStatus(status, @"Could not add I/O node to AUGraph", YES);
    
//    //2-2:添加PlayerNode
//    AudioComponentDescription playerDescription;
//    bzero(&playerDescription, sizeof(playerDescription));
//    playerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
//    playerDescription.componentType = kAudioUnitType_Generator;
//    playerDescription.componentSubType = kAudioUnitSubType_AudioFilePlayer;
//    status = AUGraphAddNode(mPlayerGraph, &playerDescription, &mPlayerNode);
    
    //3:打开Graph, 只有真正的打开了Graph才会实例化每一个Node
    status = AUGraphOpen(mPlayerGraph);
    CheckStatus(status, @"Could not open AUGraph", YES);
    
    //4-1:获取出IONode的AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mPlayerIONode, NULL, &mPlayerIOUnit);
    CheckStatus(status, @"Could not retrieve node info for I/O node", YES);
    
//    //4-2:获取出PlayerNode的AudioUnit
//    status = AUGraphNodeInfo(mPlayerGraph, mPlayerNode, NULL, &mPlayerUnit);
//    CheckStatus(status, @"Could not retrieve node info for Player node", YES);
   
    //initAudioProperty
    UInt32 flag = 1;
    if (flag) {
        status = AudioUnitSetProperty(mPlayerIOUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
        NSAssert1(!status, @"AudioUnitSetProperty eror with status:%d", status);
    }
    
    
    status = AudioUnitSetProperty(mPlayerIOUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    NSAssert1(!status, @"AudioUnitSetProperty eror with status:%d", status);
    
    /// 回调方式
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AUGraphSetNodeInputCallback(mPlayerGraph, mPlayerIONode, 0, &playCallback);
    NSAssert(!status, @"AudioUnitSetProperty error");
    //7:初始化Graph
    status = AUGraphInitialize(mPlayerGraph);
    CheckStatus(status, @"Couldn't Initialize the graph", YES);
    //8:显示Graph结构
    CAShow(mPlayerGraph);
    
    /*
    //initAudioProperty
    UInt32 flag = 1;
    if (flag) {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
        NSAssert1(!status, @"AudioUnitSetProperty eror with status:%d", status);
    }
    
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    NSAssert1(!status, @"AudioUnitSetProperty eror with status:%d", status);
    
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &playCallback,
                                  sizeof(playCallback));
    NSAssert(!status, @"AudioUnitSetProperty error");
    
    status = AudioUnitInitialize(audioUnit);
    NSAssert(!status, @"AudioUnitInitialize error");
     */
}

OSStatus PlayCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData) {
    NAudioUnit *audioUnit = (__bridge NAudioUnit *)inRefCon;
    
    audioUnit->buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    OSStatus status = ExtAudioFileRead(audioUnit->exAudioFile, &inNumberFrames, audioUnit->buffList);

    if (status) NSLog(@"转换格式失败");
    if (!inNumberFrames) NSLog(@"播放结束");

    NSLog(@"total size: %llu,out size: %d", audioUnit->totalSize, audioUnit->buffList->mBuffers[0].mDataByteSize);
    memcpy(ioData->mBuffers[0].mData, audioUnit->buffList->mBuffers[0].mData, audioUnit->buffList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = audioUnit->buffList->mBuffers[0].mDataByteSize;

    audioUnit->readedSize += audioUnit->buffList->mBuffers[0].mDataByteSize / audioUnit->outputFormat.mBytesPerFrame; //Bytes per Frame = 2，所以是每2bytes一帧

    fwrite(audioUnit->buffList->mBuffers[0].mData, audioUnit->buffList->mBuffers[0].mDataByteSize, 1, [audioUnit pcmFile]);

    /// 回调进度
    UInt32 byteSize = audioUnit->buffList->mBuffers[0].mDataByteSize;
    audioUnit.progress(byteSize);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (byteSize <= 0) {
            audioUnit->totalSize = 0;
            audioUnit->readedSize = 0;
        }
    });

    return noErr;
}

- (void)readeFile
{
    // BUFFER
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    buffList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    
    // Extend Audio File
    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)_playPath, &exAudioFile);
    CheckStatus(status, @"Could not Extend Audio File", YES);
    NSAssert(!status, @"打开文件失败");
    
    uint32_t size = sizeof(AudioStreamBasicDescription);
    status = ExtAudioFileGetProperty(exAudioFile, kExtAudioFileProperty_FileDataFormat, &size, &audioFileFormat); // 读取文件格式
    NSAssert1(status == noErr, @"ExtAudioFileGetProperty error status %d", status);
    
    //initFormat
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = 44100;
    outputFormat.mFormatID         = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
    outputFormat.mBytesPerPacket   = 2;
    outputFormat.mFramesPerPacket  = 1;
    outputFormat.mBytesPerFrame    = 2;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBitsPerChannel   = 16;
    
    NSLog(@"input format:");
    [self printAudioStreamBasicDescription:audioFileFormat];
    NSLog(@"output format:");
    [self printAudioStreamBasicDescription:outputFormat];
    
    status = ExtAudioFileSetProperty(exAudioFile, kExtAudioFileProperty_ClientDataFormat, size, &outputFormat);
    NSAssert1(!status, @"ExtAudioFileSetProperty eror with status:%d", status);
    
    // 初始化不能太前，如果未设置好输入输出格式，获取的总frame数不准确
    size = sizeof(totalSize);
    status = ExtAudioFileGetProperty(exAudioFile,
                                     kExtAudioFileProperty_FileLengthFrames,
                                     &size,
                                     &totalSize);
    
    readedSize = 0;
    NSAssert(!status, @"ExtAudioFileGetProperty error");
    
    [self createAudioUnit];
}

- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDes
{
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(audioStreamBasicDes.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  audioStreamBasicDes.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)audioStreamBasicDes.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)audioStreamBasicDes.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)audioStreamBasicDes.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)audioStreamBasicDes.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)audioStreamBasicDes.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)audioStreamBasicDes.mBitsPerChannel);
    printf("\n");
}

- (FILE *)pcmFile
{
    static FILE *_pcmFile;
    if (!_pcmFile) {
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.pcm"];
        _pcmFile = fopen(filePath.UTF8String, "w");
        
    }
    return _pcmFile;
}

- (double)getCurrentTime
{
    Float64 timeInterval = (readedSize * 1.0) / totalSize;
    return timeInterval;
}

/*
 -(void)setupAudioUnitRenderWithAudioDesc:(AudioStreamBasicDescription)audioDesc{
 
 //componentDesc是筛选条件 component是组件的抽象，对应class的角色，componentInstance是具体的组件实体，对应object角色。
 AudioComponentDescription componentDesc;
 componentDesc.componentType = kAudioUnitType_Output;
 componentDesc.componentSubType = kAudioUnitSubType_RemoteIO;
 componentDesc.componentFlags = 0;
 componentDesc.componentFlagsMask = 0;
 componentDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
 
 AudioComponent component = AudioComponentFindNext(NULL, &componentDesc);
 OSStatus status = AudioComponentInstanceNew(component, &audioUnit);
 
 TFCheckStatusUnReturn(status, @"instance new audio component");
 
 //open render output
 UInt32 falg = 1;
 status = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, renderAudioElement, &falg, sizeof(UInt32));
 
 TFCheckStatusUnReturn(status, @"enable IO");
 
 //set render input format
 status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, renderAudioElement, &audioDesc, sizeof(audioDesc));
 
 TFCheckStatusUnReturn(status, @"set render input format");
 
 //set render callback to process audio buffers
 AURenderCallbackStruct callbackSt;
 callbackSt.inputProcRefCon = (__bridge void * _Nullable)(self);
 callbackSt.inputProc = playAudioBufferCallback;
 status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Group, renderAudioElement, &callbackSt, sizeof(callbackSt));
 
 TFCheckStatusUnReturn(status, @"set render callback");
 
 NSError *error = nil;
 [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
 if (error) {
 NSLog(@"audio session set category: %@",error);
 return;
 }
 [[AVAudioSession sharedInstance] setActive:YES error:&error];
 if (error) {
 NSLog(@"active audio session: %@",error);
 return;
 }
 
 status = AudioOutputUnitStart(audioUnit);
 
 if (status != 0) {
 [self stop];
 }
 
 NSLog(@"audio play started!");
 _playing = YES;
 }
 
 */

#pragma mark - callback
/*
OSStatus playAudioBufferCallback(    void *                            inRefCon,
                                 AudioUnitRenderActionFlags *    ioActionFlags,
                                 const AudioTimeStamp *            inTimeStamp,
                                 UInt32                            inBusNumber,
                                 UInt32                            inNumberFrames,
                                 AudioBufferList * __nullable    ioData){
    
    TFAudioUnitPlayer *player = (__bridge TFAudioUnitPlayer *)(inRefCon);
    
    UInt32 framesPerPacket = inNumberFrames;
    OSStatus status = [player readFrames:&framesPerPacket toBufferList:ioData];
    
    return status;
}
 */



- (void)initializePlayGraph
{
    /// 描述信息
//    AudioComponentDescription ioUnitDescription;
//    ioUnitDescription.componentType = kAudioUnitType_Output;
//    ioUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
//    ioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
//    ioUnitDescription.componentFlags = 0;
//    ioUnitDescription.componentFlagsMask = 0;
    
    /*
    /// 1.裸创建方式
    AudioComponent ioUnitRef = AudioComponentFindNext(NULL,&ioUnitDescription);
    AudioUnit ioUnitInstance;
    AudioConponentInstanceNew(ioUnitRef,&ioUnitInstance);
    */
    
    /// 2.AUGraph创建方法
    OSStatus status = noErr;
    //1:构造AUGraph
    status = NewAUGraph(&mPlayerGraph);
    CheckStatus(status, @"Could not create a new AUGraph", YES);
    //2-1:添加IONode
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentType = kAudioUnitType_Output;
    ioDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    status = AUGraphAddNode(mPlayerGraph, &ioDescription, &mPlayerIONode);
    CheckStatus(status, @"Could not add I/O node to AUGraph", YES);
    //2-2:添加PlayerNode
    AudioComponentDescription playerDescription;
    bzero(&playerDescription, sizeof(playerDescription));
    playerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    playerDescription.componentType = kAudioUnitType_Generator;
    playerDescription.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    status = AUGraphAddNode(mPlayerGraph, &playerDescription, &mPlayerNode);
    CheckStatus(status, @"Could not add Player node to AUGraph", YES);
    //2-3:添加Splitter
    AudioComponentDescription splitterDescription;
    bzero(&splitterDescription, sizeof(splitterDescription));
    splitterDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    splitterDescription.componentType = kAudioUnitType_FormatConverter;
    splitterDescription.componentSubType = kAudioUnitSubType_Splitter;
    status = AUGraphAddNode(mPlayerGraph, &splitterDescription, &mSplitterNode);
    CheckStatus(status, @"Could not add Splitter node to AUGraph", YES);
    //2-4:添加两个Mixer
    AudioComponentDescription mixerDescription;
    bzero(&mixerDescription, sizeof(mixerDescription));
    mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerDescription.componentType = kAudioUnitType_Mixer;
    mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    status = AUGraphAddNode(mPlayerGraph, &mixerDescription, &mVocalMixerNode);
    CheckStatus(status, @"Could not add VocalMixer node to AUGraph", YES);
    status = AUGraphAddNode(mPlayerGraph, &mixerDescription, &mAccMixerNode);
    CheckStatus(status, @"Could not add AccMixer node to AUGraph", YES);
    
    //3:打开Graph, 只有真正的打开了Graph才会实例化每一个Node
    status = AUGraphOpen(mPlayerGraph);
    CheckStatus(status, @"Could not open AUGraph", YES);

    //4-1:获取出IONode的AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mPlayerIONode, NULL, &mPlayerIOUnit);
    CheckStatus(status, @"Could not retrieve node info for I/O node", YES);

    //4-2:获取出PlayerNode的AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mPlayerNode, NULL, &mPlayerUnit);
    CheckStatus(status, @"Could not retrieve node info for Player node", YES);
    
    //4-3:获取出mSplitterNode的AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mSplitterNode, NULL, &mSplitterUnit);
    CheckStatus(status, @"Could not retrieve node info for Splitter node", YES);
    
    //4-4:获取出VocalMixer的AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mVocalMixerNode, NULL, &mVocalMixerUnit);
    CheckStatus(status, @"Could not retrieve node info for VocalMixer node", YES);
    
    //4-5:获取出AccMixer的AudioUnit
    status = AUGraphNodeInfo(mPlayerGraph, mAccMixerNode, NULL, &mAccMixerUnit);
    CheckStatus(status, @"Could not retrieve node info for AccMixer node", YES);
    
    //5:给AudioUnit设置参数
    AudioStreamBasicDescription stereoStreamFormat;
    UInt32 bytesPerSample = sizeof(Float32);
    bzero(&stereoStreamFormat, sizeof(stereoStreamFormat));
    stereoStreamFormat.mFormatID          = kAudioFormatLinearPCM;
    stereoStreamFormat.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    stereoStreamFormat.mBytesPerPacket    = bytesPerSample;
    stereoStreamFormat.mFramesPerPacket   = 1;
    stereoStreamFormat.mBytesPerFrame     = bytesPerSample;
    stereoStreamFormat.mChannelsPerFrame  = 2;                    // 2 indicates stereo
    stereoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
    stereoStreamFormat.mSampleRate        = 48000.0;
    
    status = AudioUnitSetProperty(mPlayerIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &stereoStreamFormat, sizeof(stereoStreamFormat));
    CheckStatus(status, @"set remote IO output element stream format ", YES);
    
    status = AudioUnitSetProperty(
                                  mPlayerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &stereoStreamFormat,
                                  sizeof (stereoStreamFormat)
                                  );
    CheckStatus(status, @"Could not Set StreamFormat for Player Unit", YES);
    
    //5-2配置Splitter的属性
    status = AudioUnitSetProperty(mSplitterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,
                                  0, &stereoStreamFormat, sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for Splitter Unit", YES);
    status = AudioUnitSetProperty(mSplitterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                  0, &stereoStreamFormat, sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for Splitter Unit", YES);
    //5-3 配置VocalMixerUnit的属性
    status = AudioUnitSetProperty(mVocalMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,
                                  0, &stereoStreamFormat, sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for VocalMixer Unit", YES);
    status = AudioUnitSetProperty(mVocalMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                  0, &stereoStreamFormat, sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for VocalMixer Unit", YES);
    int mixerElementCount = 1;
    status = AudioUnitSetProperty(mVocalMixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0,
                                  &mixerElementCount, sizeof(mixerElementCount));
    //5-4 配置AccMixerUnit的属性
    status = AudioUnitSetProperty(mAccMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,
                                  0, &stereoStreamFormat, sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for AccMixer Unit", YES);
    status = AudioUnitSetProperty(mAccMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                  0, &stereoStreamFormat, sizeof(stereoStreamFormat));
    CheckStatus(status, @"Could not Set StreamFormat for AccMixer Unit", YES);
    mixerElementCount = 2;
    status = AudioUnitSetProperty(mAccMixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0,
                                  &mixerElementCount, sizeof(mixerElementCount));
    
    [self setInputSource:NO];
    
    //6:连接起Node来
    AUGraphConnectNodeInput(mPlayerGraph, mPlayerNode, 0, mSplitterNode, 0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    AUGraphConnectNodeInput(mPlayerGraph, mSplitterNode, 0, mVocalMixerNode, 0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    AUGraphConnectNodeInput(mPlayerGraph, mSplitterNode, 1, mAccMixerNode, 0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    AUGraphConnectNodeInput(mPlayerGraph, mVocalMixerNode, 0, mAccMixerNode, 1);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    AUGraphConnectNodeInput(mPlayerGraph, mAccMixerNode, 0, mPlayerIONode, 0);
    CheckStatus(status, @"Player Node Connect To IONode", YES);
    //7:初始化Graph
    status = AUGraphInitialize(mPlayerGraph);
    CheckStatus(status, @"Couldn't Initialize the graph", YES);
    //8:显示Graph结构
    CAShow(mPlayerGraph);
    //9:只有对Graph进行Initialize之后才可以设置AudioPlayer的参数
    [self setUpFilePlayer];
}

- (void)setInputSource:(BOOL) isAcc
{
    OSStatus status;
    AudioUnitParameterValue value;
    status = AudioUnitGetParameter(mVocalMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, &value);
    CheckStatus(status, @"get parameter fail", YES);
    NSLog(@"Vocal Mixer %lf", value);
    status = AudioUnitGetParameter(mAccMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, &value);
    CheckStatus(status, @"get parameter fail", YES);
    NSLog(@"Acc Mixer 0 %lf", value);
    status = AudioUnitGetParameter(mAccMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 1, &value);
    CheckStatus(status, @"get parameter fail", YES);
    NSLog(@"Acc Mixer 1 %lf", value);
    
    //    status = AudioUnitSetParameter(mVocalMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0);
    //    CheckStatus(status, @"set parameter fail", YES);
    if(isAcc) {
        status = AudioUnitSetParameter(mAccMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 0.1, 0);
        CheckStatus(status, @"set parameter fail", YES);
        status = AudioUnitSetParameter(mAccMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 1, 1, 0);
        CheckStatus(status, @"set parameter fail", YES);
    } else {
        status = AudioUnitSetParameter(mAccMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1, 0);
        CheckStatus(status, @"set parameter fail", YES);
        status = AudioUnitSetParameter(mAccMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 1, 0.1, 0);
        CheckStatus(status, @"set parameter fail", YES);
    }
}

/// 文件读写
- (void)setUpFilePlayer
{
    OSStatus status = noErr;
    AudioFileID musicFile;
    CFURLRef songURL = (__bridge  CFURLRef) _playPath;
    // open the input audio file
    status = AudioFileOpenURL(songURL, kAudioFileReadPermission, 0, &musicFile);
    CheckStatus(status, @"Open AudioFile... ", YES);
    
    
    // tell the file player unit to load the file we want to play
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduledFileIDs,
                                  kAudioUnitScope_Global, 0, &musicFile, sizeof(musicFile));
    CheckStatus(status, @"Tell AudioFile Player Unit Load Which File... ", YES);
    
    
    
    AudioStreamBasicDescription fileASBD;
    // get the audio data format from the file
    UInt32 propSize = sizeof(fileASBD);
    status = AudioFileGetProperty(musicFile, kAudioFilePropertyDataFormat,
                                  &propSize, &fileASBD);
    CheckStatus(status, @"get the audio data format from the file... ", YES);
    UInt64 nPackets;
    UInt32 propsize = sizeof(nPackets);
    AudioFileGetProperty(musicFile, kAudioFilePropertyAudioDataPacketCount,
                         &propsize, &nPackets);
    // tell the file player AU to play the entire file
    ScheduledAudioFileRegion rgn;
    memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    rgn.mCompletionProc = NULL;
    rgn.mCompletionProcUserData = NULL;
    rgn.mAudioFile = musicFile;
    rgn.mLoopCount = 0;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = (UInt32)nPackets * fileASBD.mFramesPerPacket;
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduledFileRegion,
                                  kAudioUnitScope_Global, 0,&rgn, sizeof(rgn));
    CheckStatus(status, @"Set Region... ", YES);
    
    
    // prime the file player AU with default values
    UInt32 defaultVal = 0;
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduledFilePrime,
                                  kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal));
    CheckStatus(status, @"Prime Player Unit With Default Value... ", YES);
    
    
    // tell the file player AU when to start playing (-1 sample time means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp,
                                  kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
    CheckStatus(status, @"set Player Unit Start Time... ", YES);
}

- (AUGraph )augraph
{
    return mPlayerGraph;
}

- (void)dealloc
{
    AudioOutputUnitStop(mPlayerIOUnit);
    AudioUnitUninitialize(mPlayerIOUnit);
    AudioComponentInstanceDispose(mPlayerIOUnit);
}

@end
