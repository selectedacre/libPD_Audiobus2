//
//  AudioManager.h
//  libpd+audiobus
//
//  Created by Ragnar Hrafnkelsson on 31/10/2013.
//  Copyright (c) 2013 Reactify. All rights reserved.
//
//  Audiobus 2 update by Oliver Greschke (o-g-sus)
//

#import <Foundation/Foundation.h>

#import "PdBase.h"

@class PdAudioController;

@interface AudioManager : NSObject <PdReceiverDelegate>

+ (AudioManager *)sharedInstance;

// for extern communication
@property (strong, nonatomic) PdAudioController *pdAudioController;


@end
