//
//  AudioManager.m
//  libpd+audiobus
//
//  Created by Ragnar Hrafnkelsson on 31/10/2013.
//  Copyright (c) 2013 Reactify. All rights reserved.
//
//  Audiobus 2 update by Oliver Greschke (o-g-sus)
//

#import "AudioManager.h"
#import "Audiobus.h"
#import "PdBase.h"
#import "PdAudioUnit.h"
#import "PdAudioController_AB.h"    // Make sure to import extended PdAudioController


// This must be unique, get a temporary registration from http://developer.audiob.us/temporary-registration
// replace with you Key !!
static NSString *const AUDIOBUS_API_KEY= @"MCoqKkVsYXN0aWNEcnVtcyoqKkVsYXN0aWNEcnVtcy5hdWRpb2J1czovLw==:jkXelMuYSaPT3xeQQQEMYCVZgLjPUADYo0EI1P+PBTFfiC2wvtApgKOik2io0nRrlaDOa6FSlpUMQG2k29es2wyOA3GDGCLhMNgSZVQvxz+R1YmJmOnW23mrWto3HH/P";


static NSString *const PD_PATCH = @"_main.pd";


@interface AudioManager () {}

@property (nonatomic, readwrite, getter = isActive) BOOL active;

// Audiobus
@property (strong, nonatomic) ABSenderPort *sender;
@property (strong, nonatomic, readwrite) ABAudiobusController *audiobusController;

@end



@implementation AudioManager


+ (AudioManager *)sharedInstance
{
    static AudioManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AudioManager alloc] init];
    });
    return sharedInstance;
}

static void * kAudiobusRunningOrConnectedChanged = &kAudiobusRunningOrConnectedChanged;

- (id)init
{
    if (self = [super init]) {
        
        [self setupPDAudio];
        
        // Create an Audiobus instance
        self.audiobusController = [[ABAudiobusController alloc] initWithApiKey:AUDIOBUS_API_KEY];
        
        // Create a sender port
        self.sender = [[ABSenderPort alloc] initWithName:@"ElasticDrums"
                                               title:@"ElasticDrums"
                                        audioComponentDescription:(AudioComponentDescription) {
                                            .componentType = kAudioUnitType_RemoteGenerator,
                                            .componentSubType = 'aout',
                                            .componentManufacturer = 'ogsu' }
                                               audioUnit:_pdAudioController.audioUnit.audioUnit];

        [_audiobusController addSenderPort:_sender];
        
        // Watch the connected and audiobusAppRunning properties to be notified when we connect/disconnect or Audiobus opens or closes
        [_audiobusController addObserver:self forKeyPath:@"connected" options:0 context:kAudiobusRunningOrConnectedChanged];
        [_audiobusController addObserver:self forKeyPath:@"audiobusAppRunning" options:0 context:kAudiobusRunningOrConnectedChanged];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
    }
    return self;
}

- (void) setupPDAudio
{
    
    // register for Pd messages
    [PdBase setDelegate: self];
    
    // set up Pd audio session
    _pdAudioController = [[PdAudioController alloc] init];
    [_pdAudioController configurePlaybackWithSampleRate:44100 numberChannels:2 inputEnabled:NO mixingEnabled:YES];
    
    // 4, 8, 16 ?  ... Audiobus wants your app to perform well at 256 frames
    // Pd block size * ticks per buffer = buffer size (64 * 4 = 256)
    //[_pdAudioController configureTicksPerBuffer: 4];
    // I am not sure about this, so I just let it automatically be done by iOS

    [PdBase openFile:PD_PATCH path:[[NSBundle mainBundle] bundlePath]];
    
    // Turn DSP on
    [self setActive: YES];
}

-(void)dealloc {
    [_audiobusController removeObserver:self forKeyPath:@"connected"];
    [_audiobusController removeObserver:self forKeyPath:@"audiobusAppRunning"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context {
    
    if ( context == kAudiobusRunningOrConnectedChanged ){
        if ( [UIApplication sharedApplication].applicationState == UIApplicationStateBackground
            && !_audiobusController.connected
            && !_audiobusController.audiobusAppRunning
            && [self isActive] ) {
            // Audiobus has quit. Time to sleep.
            [self setActive:NO];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)applicationDidEnterBackground:(NSNotification *)notification {

    if ( !_audiobusController.connected && !_audiobusController.audiobusAppRunning && [self isActive] ) {
        // Stop the audio engine, suspending the app, if Audiobus isn't running
        [self setActive: NO];
    }
}
-(void)applicationWillEnterForeground:(NSNotification *)notification {

    if ( ![self isActive]) {
        // Start the audio system if it wasn't running
        [self setActive: YES];
    }
}


#pragma mark - Helper functions
- (BOOL)isActive
{
    return _pdAudioController.isActive;
}

- (void)setActive:(BOOL)active {
    
    [_pdAudioController setActive: active];
}

- (BOOL)audiobusConnected
{
    return [_audiobusController connected];
}

@end
