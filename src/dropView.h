//
//  dropView.h
//  LESSCompile
//
//  Created by Michael on 4/21/14.
//
//

#import <Cocoa/Cocoa.h>

@protocol DraggingDestinationDelegate <NSObject>
@optional
-(void) draggingDestinationPerformedDragOperation:(id<NSDraggingInfo>)sender;
@end;


@interface dropView : NSView <NSDraggingDestination>

@property(strong, nonatomic) id<DraggingDestinationDelegate> delegate;

@end
