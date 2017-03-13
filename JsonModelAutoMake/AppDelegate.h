//
//  AppDelegate.h
//  JsonModelAutoMake
//
//  Created by yangjihang on 14/12/9.
//  Copyright (c) 2014年 yangjihang. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property(weak) IBOutlet NSTextField *urlTextField;
@property(weak) IBOutlet NSTextField *customJsonModelNameTextField;
@property(weak) IBOutlet NSButton *generateByURLButton;
@property(weak) IBOutlet NSButton *generateByJsonFileFromDesktopButton;

- (IBAction)generateByURLClicked:(id)sender;
- (IBAction)generateByJsonFilesClicked:(id)sender;

@end

