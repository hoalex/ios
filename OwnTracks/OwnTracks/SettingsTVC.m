//
//  SettingsTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 11.09.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import "SettingsTVC.h"
#import "CertificatesTVC.h"
#import "TabBarController.h"
#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "Friend+Create.h"
#import "CoreData.h"
#import "AlertView.h"
#import "OwnTracking.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

#define QRSCANNER NSLocalizedString(@"QRScanner", @"Header of an alert message regarging QR code scanning")

@interface SettingsTVC ()
@property (weak, nonatomic) IBOutlet UITableViewCell *UITLSCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *UIclientPKCSCell;
@property (weak, nonatomic) IBOutlet UITextField *UIclientPKCS;
@property (weak, nonatomic) IBOutlet UISwitch *UIallowinvalidcerts;
@property (weak, nonatomic) IBOutlet UITextField *UIpassphrase;
@property (weak, nonatomic) IBOutlet UISwitch *UIvalidatecertificatechain;
@property (weak, nonatomic) IBOutlet UISwitch *UIvalidatedomainname;
@property (weak, nonatomic) IBOutlet UISegmentedControl *UIpolicymode;
@property (weak, nonatomic) IBOutlet UISwitch *UIusepolicy;
@property (weak, nonatomic) IBOutlet UITableViewCell *UIserverCERCell;
@property (weak, nonatomic) IBOutlet UITextField *UIserverCER;
@property (weak, nonatomic) IBOutlet UISegmentedControl *UImode;
@property (weak, nonatomic) IBOutlet UITextField *UIDeviceID;
@property (weak, nonatomic) IBOutlet UITextField *UIHost;
@property (weak, nonatomic) IBOutlet UITextField *UIUserID;
@property (weak, nonatomic) IBOutlet UITextField *UIPassword;
@property (weak, nonatomic) IBOutlet UITextField *UIPort;
@property (weak, nonatomic) IBOutlet UISwitch *UITLS;
@property (weak, nonatomic) IBOutlet UISwitch *UIAuth;
@property (weak, nonatomic) IBOutlet UITextField *UItrackerid;
@property (weak, nonatomic) IBOutlet UIButton *UIexport;
@property (weak, nonatomic) IBOutlet UIButton *UIpublish;
@property (weak, nonatomic) IBOutlet UITextField *UIsecret;
@property (weak, nonatomic) IBOutlet UITextField *UIurl;

@property (strong, nonatomic) UIDocumentInteractionController *dic;
@property (strong, nonatomic) UIAlertView *tidAlertView;
@property (strong, nonatomic) UIAlertView *modeAlertView;
@property (strong, nonatomic) QRCodeReaderViewController *reader;

@end

@implementation SettingsTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.UIHost.delegate = self;
    self.UIPort.delegate = self;
    self.UIUserID.delegate = self;
    self.UIPassword.delegate = self;
    self.UIsecret.delegate = self;
    self.UItrackerid.delegate = self;
    self.UIDeviceID.delegate = self;
    self.UIpassphrase.delegate = self;
    self.UIurl.delegate = self;
    
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate addObserver:self
               forKeyPath:@"configLoad"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    [self updated];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return TRUE;
}

- (void)viewWillDisappear:(BOOL)animated {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate removeObserver:self
                  forKeyPath:@"configLoad"
                     context:nil];
    [self reconnect];
    [super viewWillDisappear:animated];
}

