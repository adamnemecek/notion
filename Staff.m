//
//  Staff.m
//  Music Editor
//
//  Created by Konstantine Prevas on 5/7/06.
//  Copyright 2006 Konstantine Prevas. All rights reserved.
//

#import "Staff.h"
#import "Measure.h"
#import "Clef.h"
#import "DrumKit.h"
#import "Song.h"
#import "KeySignature.h"
#import "ChromaticKeySignature.h"
#import "TimeSignature.h"
@class StaffDraw;
@class DrumStaffDraw;
@class StaffController;

@implementation Staff

- (id)initWithSong:(Song *)_song{
	if((self = [super init])){
		Measure *firstMeasure = [[Measure alloc] initWithStaff:self];
		[firstMeasure setClef:[Clef trebleClef]];
		[firstMeasure setKeySignature:[KeySignature getSignatureWithFlats:0 minor:NO]];
		measures = [[NSMutableArray arrayWithObject:firstMeasure] retain];
		song = _song;
	}
	return self;
}

- (NSUndoManager *)undoManager{
	return [[song document] undoManager];
}

- (void)sendChangeNotification{
	[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"modelChanged" object:self]];
}

- (void)setSong:(Song *)_song{
	song = _song;
}

- (Song *)getSong{
	return song;
}

- (NSMutableArray *)getMeasures{
	return measures;
}

- (void)setMeasures:(NSMutableArray *)_measures{
	if(![measures isEqual:_measures]){
		[measures release];
		measures = [_measures retain];
	}
}

- (StaffVerticalRulerComponent *)rulerView{
	return rulerView;
}

- (BOOL)isDrums{
	return channel == 9;
}

- (IBAction)setChannel:(id)sender{
	channel = [channelButton selectedTag] - 1;
	[self sendChangeNotification];
}

- (IBAction)deleteSelf:(id)sender{
	[rulerView removeFromSuperview];
	[song removeStaff:self];
}

- (DrumKit *)getDrumKitForMeasure:(Measure *)measure{
	int index = [measures indexOfObject:measure];
	while([measure getDrumKit] == nil){
		if(index == 0) return [DrumKit standardKit];
		index--;
		measure = [measures objectAtIndex:index];
	}
	return [measure getDrumKit];
}

- (Clef *)getClefForMeasure:(Measure *)measure{
	int index = [measures indexOfObject:measure];
	if([self isDrums]){
		return [self getDrumKitForMeasure:measure];
	} else {
		while([measure getClef] == nil){
			if(index == 0) return [Clef trebleClef];
			index--;
			measure = [measures objectAtIndex:index];
		}
		return [measure getClef];		
	}
}

- (KeySignature *)getKeySignatureForMeasure:(Measure *)measure{
	if([self isDrums]){
		return [ChromaticKeySignature instance];
	}
	int index = [measures indexOfObject:measure];
	while([measure getKeySignature] == nil){
		if(index == 0) return [KeySignature getSignatureWithSharps:0 minor:NO];
		index--;
		measure = [measures objectAtIndex:index];
	}
	return [measure getKeySignature];
}

- (TimeSignature *)getTimeSignatureForMeasure:(Measure *)measure{
	return [song getTimeSignatureAt:[measures indexOfObject:measure]];
}

- (TimeSignature *)getEffectiveTimeSignatureForMeasure:(Measure *)measure{
	int index = [measures indexOfObject:measure];
	return [song getEffectiveTimeSignatureAt:index];
}

- (Measure *)getLastMeasure{
	return [measures lastObject];
}

- (Measure *)getMeasureBefore:(Measure *)measure{
	int index = [measures indexOfObject:measure];
	if(index > 0){
		return [measures objectAtIndex:(index - 1)];
	} else{
		return nil;
	}
}

- (Measure *)addMeasure{
	Measure *measure = [[Measure alloc] initWithStaff:self];
	[self addMeasure:measure];
	return measure;
}

- (void)addMeasure:(Measure *)measure{
	if(![measures containsObject:measure]){
		[[[self undoManager] prepareWithInvocationTarget:self] removeMeasure:measure];
		[measures addObject:measure];
		[song refreshTimeSigs];
		[song refreshTempoData];
	}
}

