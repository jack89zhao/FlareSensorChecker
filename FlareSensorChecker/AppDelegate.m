//
//  AppDelegate.m
//  FlareSensorChecker
//
//  Created by Jackie Wang on 2020/4/28.
//  Copyright © 2020 Jackie Wang. All rights reserved.
//

#import "AppDelegate.h"
#import "LTSMC.h"

@interface AppDelegate ()
{
    int _gHandle;
    BOOL _connected;
    int _selectedAxis;
}
@property (weak) IBOutlet NSTextField *lbEmg;
@property (weak) IBOutlet NSTextField *lbServo;
@property (weak) IBOutlet NSTextField *lbPositive;
@property (weak) IBOutlet NSTextField *lbOrigin;
@property (weak) IBOutlet NSTextField *lbNegative;
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSComboBox *cbAxis;
@property (weak) IBOutlet NSTextField *tfErrorMsg;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [NSThread detachNewThreadSelector:@selector(checkSensor) toTarget:self withObject:nil];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    if (_connected) {
        smc_stop(_gHandle, _selectedAxis, 0);
        
        nmcs_clear_card_errcode(_gHandle);   // clear card error
        nmcs_clear_errcode(_gHandle,0);      // clear bus error
        
        for (int axis = 1; axis <= 12; axis++) {
            nmcs_clear_axis_errcode(_gHandle, axis);
        }
        
        int rtn = 0;
        for (int i = 1; i < 13 ; i++) {
            rtn |= smc_write_sevon_pin(_gHandle, i, 1);
            usleep(5000);
        }
        
        smc_board_close(_gHandle);
        _connected = NO;
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (IBAction)connect:(NSButton *)sender {
    if ([sender.title isEqualToString:@"Connect"]) {
        [_cbAxis selectItemWithObjectValue:@"Axis1"];
        [self selectAxis:_cbAxis];
        if (0 == (_gHandle=smc_board_init(0, 2, "192.168.5.11", 0))) {
            WORD cardNum;
            DWORD cardTypeList;
            WORD cardIdList;
            smc_get_CardInfList(&cardNum, &cardTypeList, &cardIdList);
            nmcs_clear_card_errcode(_gHandle);   // clear card error
            nmcs_clear_errcode(_gHandle,0);      // clear bus error
            nmcs_set_alarm_clear(_gHandle,2,0);

            for (int axis = 1; axis <= 12; axis++) {
                nmcs_clear_axis_errcode(_gHandle, axis);
            }

            int rtn = 0;
            for (int i = 1; i < 13 ; i++) {
                rtn |= smc_write_sevon_pin(_gHandle, i, 0);
                usleep(50000);
            }

            _connected = YES;
            [_cbAxis selectItemAtIndex:0];
            sender.title = @"Disconnect";
        } else {
            NSAlert *alert = [NSAlert new];
            alert.informativeText = @"Connect fail";
            alert.messageText = @"Error";
            [alert runModal];
        }
    } else {
        nmcs_clear_card_errcode(_gHandle);   // clear card error
        nmcs_clear_errcode(_gHandle,0);      // clear bus error
        
        for (int axis = 1; axis <= 12; axis++) {
            nmcs_clear_axis_errcode(_gHandle, axis);
        }
        usleep(20000);
        
        int rtn = 0;
        for (int i = 1; i < 13 ; i++) {
            rtn |= smc_write_sevon_pin(_gHandle, i, 1);
            usleep(50000);
        }
        
        if ((rtn = smc_board_close(_gHandle))) {
            sender.title = @"Disconnect";
        } else {
            sender.title = @"Connect";
        }
        _connected = NO;
    }
}

- (IBAction)selectAxis:(NSComboBox *)sender {
    NSString *axisString = sender.objectValueOfSelectedItem;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    
    if (regex) {
        NSTextCheckingResult *tcr = [regex firstMatchInString:axisString options:NSMatchingReportCompletion range:NSMakeRange(0, axisString.length)];
        if (tcr) {
            int axis = [[axisString substringWithRange:tcr.range] intValue];
            _selectedAxis = axis;
        }
    }
}

- (IBAction)move:(NSButton *)sender {
    int rtn = 0;
    int direction = 1;
    double ratio = 1;
    
    if ([sender.title isEqualToString:@"Move+"]) {
        direction = 1;
    } else {
        direction = 0;
    }
    
    switch (_selectedAxis) {
        case 1:
            ratio = 100;
            break;
        case 2:
        case 3:
            ratio = 2500;
            break;
        case 4:
            ratio = 15000;
            break;
        case 5:
        case 6:
        case 7:
        case 8:
            ratio = 1000;
            break;
        case 9:
            ratio = 40000;
            break;
        case 10:
            ratio = 800;
            break;
        case 11:
        case 12:
            ratio = 2000;
            break;
        default:
            break;
    }
    
    if (_connected) {
        for (int axis = 0; axis <= 12; axis++) {
            smc_stop(_gHandle, axis, 0);
        }
        
        rtn |= smc_set_profile_unit(_gHandle, _selectedAxis, 5.0 * ratio, 15.0 * ratio, 2, 2, 5 * ratio);
        rtn |= smc_set_s_profile(_gHandle, _selectedAxis,0,0);
        rtn |= smc_vmove(_gHandle, _selectedAxis, direction);
        
        if (rtn != 0) {
            NSLog(@"Error code: %d", rtn);
            _tfErrorMsg.stringValue = [NSString stringWithFormat:@"Error code: %d", rtn];
            _tfErrorMsg.hidden = NO;
        }
        else {
            _tfErrorMsg.stringValue = @"";
            _tfErrorMsg.hidden = YES;
            sender.enabled = NO;
            
            __weak NSButton *button = sender;
            
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                while(smc_check_done(self->_gHandle, self->_selectedAxis)==0) { usleep(10000); } //等待运动停止
                dispatch_async(dispatch_get_main_queue(), ^{
                    button.enabled = YES;
                });
            });
        }
    }
}