- (void)updateValues {
    if (self.UIDeviceID) [Settings setString:self.UIDeviceID.text forKey:@"deviceid_preference"];
    if (self.UIclientPKCS) [Settings setString:self.UIclientPKCS.text forKey:@"clientpkcs"];
    if (self.UIserverCER) [Settings setString:self.UIserverCER.text forKey:@"servercer"];
    if (self.UIpassphrase) [Settings setString:self.UIpassphrase.text forKey:@"passphrase"];
    if (self.UIpolicymode) [Settings setInt:(int)self.UIpolicymode.selectedSegmentIndex forKey:@"policymode"];
    if (self.UIusepolicy) [Settings setBool:self.UIusepolicy.on forKey:@"usepolicy"];
    if (self.UIallowinvalidcerts) [Settings setBool:self.UIallowinvalidcerts.on forKey:@"allowinvalidcerts"];
    if (self.UIvalidatedomainname) [Settings setBool:self.UIvalidatedomainname.on forKey:@"validatedomainname"];
    if (self.UIvalidatecertificatechain) [Settings setBool:self.UIvalidatecertificatechain.on forKey:@"validatecertificatechain"];
    if (self.UItrackerid) [Settings setString:self.UItrackerid.text forKey:@"trackerid_preference"];
    if (self.UIHost) [Settings setString:self.UIHost.text forKey:@"host_preference"];
    if (self.UIUserID) [Settings setString:self.UIUserID.text forKey:@"user_preference"];
    if (self.UIPassword) [Settings setString:self.UIPassword.text forKey:@"pass_preference"];
    if (self.UIsecret) [Settings setString:self.UIsecret.text forKey:@"secret_preference"];
    if (self.UImode) {
        switch (self.UImode.selectedSegmentIndex) {
            case 2:
                [Settings setInt:MODE_HTTP forKey:@"mode"];
                break;
            case 1:
                [Settings setInt:MODE_PUBLIC forKey:@"mode"];
                break;
            case 0:
            default:
                [Settings setInt:MODE_PRIVATE forKey:@"mode"];
                break;
        }
    }
    if (self.UIPort) [Settings setString:self.UIPort.text forKey:@"port_preference"];
    if (self.UITLS) [Settings setBool:self.UITLS.on forKey:@"tls_preference"];
    if (self.UIAuth) [Settings setBool:self.UIAuth.on forKey:@"auth_preference"];
    if (self.UIurl) [Settings setString:self.UIurl.text forKey:@"url_preference"];
    
    [CoreData saveContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    DDLogVerbose(@"observeValueForKeyPath %@", keyPath);

    if ([keyPath isEqualToString:@"configLoad"]) {
        [self performSelectorOnMainThread:@selector(updated) withObject:nil waitUntilDone:NO];
    }
}

- (void)updated
{
    BOOL locked = [Settings boolForKey:@"locked"];
    self.title = [NSString stringWithFormat:@"%@%@",
                  NSLocalizedString(@"Settings",
                                    @"Settings screen title"),
                  locked ?
                  [NSString stringWithFormat:@" (%@)", NSLocalizedString(@"locked",
                                                                         @"indicates a locked configuration")] :
                  @""];
    
    if (self.UIDeviceID) {
        self.UIDeviceID.text =  [Settings stringForKey:@"deviceid_preference"];
        self.UIDeviceID.enabled = !locked;
    }
    
    if (self.UIclientPKCS) {
        self.UIclientPKCS.text = [Settings stringForKey:@"clientpkcs"];
        self.UIclientPKCS.enabled = !locked;
        self.UIclientPKCSCell.userInteractionEnabled = !locked;
        self.UIclientPKCSCell.accessoryType = !locked ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    }

    if (self.UIpassphrase) {
        if (self.UIclientPKCS) {
            self.UIpassphrase.enabled = !locked && (self.UIclientPKCS.text.length > 0);
            self.UIpassphrase.textColor = (self.UIclientPKCS.text.length > 0) ? [UIColor blackColor] : [UIColor lightGrayColor];
        }
        self.UIpassphrase.text = [Settings stringForKey:@"passphrase"];
    }

    if (self.UIusepolicy) {
        self.UIusepolicy.on =  [Settings boolForKey:@"usepolicy"];
        self.UIusepolicy.enabled = !locked;
    }
    
    if (self.UIpolicymode) {
        if (self.UIusepolicy) {
            self.UIpolicymode.enabled = !locked && self.UIusepolicy.on;
        }
        self.UIpolicymode.selectedSegmentIndex = [Settings intForKey:@"policymode"];
    }
    if (self.UIserverCER) {
        if (self.UIusepolicy && self.UIpolicymode) {
            self.UIserverCERCell.userInteractionEnabled = !locked && self.UIusepolicy.on && self.UIpolicymode.selectedSegmentIndex != 0;
            self.UIserverCERCell.accessoryType = (!locked && self.UIusepolicy.on && self.UIpolicymode.selectedSegmentIndex != 0) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
;
        }
        self.UIserverCER.text = [Settings stringForKey:@"servercer"];
    }
    if (self.UIallowinvalidcerts) {
        if (self.UIusepolicy) {
            self.UIallowinvalidcerts.enabled = !locked && self.UIusepolicy.on;
        }
        self.UIallowinvalidcerts.on = [Settings boolForKey:@"allowinvalidcerts"];
    }
    if (self.UIvalidatedomainname) {
        if (self.UIusepolicy) {
            self.UIvalidatedomainname.enabled = !locked && self.UIusepolicy.on;
        }
        self.UIvalidatedomainname.on =  [Settings boolForKey:@"validatedomainname"];
    }
    if (self.UIvalidatecertificatechain) {
        if (self.UIusepolicy) {
            self.UIvalidatecertificatechain.enabled = !locked && self.UIusepolicy.on;
        }
        self.UIvalidatecertificatechain.on = [Settings boolForKey:@"validatecertificatechain"];
    }
    
    if (self.UItrackerid) {
        self.UItrackerid.text = [Settings stringForKey:@"trackerid_preference"];
        self.UItrackerid.enabled = !locked;
    }
    if (self.UIHost) {
        self.UIHost.text = [Settings stringForKey:@"host_preference"];
        self.UIHost.enabled = !locked;
    }
    if (self.UIUserID) {
        self.UIUserID.text = [Settings stringForKey:@"user_preference"];
        self.UIUserID.enabled = !locked;
    }
    if (self.UIPassword) {
        self.UIPassword.text = [Settings stringForKey:@"pass_preference"];
        self.UIPassword.enabled = !locked;
    }
    if (self.UIsecret) {
        self.UIsecret.text = [Settings stringForKey:@"secret_preference"];
        self.UIsecret.enabled = !locked;
    }
    if (self.UImode) {
        switch ([Settings intForKey:@"mode"]) {
            case MODE_HTTP:
                self.UImode.selectedSegmentIndex = 2;
                break;
            case MODE_PUBLIC:
                self.UImode.selectedSegmentIndex = 1;
                break;
            case MODE_PRIVATE:
            default:
                self.UImode.selectedSegmentIndex = 0;
                break;
        }
        self.UImode.enabled = !locked;
    }
    if (self.UIPort) {
        self.UIPort.text = [Settings stringForKey:@"port_preference"];
        self.UIPort.enabled = !locked;
    }
    if (self.UITLS) {
        self.UITLS.on = [Settings boolForKey:@"tls_preference"];
        self.UITLS.enabled = !locked;
    }
    if (self.UIAuth) {
        self.UIAuth.on = [Settings boolForKey:@"auth_preference"];
        self.UIAuth.enabled = !locked;
    }
    if (self.UIurl) {
        self.UIurl.text = [Settings stringForKey:@"url_preference"];
        self.UIurl.enabled = !locked;
    }
    int mode = [Settings intForKey:@"mode"];

    NSMutableArray *hiddenFieldsMode123 = [[NSMutableArray alloc] init];
    NSMutableArray *hiddenIndexPathsMode123 = [[NSMutableArray alloc] init];
    
    if (self.UIHost) {
        [hiddenFieldsMode123 addObject:self.UIHost];
        [hiddenIndexPathsMode123 addObject:[NSIndexPath indexPathForRow:5 inSection:0]];
    }
    if (self.UIPort) {
        [hiddenFieldsMode123 addObject:self.UIPort];
        [hiddenIndexPathsMode123 addObject:[NSIndexPath indexPathForRow:6 inSection:0]];
    }
    if (self.UITLS) {
        [hiddenFieldsMode123 addObject:self.UITLS];
        [hiddenIndexPathsMode123 addObject:[NSIndexPath indexPathForRow:7 inSection:0]];
    }
    if (self.UIAuth) {
        [hiddenFieldsMode123 addObject:self.UIAuth];
        [hiddenIndexPathsMode123 addObject:[NSIndexPath indexPathForRow:8 inSection:0]];
        
    }
    if (self.UIUserID) {
        if (self.UIAuth) {
            self.UIUserID.enabled = !locked && self.UIAuth.on;
            self.UIUserID.textColor = self.UIAuth.on ? [UIColor blackColor] : [UIColor lightGrayColor];
        }
        [hiddenFieldsMode123 addObject:self.UIUserID];
        [hiddenIndexPathsMode123 addObject:[NSIndexPath indexPathForRow:9 inSection:0]];
    }
    if (self.UIPassword) {
        if (self.UIAuth) {
            self.UIPassword.enabled = !locked && self.UIAuth.on;
            self.UIPassword.textColor = self.UIAuth.on ? [UIColor blackColor] : [UIColor lightGrayColor];
        }
        [hiddenFieldsMode123 addObject:self.UIPassword];
        [hiddenIndexPathsMode123 addObject:[NSIndexPath indexPathForRow:10 inSection:0]];
    }
    
    if (self.UIDeviceID) {
        [hiddenFieldsMode123 addObject:self.UIDeviceID];
        [hiddenIndexPathsMode123 addObject:[NSIndexPath indexPathForRow:4 inSection:0]];
    }
    
    NSMutableArray *hiddenFieldsMode12 = [[NSMutableArray alloc] init];
    NSMutableArray *hiddenIndexPathsMode12 = [[NSMutableArray alloc] init];
    
    if (self.UIsecret) {
        [hiddenFieldsMode12 addObject:self.UIsecret];
        [hiddenIndexPathsMode12 addObject:[NSIndexPath indexPathForRow:11 inSection:0]];
    }
    
    NSMutableArray *hiddenFieldsMode012 = [[NSMutableArray alloc] init];
    NSMutableArray *hiddenIndexPathsMode012 = [[NSMutableArray alloc] init];
    if (self.UIurl) {
        [hiddenFieldsMode012 addObject:self.UIurl];
        [hiddenIndexPathsMode012 addObject:[NSIndexPath indexPathForRow:12 inSection:0]];
    }
    
    // hide mode row if locked
    if (self.UImode) {
        NSIndexPath *modeIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        if ([self isRowVisible:modeIndexPath] && locked) {
            [self deleteRowsAtIndexPaths:@[modeIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else if (![self isRowVisible:modeIndexPath] && !locked) {
            [self insertRowsAtIndexPaths:@[modeIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    // hide fields and rows depending on modes
    for (UIView *view in hiddenFieldsMode012) {
        [view setHidden:(mode == MODE_PRIVATE || mode == MODE_HOSTED || mode == MODE_PUBLIC)];
    }
    
    for (NSIndexPath *indexPath in hiddenIndexPathsMode012) {
        if ([self isRowVisible:indexPath] && (mode == MODE_PRIVATE || mode == 1 || mode == MODE_PUBLIC)) {
            [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else if (![self isRowVisible:indexPath] && !(mode == MODE_PRIVATE || mode == 1 || mode == MODE_PUBLIC)) {
            [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    for (UIView *view in hiddenFieldsMode12) {
        [view setHidden:(mode == MODE_HOSTED || mode == MODE_PUBLIC)];
    }
    
    for (NSIndexPath *indexPath in hiddenIndexPathsMode12) {
        if ([self isRowVisible:indexPath] && (mode == MODE_HOSTED || mode == MODE_PUBLIC)) {
            [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else if (![self isRowVisible:indexPath] && !(mode == MODE_HOSTED || mode == MODE_PUBLIC)) {
            [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    for (UIView *view in hiddenFieldsMode123) {
        [view setHidden:(mode == MODE_HOSTED || mode == MODE_PUBLIC || mode == MODE_HTTP)];
    }
    
    for (NSIndexPath *indexPath in hiddenIndexPathsMode123) {
        if ([self isRowVisible:indexPath] && (mode == MODE_HOSTED || mode == MODE_PUBLIC || mode == MODE_HTTP)) {
            [self deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else if (![self isRowVisible:indexPath] && !(mode == MODE_HOSTED || mode == MODE_PUBLIC || mode == MODE_HTTP)) {
            [self insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    if (self.UIexport) self.UIexport.hidden = (mode == MODE_PUBLIC);
    if (self.UIpublish) self.UIpublish.hidden = (mode == MODE_PUBLIC);
    
    if (self.UITLS) {
        if (self.UITLSCell) {
            self.UITLSCell.accessoryType = self.UITLS.on ? UITableViewCellAccessoryDetailDisclosureButton : UITableViewCellAccessoryNone;
        }
    }

    if ([self.tabBarController isKindOfClass:[TabBarController class]]) {
        TabBarController *tbc = (TabBarController *)self.tabBarController;
        [tbc adjust];
    }
}

- (IBAction)publishSettingsPressed:(UIButton *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate dump];
}

- (IBAction)publishWaypointsPressed:(UIButton *)sender {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate waypoints];
}

- (IBAction)exportPressed:(UIButton *)sender {
    NSError *error;
    
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:&error];
    NSString *fileName = [NSString stringWithFormat:@"config.otrc"];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
    
    [[NSFileManager defaultManager] createFileAtPath:[fileURL path]
                                            contents:[Settings toData]
                                          attributes:nil];
    
    self.dic = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.dic.delegate = self;
    
    [self.dic presentOptionsMenuFromRect:self.UIexport.frame inView:self.UIexport animated:TRUE];
}

- (IBAction)exportWaypointsPressed:(UIButton *)sender {
    NSError *error;
    
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:&error];
    NSString *fileName = [NSString stringWithFormat:@"config.otrw"];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
    
    [[NSFileManager defaultManager] createFileAtPath:[fileURL path]
                                            contents:[Settings waypointsToData]
                                          attributes:nil];
    
    self.dic = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.dic.delegate = self;
    
    [self.dic presentOptionsMenuFromRect:self.UIexport.frame inView:self.UIexport animated:TRUE];
}

- (IBAction)hostedPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:
     [NSURL URLWithString:@"https://hosted.owntracks.org"]];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController respondsToSelector:@selector(setSelectedFileNames:)] &&
        [segue.destinationViewController respondsToSelector:@selector(setMultiple:)] &&
        [segue.destinationViewController respondsToSelector:@selector(setFileNameIdentifier:)]) {
        if ([segue.identifier isEqualToString:@"setClientPKCS"]) {
            [segue.destinationViewController performSelector:@selector(setSelectedFileNames:)
                                                  withObject:[Settings stringForKey:@"clientpkcs"]];
            [segue.destinationViewController performSelector:@selector(setFileNameIdentifier:)
                                                  withObject:@"clientpkcs"];
            [segue.destinationViewController performSelector:@selector(setMultiple:)
                                                  withObject:[NSNumber numberWithBool:FALSE]];
            
        }
        if ([segue.identifier isEqualToString:@"setServerCER"]) {
            [segue.destinationViewController performSelector:@selector(setSelectedFileNames:)
                                                  withObject:[Settings stringForKey:@"servercer"]];
            [segue.destinationViewController performSelector:@selector(setFileNameIdentifier:)
                                                  withObject:@"servercer"];
            [segue.destinationViewController performSelector:@selector(setMultiple:)
                                                  withObject:[NSNumber numberWithBool:TRUE]];
        }
    }
}

- (IBAction)setNames:(UIStoryboardSegue *)segue {
    if ([segue.sourceViewController respondsToSelector:@selector(selectedFileNames)] &&
        [segue.sourceViewController respondsToSelector:@selector(fileNameIdentifier)]) {
        NSString *names = [segue.sourceViewController performSelector:@selector(selectedFileNames)];
        NSString *identifier = [segue.sourceViewController performSelector:@selector(fileNameIdentifier)];
        
        [Settings setString:names forKey:identifier];
        [self updated];
    }
}

- (NSString *)qosString:(int)qos
{
    switch (qos) {
        case 2:
            return NSLocalizedString(@"exactly once (2)",
                                     @"description of MQTT QoS level 2");
        case 1:
            return NSLocalizedString(@"at least once (1)",
                                     @"description of MQTT QoS level 1");
        case 0:
        default:
            return NSLocalizedString(@"at most once (0)",
                                     @"description of MQTT QoS level 0");
    }
}

- (IBAction)touchedOutsideText:(UITapGestureRecognizer *)sender {
    [self.UIHost resignFirstResponder];
    [self.UIPort resignFirstResponder];
    [self.UIUserID resignFirstResponder];
    [self.UIPassword resignFirstResponder];
    [self.UIsecret resignFirstResponder];
    [self.UItrackerid resignFirstResponder];
    [self.UIDeviceID resignFirstResponder];
}

#define INVALIDTRACKERID NSLocalizedString(@"TrackerID invalid", @"Alert header regarding TrackerID input")

- (IBAction)tidChanged:(UITextField *)sender {
    
    if (sender.text.length > 2) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:INVALIDTRACKERID
                                  message:NSLocalizedString(@"TrackerID may be empty or up to 2 characters long",
                                                            @"Alert content regarding TrackerID input")
                                  delegate:self
                                  cancelButtonTitle:nil
                                  otherButtonTitles:NSLocalizedString(@"OK",
                                                                      @"OK button title"),
                                  nil
                                  ];
        [alertView show];
        sender.text = [Settings stringForKey:@"trackerid_preference"];
        return;
    }
    for (int i = 0; i < sender.text.length; i++) {
        if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[sender.text characterAtIndex:i]]) {
            self.tidAlertView = [[UIAlertView alloc]
                                 initWithTitle:INVALIDTRACKERID
                                 message:NSLocalizedString(@"TrackerID may contain alphanumeric characters only",
                                                           @"Alert content regarding TrackerID input")
                                 delegate:self
                                 cancelButtonTitle:nil
                                 otherButtonTitles:NSLocalizedString(@"OK",
                                                                     @"OK button title"),
                                 nil
                                 ];
            [self.tidAlertView show];
            sender.text = [Settings stringForKey:@"trackerid_preference"];
            return;
        }
    }
    [Settings setString:sender.text forKey:@"trackerid_preference"];
}

- (IBAction)modeChanged:(UISegmentedControl *)sender {
    self.modeAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Mode change",
                                                                              @"Alert header for mode change warning")
                                                    message:NSLocalizedString(@"Please be aware your stored waypoints and locations will be deleted on this device for privacy reasons. Please backup before.",
                                                                              @"Alert content for mode change warning")
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel",
                                                                              @"Cancel button title")
                                          otherButtonTitles:NSLocalizedString(@"Continue",
                                                                              @"Continue button title"),
                          nil
                          ];
    [self.modeAlertView show];
}

- (IBAction)authChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}

- (IBAction)tlsChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)usePolicyChanged:(UISwitch *)sender {
    [self updateValues];
    [self updated];
}
- (IBAction)policyModeChanged:(UISegmentedControl *)sender {
    [self updateValues];
    [self updated];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;

    if (alertView == self.tidAlertView) {
        self.UItrackerid.text = [Settings stringForKey:@"trackerid_preference"];
    } else if (alertView == self.modeAlertView) {
        if (buttonIndex > 0) {
            if (self.UImode) {
                switch (self.UImode.selectedSegmentIndex) {
                    case 2:
                        [Settings setInt:MODE_HTTP forKey:@"mode"];
                        break;
                    case 1:
                        [Settings setInt:MODE_PUBLIC forKey:@"mode"];
                        break;
                    case 0:
                    default:
                        [Settings setInt:MODE_PRIVATE forKey:@"mode"];
                        break;
                }
            }
            [self updated];
            [delegate terminateSession];
            [self updateValues];
            [delegate reconnect];
        } else {
            if (self.UImode) {
                switch ([Settings intForKey:@"mode"]) {
                    case MODE_HTTP:
                        self.UImode.selectedSegmentIndex = 2;
                        break;
                    case MODE_PUBLIC:
                        self.UImode.selectedSegmentIndex = 1;
                        break;
                    case MODE_PRIVATE:
                    default:
                        self.UImode.selectedSegmentIndex = 0;
                        break;
                }
            }
        }
    }
}

- (void)reconnect {
    OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate connectionOff];
    [[OwnTracking sharedInstance] syncProcessing];
    [self updateValues];
    [delegate reconnect];
}

- (IBAction)scan:(UIBarButtonItem *)sender {
    if ([QRCodeReader isAvailable]) {
        NSArray *types = @[AVMetadataObjectTypeQRCode];
        self.reader = [QRCodeReaderViewController readerWithMetadataObjectTypes:types];
        
        self.reader.modalPresentationStyle = UIModalPresentationFormSheet;
        
        self.reader.delegate = self;
        
        [self presentViewController:_reader animated:YES completion:NULL];
    } else {
        [AlertView alert:QRSCANNER
                 message:NSLocalizedString(@"App does not have access to camera",
                                           @"content of an alert message regarging QR code scanning")
         ];
    }
}


#pragma mark - QRCodeReader Delegate Methods

- (void)reader:(QRCodeReaderViewController *)reader didScanResult:(NSString *)result
{
    [self dismissViewControllerAnimated:YES completion:^{
        DDLogVerbose(@"result %@", result);
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        if ([delegate application:[UIApplication sharedApplication] openURL:[NSURL URLWithString:result] options:@{}]) {
            [AlertView alert:QRSCANNER
                     message:NSLocalizedString(@"QR code successfully processed!",
                                               @"content of an alert message regarging QR code scanning")
             ];
        } else {
            [AlertView alert:QRSCANNER
                     message:delegate.processingMessage
             ];
        }
        delegate.processingMessage = nil;
    }];
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