- (void)removeMeasure:(Measure *)measure{
	if([measures containsObject:measure]){
		[[[self undoManager] prepareWithInvocationTarget:self] addMeasure:measure];
		[measures removeObject:measure];		
		[song refreshTimeSigs];
		[song refreshTempoData];
	}
}

- (Measure *)getMeasureAfter:(Measure *)measure{
	int index = [measures indexOfObject:measure];
	if(index + 1 < [measures count]){
		return [measures objectAtIndex:(index + 1)];
	} else{
		return [self addMeasure];
	}
}

- (Measure *)getMeasureContainingNote:(NoteBase *)note{
	NSEnumerator *measuresEnum = [measures objectEnumerator];
	id measure;
	while(measure = [measuresEnum nextObject]){
		int i;
		for(i=0; i<[[measure getNotes] count]; i++){
			NoteBase *currNote = [[measure getNotes] objectAtIndex:i];
			if(currNote == note || ([currNote isKindOfClass:[Chord class]] && [[currNote getNotes] containsObject:note])){
				return measure;
			}
		}
	}
	return nil;
}

- (Chord *)getChordContainingNote:(NoteBase *)noteToFind{
	NSEnumerator *measuresEnum = [measures objectEnumerator];
	id measure;
	while(measure = [measuresEnum nextObject]){
		NSEnumerator *notes = [[measure getNotes] objectEnumerator];
		id note;
		while(note = [notes nextObject]){
			if([note isKindOfClass:[Chord class]] &&
			   [[note getNotes] containsObject:noteToFind]){
				return note;
			}			
		}
	}
	return nil;
}

- (void)cleanEmptyMeasures{
	while([measures count] > 1 && [[measures lastObject] isEmpty]){
		Measure *measure = [measures lastObject];
		[measure keySigClose:nil];
		[self removeMeasure:measure];
	}
	[song refreshTimeSigs];
	[song refreshTempoData];
}

- (Note *)findPreviousNoteMatching:(Note *)source inMeasure:(Measure *)measure{
	if([measure getFirstNote] == source){
		Measure *prevMeasure = [[measure getStaff] getMeasureBefore:measure];
		if(prevMeasure != nil){
			NoteBase *note = [[prevMeasure getNotes] lastObject];
			if([note pitchMatches:source]){
				return note;
			}
		}
		return nil;
	} else{
		NoteBase *note = [measure getNoteBefore:source];
		if([note pitchMatches:source]){
			return note;
		}
		return nil;
	}
}

- (NoteBase *)noteBefore:(NoteBase *)note{
	NSEnumerator *measureEnum = [measures objectEnumerator];
	id measure;
	while((measure = [measureEnum nextObject]) && ![[measure getNotes] containsObject:note]);
	if(measure != nil){
		if([measure getFirstNote] == note){
			if(measure == [measures objectAtIndex:0]){
				return nil;
			}
			return [[[measures objectAtIndex:([measures indexOfObject:measure] - 1)] getNotes] lastObject];
		} else{
			return [[measure getNotes] objectAtIndex:([[measure getNotes] indexOfObject:note] - 1)];
		}
	}
	return nil;
}

- (NoteBase *)noteAfter:(NoteBase *)note{
	NSEnumerator *measureEnum = [measures objectEnumerator];
	id measure;
	while((measure = [measureEnum nextObject]) && ![[measure getNotes] containsObject:note]);
	if(measure != nil){
		if([[measure getNotes] lastObject] == note){
			if(measure == [measures lastObject]){
				return nil;
			}
			Measure *nextMeasure = [measures objectAtIndex:([measures indexOfObject:measure] + 1)];
			if([[nextMeasure getNotes] count] == 0){
				return nil;
			}
			return [[nextMeasure getNotes] objectAtIndex:0];
		} else{
			return [[measure getNotes] objectAtIndex:([[measure getNotes] indexOfObject:note] + 1)];
		}
	}
	return nil;
}