- (IBAction)stopAxis:(NSButton *)sender {
    if (_connected) {
        _tfErrorMsg.stringValue = @"";
        _tfErrorMsg.hidden = YES;
        smc_stop(_gHandle, _selectedAxis, 0);
    }
}

- (void)checkSensor {
    while (!_connected) {
        sleep(1);
    }
    
    while (_connected) {
        DWORD state = smc_axis_io_status(_gHandle, _selectedAxis);
        
        int index = 0;
        state <<= 1;
        
        do {
            state = state >> 1;
            int bit = state & 0x01;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                switch (index) {
                    case 0:
                        if (bit==1) {
                            self->_lbServo.backgroundColor = NSColor.greenColor;
                            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                                NSString *errorMsg = [self showErrorMessage:self->_selectedAxis];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    self->_tfErrorMsg.stringValue = errorMsg;
                                });
                            });
                        } else {
                            self->_lbServo.backgroundColor = NSColor.redColor;
                        } break;
                    case 1:
                        if (bit==1) {
                            self->_lbPositive.backgroundColor = NSColor.greenColor;
                        } else{
                            self->_lbPositive.backgroundColor = NSColor.redColor;
                        } break;
                    case 2:
                        if (bit==1) {
                            self->_lbNegative.backgroundColor = NSColor.greenColor;
                        } else {
                            self->_lbNegative.backgroundColor = NSColor.redColor;
                        } break;
                    case 3:
                        if (bit==1) {
                            self->_lbEmg.backgroundColor = NSColor.greenColor;
                        } else{
                            self->_lbEmg.backgroundColor = NSColor.redColor;
                        } break;
                    case 4:
                        if (bit==1) {
                            self->_lbOrigin.backgroundColor = NSColor.greenColor;
                        } else{
                            self->_lbOrigin.backgroundColor = NSColor.redColor;
                        } break;
                    default: break;
                }
            });
            index++;
        } while (state);
    }
}

- (NSString *)showErrorMessage:(int)axis {
    NSMutableString *errorMsg = [NSMutableString new];
    
    if (_gHandle != -1) {
        do {
            [errorMsg appendFormat:@"Axis %d driver alarm. ", axis];
            
            DWORD errorcode = 0;
            nmcs_get_errcode(_gHandle, 2, &errorcode);
            
            if (errorcode != 0) {
                [errorMsg appendFormat:@"The bus error, errorcode: 0x%lx", errorcode];
                break;
            }
            
            nmcs_get_card_errcode(_gHandle, &errorcode);
            
            if (errorcode != 0) {
                [errorMsg appendFormat:@"The bus error, errorcode: 0x%lx", errorcode];
                break;
            }
            
        } while (0);
    }
    
    return errorMsg;
}

@end
