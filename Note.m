//
//  Note.m
//  Music Editor
//
//  Created by Konstantine Prevas on 5/7/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Note.h"
#import "KeySignature.h"
@class NoteDraw;

@implementation Note

- (id)initWithPitch:(int)_pitch octave:(int)_octave 
	duration:(int)_duration dotted:(BOOL)_dotted accidental:(int)_accidental{
	if(self = [super init]){
		pitch = _pitch;
		octave = _octave;
		duration = _duration;
		dotted = _dotted;
		accidental = _accidental;
	}
	return self;
}

- (int)getDuration{
	return duration;
}
- (BOOL)getDotted{
	return dotted;
}
- (int)getPitch{
	return pitch;
}
- (int)getOctave{
	return octave;
}
- (int)getAccidental{
	return accidental;
}

- (void)setDuration:(int)_duration{
	duration = _duration;
}
- (void)setDotted:(BOOL)_dotted{
	dotted = _dotted;
}
- (void)setOctave:(int)_octave{
	octave = _octave;
}
- (void)setPitch:(int)_pitch{
	pitch = _pitch;
}
- (void)setAccidental:(int)_accidental{
	accidental = _accidental;
}

- (id)copyWithZone:(NSZone *)zone{
	return [[Note allocWithZone:zone] initWithPitch:pitch
		octave:octave duration:duration dotted:dotted
		accidental:accidental];
}

- (BOOL)isEqualTo:(id)obj{
	return [obj isKindOfClass:[Note class]] &&
		[obj getPitch] == pitch && [obj getOctave] == octave &&
		[obj getDuration] == duration && [obj getDotted] == dotted &&
		[obj getAccidental] == accidental;
}

- (float)addToMIDITrack:(MusicTrack *)musicTrack atPosition:(float)pos withKeySignature:(KeySignature *)keySig 
			accidentals:(NSMutableDictionary *)accidentals onChannel:(int)channel{
	if(tieFrom != nil) return 4.0 * [self getEffectiveDuration];
	MIDINoteMessage note;
	note.channel = channel;
	note.velocity = 100.00;
	note.duration = 4.0 * [self getEffectiveDuration];
	Note *tie = tieTo;
	while(tie != nil){
		note.duration += 4.0 * [tie getEffectiveDuration];
		tie = [tie getTieTo];
	}
	note.note = octave * 12 + [keySig getPitchAtPosition:pitch];
	int effAccidental = accidental;
	if(effAccidental == NO_ACC){
		NSNumber *effAccGet = [accidentals objectForKey:[[[NSNumber alloc] initWithInt:(octave * 7 + pitch)] autorelease]];
		if(effAccGet != nil){
			effAccidental = [effAccGet intValue];
		}
	} else{
		[accidentals setObject:[[[NSNumber alloc] initWithInt:accidental] autorelease] forKey:[[[NSNumber alloc] initWithInt:(octave * 7 + pitch)] autorelease]];
	}
	if(effAccidental != NO_ACC){
		int keySigAcc = [keySig getAccidentalAtPosition:pitch];
		if(keySigAcc != NO_ACC){
			effAccidental -= keySigAcc;
		}
		note.note += effAccidental;
	}
	if (MusicTrackNewMIDINoteEvent(*musicTrack, pos, &note) != noErr) {
		NSLog(@"Cannot add note to track.");
    }
	return 4.0 * [self getEffectiveDuration];
}

- (void)tieTo:(Note *)note{
	if(![tieTo isEqual:note]){
		[tieTo release];
		tieTo = [note retain];
	}
}

- (Note *)getTieTo{
	return tieTo;
}

- (void)tieFrom:(Note *)note{
	if(![tieFrom isEqual:note]){
		[tieFrom release];
		tieFrom = [note retain];
	}
}

- (Note *)getTieFrom{
	return tieFrom;
}

- (void)transposeBy:(int)transposeAmount{
	pitch += transposeAmount;
	while(pitch >= 7){
		pitch -= 7;
		octave++;
	}
	while(pitch < 0){
		pitch += 7;
		octave--;
	}
}

- (void)collapseOnTo:(Note *)note{
	float effDuration = [self getEffectiveDuration];
	float targetDuration = [note getEffectiveDuration];
	float totalDuration = effDuration + targetDuration;
	//TODO: implement
}

- (void)encodeWithCoder:(NSCoder *)coder{
	[coder encodeInt:duration forKey:@"duration"];
	[coder encodeBool:dotted forKey:@"dotted"];
	[coder encodeInt:octave forKey:@"octave"];
	[coder encodeInt:pitch forKey:@"pitch"];
	[coder encodeInt:accidental forKey:@"accidental"];
	[coder encodeObject:tieTo forKey:@"tieTo"];
	[coder encodeObject:tieFrom forKey:@"tieFrom"];
}

- (id)initWithCoder:(NSCoder *)coder{
	if(self = [super init]){
		duration = [coder decodeIntForKey:@"duration"];
		dotted = [coder decodeBoolForKey:@"dotted"];
		octave = [coder decodeIntForKey:@"octave"];
		pitch = [coder decodeIntForKey:@"pitch"];
		accidental = [coder decodeIntForKey:@"accidental"];
		[self tieTo:[coder decodeObjectForKey:@"tieTo"]];
		[self tieFrom:[coder decodeObjectForKey:@"tieFrom"]];
	}
	return self;
}

- (void)dealloc{
	tieTo = nil;
	tieFrom = nil;
	[super dealloc];
}

- (Class)getViewClass{
	return [NoteDraw class];
}

@end
