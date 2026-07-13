#import "SPKWhatsNewViewController.h"
#import "../Tweak.h"

@implementation SPKWhatsNewViewController

// Release notes are curated from the conventional-commit log for the release range
// (see whats-new.sh). Feature rows carry a per-surface IG catalog glyph; fix rows
// share the `subtract` bullet so they read as one clean list. Icon names are
// SPKAssetUtils override keys — never SF Symbols. Keep in sync with README/FEATURES.
- (NSArray<SPKPagedSheetPage *> *)buildPages {
    return @[
        [SPKPagedSheetPage pageWithTitle:@"New Features"
                                    body:[NSString stringWithFormat:@"What's new in %@", SPKVersionString]
                                    rows:@[
                                        @{ @"icon": @"action", @"text": @"Action button for media shared in chats" },
                                        @{ @"icon": @"clock", @"text": @"Last-active timestamps in chats with smart formatting" },
                                        @{ @"icon": @"eye", @"text": @"Auto-mark seen when you start typing" },
                                        @{ @"icon": @"sort", @"text": @"Choose where the Seen button sits, and nudge it aside to peek" },
                                        @{ @"icon": @"search", @"text": @"Search your story viewer list" },
                                        @{ @"icon": @"story_preview", @"text": @"Peek at stories without appearing on the viewer list" },
                                        @{ @"icon": @"feed", @"text": @"Feed header shortcut to Gallery, Profile Analyzer & more" },
                                        @{ @"icon": @"user_check", @"text": @"Subtle following indicator on profiles" },
                                        @{ @"icon": @"users", @"text": @"Clear visited profiles in Profile Analyzer" },
                                        @{ @"icon": @"info", @"text": @"Metadata overlay on expanded photos" },
                                        @{ @"icon": @"interface", @"text": @"Pill-shaped tab bar on iOS 18 and earlier" },
                                        @{ @"icon": @"haptics", @"text": @"Optional haptics when opening settings" },
                                        @{ @"icon": @"arrow_ccw", @"text": @"Reset any configurable settings group to its defaults" },
                                    ]],
        [SPKPagedSheetPage pageWithTitle:@"Fixes & Improvements"
                                    body:@""
                                    rows:@[
                                        @{ @"icon": @"subtract", @"text": @"Sharper video downloads on the default encoding preset" },
                                        @{ @"icon": @"subtract", @"text": @"Cleaned-up links no longer escape special characters" },
                                        @{ @"icon": @"subtract", @"text": @"No more duplicate comment-like confirmations" },
                                        @{ @"icon": @"subtract", @"text": @"Clearing download history reclaims its storage" },
                                        @{ @"icon": @"subtract", @"text": @"Action buttons & enhanced media resolution are now on by default" },
                                        @{ @"icon": @"subtract", @"text": @"TestFlight popup hidden by default" },
                                        @{ @"icon": @"subtract", @"text": @"Reset All Settings is now scoped per account" },
                                        @{ @"icon": @"subtract", @"text": @"Other bug fixes & UI improvements" },
                                    ]],
    ];
}

- (NSString *)finishButtonTitle {
    return @"Done";
}

- (BOOL)allowsInteractiveDismiss {
    return YES;
}

@end
