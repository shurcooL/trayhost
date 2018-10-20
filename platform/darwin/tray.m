#import <Cocoa/Cocoa.h>

NSMenu * appMenu;
char * clipboardString;

extern void tray_callback(int itemId);
extern BOOL tray_enabled(int itemId);
extern void notification_callback();

@interface ManageHandler : NSObject<NSUserNotificationCenterDelegate>
- (void)manage:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification;
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification;
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification;
@end

ManageHandler * uncDelegate;

@implementation ManageHandler
- (void)manage:(id)sender {
    tray_callback([[sender representedObject] intValue]);
}
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    //NSLog(@"in tray.m validateMenuItem\n");
    return tray_enabled([[menuItem representedObject] intValue]);
}
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    NSLog(@"in tray.m shouldPresentNotification\n");
    return YES;
}
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    NSLog(@"in tray.m didActivateNotification\n");
    [center removeDeliveredNotification: notification];

    // Call the handler for notification activation.
    int notificationId = [[[notification userInfo] objectForKey:@"notificationId"] intValue];
    notification_callback(notificationId);
}
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification {
    NSLog(@"in tray.m didDeliverNotification\n");
    //[center removeDeliveredNotification: notification];

    NSTimeInterval timeout = [[[notification userInfo] objectForKey:@"timeout"] doubleValue];
    if (timeout > 0.0) {
        NSLog(@"starting timer (timeout = %f) for %p\n", timeout, notification);
        [NSTimer scheduledTimerWithTimeInterval:timeout
                                         target:uncDelegate
                                       selector:@selector(clearNotificationTimer:)
                                       userInfo:notification
                                        repeats:NO];
    }
}
- (void)clearNotificationTimer:(NSTimer *)timer {
    NSUserNotification * notification = [timer userInfo];
    NSLog(@"in clearNotificationTimer %p\n", notification);
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification: notification];
}
@end

void add_menu_item(int itemId, const char * title, int disabled) {
    NSString * manageTitle = [NSString stringWithUTF8String:title];
    NSMenuItem * menuItem = [[[NSMenuItem alloc] initWithTitle:manageTitle
                                action:@selector(manage:) keyEquivalent:@""]
                                autorelease];

    [menuItem setRepresentedObject:[NSNumber numberWithInt:itemId]];
    [menuItem setTarget:uncDelegate];
    [appMenu addItem:menuItem];
}

void clear_menu_items() {
    [appMenu removeAllItems];
}

void add_separator_item() {
    [appMenu addItem:[NSMenuItem separatorItem]];
}

void native_loop() {
    [NSApp run];
}

void exit_loop() {
    // Clear all notifications.
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];

    [NSApp stop:nil];
}

int init(const char * title, struct image img) {
    [NSAutoreleasePool new];

    [NSApplication sharedApplication];

    // This is needed to avoid having a dock icon (and entry in Cmd+Tab list).
    // [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    // However, it causes the tooltip to not appear. So LSUIElement should be used instead.

    appMenu = [[NSMenu new] autorelease];

    // Set self as NSUserNotificationCenter delegate.
    uncDelegate = [[ManageHandler alloc] init];
    NSLog(@"[NSUserNotificationCenter defaultUserNotificationCenter] -> %p", [NSUserNotificationCenter defaultUserNotificationCenter]);
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate: uncDelegate];

    // If we were opened from a user notification, do the corresponding action.
    /*{
        NSUserNotification * launchNotification = [[aNotification userInfo] objectForKey: NSApplicationLaunchUserNotificationKey];
        if (launchNotification)
            [self userNotificationCenter: nil didActivateNotification: launchNotification];
    }*/

    NSSize iconSize = NSMakeSize(16, 16);
    NSImage * icon = [[NSImage alloc] initWithSize:iconSize];
    NSData * iconData = [NSData dataWithBytes:img.bytes length:img.length];
    [icon addRepresentation:[NSBitmapImageRep imageRepWithData:iconData]];
    [icon setTemplate:YES];

    NSStatusItem * statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
    [statusItem setMenu:appMenu];
    [statusItem setImage:icon];
    [statusItem setHighlightMode:YES];
    [statusItem setToolTip:[NSString stringWithUTF8String:title]];

    return 0;
}

void set_clipboard_string(const char * string) {
    NSArray * types = [NSArray arrayWithObjects:NSPasteboardTypeString, nil];

    NSPasteboard * pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:types owner:nil];
    [pasteboard setString:[NSString stringWithUTF8String:string]
                  forType:NSPasteboardTypeString];
}

struct clipboard_content get_clipboard_content() {
    struct clipboard_content cc;
    cc.text = NULL;
    cc.image.kind = NULL;
    cc.image.bytes = NULL;
    cc.image.length = 0;
    cc.files.names = NULL;
    cc.files.count = 0;

    NSPasteboard * pasteboard = [NSPasteboard generalPasteboard];
    NSData * object = NULL;
    NSString * string = NULL;
    NSArray * filenames = NULL;

    if ([[pasteboard types] containsObject:NSFilenamesPboardType] &&
        (filenames = [pasteboard propertyListForType:NSFilenamesPboardType]) != NULL) {

        const int count = [filenames count];
        if (count) {
            NSEnumerator * e = [filenames objectEnumerator];
            char ** names = calloc(count, sizeof(char *));
            for (int i = 0; i < count; i++) {
                names[i] = strdup([[e nextObject] UTF8String]);
            }

            cc.files.names = (const char **)(names);
            cc.files.count = count;

            // TODO: Fix memory leak.
            /*for (i = 0; i < count; i++)
                free(names[i]);
            free(names);*/
        }
    } else if ([[pasteboard types] containsObject:NSPasteboardTypePNG] &&
        (object = [pasteboard dataForType:NSPasteboardTypePNG]) != NULL) {

        cc.image.kind = "png";
        cc.image.bytes = [object bytes];
        cc.image.length = [object length];
    } else if ([[pasteboard types] containsObject:NSPasteboardTypeTIFF] &&
        (object = [pasteboard dataForType:NSPasteboardTypeTIFF]) != NULL) {

        cc.image.kind = "tiff";
        cc.image.bytes = [object bytes];
        cc.image.length = [object length];
    } else if ([[pasteboard types] containsObject:NSPasteboardTypeString] &&
        (string = [pasteboard stringForType:NSPasteboardTypeString]) != NULL) {

        free(clipboardString); // Free previous string (noop first time this is called since the value is NULL).
        clipboardString = strdup([string UTF8String]);

        cc.text = clipboardString;
    }

    return cc;
}

void display_notification(int notificationId, const char * title, const char * body, struct image img, double timeout) {
    NSUserNotification * notification = [[NSUserNotification alloc] init];
    [notification setTitle: [NSString stringWithUTF8String:title]];
    [notification setInformativeText: [NSString stringWithUTF8String:body]];
    [notification setSoundName: NSUserNotificationDefaultSoundName];

    if (img.kind != NULL) {
        NSImage * image = [[NSImage alloc] initWithData:[NSData dataWithBytes:img.bytes length:img.length]];
        [notification setContentImage: image];
    }

    NSDictionary * dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithDouble:timeout],     @"timeout",
        [NSNumber numberWithInt:notificationId], @"notificationId",
        nil];
    [notification setUserInfo: dictionary];

    NSUserNotificationCenter * center = [NSUserNotificationCenter defaultUserNotificationCenter];
    [center deliverNotification: notification];
    //[center removeDeliveredNotification: notification];
}
