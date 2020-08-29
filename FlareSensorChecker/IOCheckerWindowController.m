//
//  IOCheckerWindowController.m
//  FlareSensorChecker
//
//  Created by Jackie Wang on 2020/7/1.
//  Copyright © 2020 Jackie Wang. All rights reserved.
//

#import "LTSMC.h"
#import "IOCheckerWindowController.h"

@interface IOCheckerWindowController ()
{
    NSDictionary *_ioTable;
    NSPopover *_popover;
    BOOL _isConnected;
    dispatch_source_t _timer;
    NSMutableDictionary *_inputControls;
    NSMutableDictionary *_outputControls;
}
@property (weak) IBOutlet NSBox *outputIOBox;
@property (weak) IBOutlet NSBox *inputIOBox;

@end

@implementation IOCheckerWindowController

- (instancetype)initWithControllerState:(BOOL)controllerState {
    if (self = [super init]) {
        [NSBundle.mainBundle loadNibNamed:self.className owner:self topLevelObjects:nil];
        
        if (!_ioTable) {
            NSString *path = [NSBundle.mainBundle pathForResource:@"IOTable" ofType:@"plist"];
            _ioTable = [NSDictionary dictionaryWithContentsOfFile:path];
        }
        
        if (!_inputControls) {
            _inputControls = [NSMutableDictionary new];
        }
        
        if (!_outputControls) {
            _outputControls = [NSMutableDictionary new];
        }
        
        _isConnected = controllerState;
        [self loadIOTable];
        [self checkIOState];
    }
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)exitChecker:(NSButton *)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (NSTextField *)createLabelWithFrame:(NSRect)frame andStringValue:(NSString *)string {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.editable = NO;
    label.drawsBackground = NO;
    label.bordered = NO;
    label.alignment = NSTextAlignmentCenter;
    label.stringValue = string;
    
    return label;
}

- (NSImageView *)createImageViewWithFrame:(NSRect)frame andImage:(NSImage *)image identifier:(NSString *)identifier {
    NSImageView *imageView = [NSImageView imageViewWithImage:image];
    [imageView setFrame:frame];
    [imageView setTarget:self];
    [imageView setIdentifier:identifier];
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:imageView.bounds
                                                                options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                                                                  owner:self
                                                               userInfo:@{@"object":imageView}];
    [imageView addTrackingArea:trackingArea];
    
    return imageView;
}

- (NSButton *)createImageButtonWithFrame:(NSRect)frame andImage:(NSImage *)image identifier:(NSString *)identifier {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.image = image;
    button.identifier = identifier;
    button.bordered = NO;
    [button setTarget:self];
    [button setAction:@selector(outputIOClick:)];
    [button setButtonType:NSButtonTypeMomentaryPushIn];
    [button setBezelStyle:NSBezelStyleRegularSquare];
    [button setImageScaling:NSImageScaleAxesIndependently];
    
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:button.bounds
                                                                options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                                                                  owner:self
                                                               userInfo:@{@"object":button}];
    [button addTrackingArea:trackingArea];
    
    return button;
}

- (void)loadIOTable {
    NSImage *led = [NSImage imageNamed:@"grayLed.png"];
    NSDictionary *inputIOs = _ioTable[@"input"];
    NSArray *keys = [inputIOs.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 intValue] > [obj2 intValue];
    }];
    
    CGFloat height = self.inputIOBox.contentView.frame.size.height;
    CGFloat width = self.inputIOBox.contentView.frame.size.width;
    int xStep = width / 7;
    
    for (int inio = 0; inio < inputIOs.count; inio++) {
        CGFloat orgX = xStep * ((int)inio % 7) + 25;
        CGFloat orgY = 70 * ((int)inio / 7) + 32;

        NSTextField *ioNumField = [self createLabelWithFrame:NSMakeRect(orgX, height - orgY, 25, 25) andStringValue:keys[inio]];
        [self.inputIOBox addSubview:ioNumField];
        
        NSImageView *imageView = [self createImageViewWithFrame:NSMakeRect(orgX, height - (orgY + 25), 25, 25)
                                                       andImage:led
                                                     identifier:keys[inio]];
        [self.inputIOBox addSubview:imageView];
        _inputControls[imageView.identifier] = imageView;
    }
    
    NSDictionary *outputIOs = _ioTable[@"output"];
    keys = [outputIOs.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 intValue] > [obj2 intValue];
    }];
    
    height = self.outputIOBox.contentView.frame.size.height;
    width = self.outputIOBox.contentView.frame.size.width;
    xStep = width / 7;
    
    for (int outio = 0; outio < outputIOs.count; outio++) {
        CGFloat orgX = xStep * ((int)outio % 7) + 25;
        CGFloat orgY = 70 * ((int)outio / 7) + 32;
        
        NSTextField *ioNumField = [self createLabelWithFrame:NSMakeRect(orgX, height - orgY, 25, 25) andStringValue:keys[outio]];
        [self.outputIOBox addSubview:ioNumField];
        
        NSButton *button = [self createImageButtonWithFrame:NSMakeRect(orgX, height - (orgY + 40), 30, 40)
                                                   andImage:[NSImage imageNamed:@"high_on.png"]
                                                 identifier:keys[outio]];
        [self.outputIOBox addSubview:button];
        _outputControls[button.identifier] = button;
    }
    
}

