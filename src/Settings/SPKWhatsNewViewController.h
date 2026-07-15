#import "../Shared/UI/SPKPagedSheetViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// A two-page release-notes sheet shown once after upgrading to a new Sparkle
/// version: the first page lists the release's new features, the second its fixes
/// and improvements. A thin subclass of `SPKPagedSheetViewController`; present it
/// with `+presentFromViewController:onFinish:` and stamp `app_last_whatsnew_version`
/// from the `onFinish` block.
@interface SPKWhatsNewViewController : SPKPagedSheetViewController
@end

NS_ASSUME_NONNULL_END