- (void)toggleClefAtMeasure:(Measure *)measure{
	Clef *oldClef = [measure getClef];
	if(oldClef != nil && measure != [measures objectAtIndex:0]){
		[measure setClef:nil];
	} else{
		oldClef = [self getClefForMeasure:measure];
		[measure setClef:[Clef getClefAfter:oldClef]];
	}
	Clef *newClef = [self getClefForMeasure:measure];
	int transposeAmount = [newClef getTranspositionFrom:oldClef];
	int index = [measures indexOfObject:measure] + 1;
	[measure transposeBy:transposeAmount];
	if(index < [measures count]){
		while(index < [measures count]){
			measure = [measures objectAtIndex:index++];
			if([measure getClef] != nil) break;
			[measure transposeBy:transposeAmount];
		}
	}
}

- (void)timeSigChangedAtMeasure:(Measure *)measure top:(int)top bottom:(int)bottom{
	[song timeSigChangedAtIndex:[measures indexOfObject:measure]
		top:(int)top bottom:(int)bottom];
}

- (void)timeSigDeletedAtMeasure:(Measure *)measure{
	if(measure != [measures objectAtIndex:0]){
		[song timeSigDeletedAtIndex:[measures indexOfObject:measure]];		
	}
}

- (void)cleanPanels{
	NSEnumerator *measureEnum = [measures objectEnumerator];
	id measure;
	while(measure = [measureEnum nextObject]){
		[measure cleanPanels];
	}
}

- (IBAction)soloPressed:(id)sender{
	if([sender state] == NSOnState){
		[muteButton setState:NSOffState];
	}
	[song soloPressed:([sender state] == NSOnState) onStaff:self];
}

- (void)muteSoloEnabled:(BOOL)enabled{
	[muteButton setEnabled:enabled];
	[soloButton setEnabled:enabled];
}

- (BOOL)isMute{
	return [muteButton state] == NSOnState;
}

- (BOOL)isSolo{
	return [soloButton state] == NSOnState;
}

- (void)addTrackToMIDISequence:(MusicSequence *)musicSequence{
	MusicTrack musicTrack;
	if (MusicSequenceNewTrack(*musicSequence, &musicTrack) != noErr) {
		NSLog(@"Cannot create music track.");
		return;
	}
  
	NSEnumerator *measureEnum = [measures objectEnumerator];
	id measure;
	float pos = 0.0;
	BOOL isRepeating;
	NSMutableArray *repeatMeasures = [NSMutableArray array];
	while(measure = [measureEnum nextObject]){
		if([measure isStartRepeat]){
			isRepeating = YES;
		}
		pos += [measure addToMIDITrack:&musicTrack atPosition:pos
				onChannel:channel];
		if(isRepeating){
			[repeatMeasures addObject:measure];
		}
		if([measure isEndRepeat]){
			isRepeating = NO;
			int i;
			for(i = 1; i < [measure getNumRepeats]; i++){
				NSEnumerator *repeatMeasuresEnum = [repeatMeasures objectEnumerator];
				id repeatMeasure;
				while(repeatMeasure = [repeatMeasuresEnum nextObject]){
					pos += [repeatMeasure addToMIDITrack:&musicTrack atPosition:pos
											   onChannel:channel];
				}
			}
			[repeatMeasures removeAllObjects];
		}
	}

	MIDIMetaEvent metaEvent = { 0x2f, 0, 0, 0, 0, { 0 } };
	if (MusicTrackNewMetaEvent(musicTrack, 13.0, &metaEvent) != noErr) {
		NSLog(@"Cannot add end of track meta event to track.");
		return;
	}

}

- (void)encodeWithCoder:(NSCoder *)coder{
	[coder encodeObject:measures forKey:@"measures"];
	[coder encodeInt:channel forKey:@"channel"];
}

- (id)initWithCoder:(NSCoder *)coder{
	if(self = [super init]){
		[self setMeasures:[coder decodeObjectForKey:@"measures"]];
		channel = [coder decodeIntForKey:@"channel"];
	}
	return self;
}

- (void)dealloc{
	[measures release];
	measures = nil;
	song = nil;
	[super dealloc];
}

- (Class)getViewClass{
	if([self isDrums]){
		return [DrumStaffDraw class];
	}
	return [StaffDraw class];
}
- (Class)getControllerClass{
	return [StaffController class];
}

@end