- (void)outputIOClick:(NSButton *)sender {
    if (_isConnected) {
        int controllerID = 0;
        WORD onOff = [sender.image isEqual:[NSImage imageNamed:@"high_on.png"]] ? 0 : 1;
        smc_write_outbit(controllerID, [sender.identifier intValue], onOff);
    }   
}

- (void)mouseEntered:(NSEvent *)event {
    NSControl *control = [(NSDictionary*)event.userData objectForKey:@"object"];
    NSString *tableKey = [control isKindOfClass:NSImageView.class] ? @"input" : @"output";
    NSString *tips = _ioTable[tableKey][control.identifier];
    
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 25)];
    field.bordered = NO;
    field.drawsBackground = NO;
    field.editable = NO;
    field.alignment = NSTextAlignmentCenter;
    field.stringValue = [NSString stringWithFormat:@"%@ io %@ : %@", tableKey, control.identifier, tips];
    NSViewController *viewController = [[NSViewController alloc] init];
    viewController.view = [[NSView alloc] initWithFrame:field.frame];
    [viewController.view addSubview:field];
    
    if (!_popover) {
        _popover = [[NSPopover alloc] init];
        
        if (@available(macOS 10.14, *)) {
            _popover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantLight];
        } else {
            // Fallback on earlier versions
            _popover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        }
        _popover.behavior = NSPopoverBehaviorTransient;
    }
    _popover.contentViewController = viewController;
    [_popover showRelativeToRect:control.bounds ofView:control preferredEdge:NSRectEdgeMaxY];
}

- (void)mouseExited:(NSEvent *)event {
    if (!_popover) {
        [_popover close];
    }
}

- (void)checkIOState {
    dispatch_queue_t queue = dispatch_queue_create("com.mt.iocheck.queue", 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC, 10 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, ^{
        if (self->_isConnected) {
            DWORD inState = smc_read_inport(0, 0);
            DWORD outState = smc_read_outport(0, 0);
            for (int inio = 0; inio <= [self->_ioTable[@"input"] count]; inio++) {
                if ((inState >> inio) & 0x01) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *key = [NSString stringWithFormat:@"%d", inio];
                        NSImageView *imageView = self->_inputControls[key];
                        imageView.image = [NSImage imageNamed:@"greenLed.png"];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *key = [NSString stringWithFormat:@"%d", inio];
                        NSImageView *imageView = self->_inputControls[key];
                        imageView.image = [NSImage imageNamed:@"redLed.png"];
                    });
                }
            }
        
            for (int outio = 0; outio <= [self->_ioTable[@"output"] count]; outio++) {
                if ((outState >> outio) & 0x01) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *key = [NSString stringWithFormat:@"%d", outio];
                        NSButton *button = self->_outputControls[key];
                        button.image = [NSImage imageNamed:@"high_on.png"];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *key = [NSString stringWithFormat:@"%d", outio];
                        NSButton *button = self->_outputControls[key];
                        button.image = [NSImage imageNamed:@"low_off.png"];
                    });
                }
            }
        }
    });
    dispatch_resume(timer);
    _timer = timer;
}

@end
