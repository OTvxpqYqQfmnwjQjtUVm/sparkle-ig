#import "SPKOnboardingViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "../AssetUtils.h"
#import "../InstagramHeaders.h"
#import "../Shared/UI/SPKGlassButton.h"
#import "../Shared/UI/SPKBrandLogoView.h"
#import "../Utils.h"

// A single onboarding page's content.
@interface SPKOnboardingPage : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *body;
// Optional feature rows: each entry is @{ @"icon": ..., @"text": ... }.
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *features;
@end

@implementation SPKOnboardingPage
+ (instancetype)pageWithTitle:(NSString *)title
                         body:(NSString *)body
                     features:(NSArray<NSDictionary *> *)features {
    SPKOnboardingPage *page = [self new];
    page.title = title;
    page.body = body;
    page.features = features;
    return page;
}
@end

@interface SPKOnboardingHeroView : UIView
@property (nonatomic, strong) UIView *glowView;
@property (nonatomic, strong) SPKBrandLogoView *logoView;

- (void)setScrollProgress:(CGFloat)progress;
@end

@implementation SPKOnboardingHeroView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = NO;

        _glowView = [[UIView alloc] initWithFrame:self.bounds];
        _glowView.layer.cornerRadius = 26.0;
        _glowView.layer.cornerCurve = kCACornerCurveContinuous;
        _glowView.clipsToBounds = YES;
        _glowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_glowView];

        UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:_glowView.bounds];
        backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
        backgroundImageView.clipsToBounds = YES;

        UIImage *bgImage = [UIImage imageNamed:@"ig-gradient-background"];
        if (!bgImage) {
            NSString *frameworkPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks/FBSharedFramework.framework"];
            NSBundle *frameworkBundle = [NSBundle bundleWithPath:frameworkPath];
            bgImage = [UIImage imageNamed:@"ig-gradient-background" inBundle:frameworkBundle compatibleWithTraitCollection:nil];
        }

        if (bgImage) {
            // Flip/mirror the image horizontally to match the IG icon gradient layout
            UIImage *flippedImage = [UIImage imageWithCGImage:bgImage.CGImage scale:bgImage.scale orientation:UIImageOrientationUpMirrored];
            backgroundImageView.image = flippedImage;
        }
        [_glowView addSubview:backgroundImageView];

        _logoView = [[SPKBrandLogoView alloc] initWithFrame:self.bounds];
        _logoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_logoView];

        [self updateShadowForStyle:self.traitCollection.userInterfaceStyle];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
        [self updateShadowForStyle:self.traitCollection.userInterfaceStyle];
    }
}

- (void)updateShadowForStyle:(UIUserInterfaceStyle)style {
    if (style == UIUserInterfaceStyleDark) {
        self.layer.shadowColor = [UIColor colorWithRed:0.29 green:0.12 blue:0.62 alpha:0.45].CGColor;
        self.layer.shadowOpacity = 0.9;
        self.layer.shadowRadius = 20.0;
    } else {
        // Soft, elegant shadow for light mode
        self.layer.shadowColor = [UIColor colorWithRed:0.29 green:0.12 blue:0.62 alpha:0.25].CGColor;
        self.layer.shadowOpacity = 0.55;
        self.layer.shadowRadius = 14.0;
    }
}

- (void)setScrollProgress:(CGFloat)progress {
    CGFloat scale = 1.0;
    if (progress <= 1.0) {
        scale = 1.0 - progress * 0.18;
    } else {
        scale = 0.82 + (progress - 1.0) * 0.18;
    }
    self.transform = CGAffineTransformMakeScale(scale, scale);

    [self.logoView setScrollProgress:progress];
}

@end

@interface SPKOnboardingViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) NSArray<SPKOnboardingPage *> *pages;
@property (nonatomic, strong) SPKOnboardingHeroView *heroView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) SPKGlassButton *primaryButton;
@property (nonatomic, strong) UIButton *skipButton;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) BOOL didFinish;
@end

@implementation SPKOnboardingViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _pages = @[
            [SPKOnboardingPage pageWithTitle:@"Welcome to Sparkle"
                                        body:@"Everything you love about Instagram, with the controls it never gave you — built right in for a seamless experience."
                                    features:nil],
            [SPKOnboardingPage pageWithTitle:@"What you can do"
                                        body:@""
                                    features:@[
                                        @{ @"icon": @"download", @"text": @"Download anything in high quality" },
                                        @{ @"icon": @"sparkle_gallery", @"text": @"Save media to a private Gallery" },
                                        @{ @"icon": @"profile_analyzer", @"text": @"Track followers, unfollowers, and profile changes" },
                                        @{ @"icon": @"channels", @"text": @"Keep messages even after they're deleted" },
                                        @{ @"icon": @"eye", @"text": @"Control read receipts and typing status" },
                                        @{ @"icon": @"ads", @"text": @"Get rid of ads and annoyances" },
                                        @{ @"icon": @"", @"text": @"... and so much more!" },
                                    ]],
            [SPKOnboardingPage pageWithTitle:@"Find Sparkle anytime"
                                        body:@"You can open Sparkle settings anytime by:"
                                    features:@[
                                        @{ @"icon": @"settings_menu", @"text": @"Long pressing the menu on your profile" },
                                        @{ @"icon": @"home", @"text": @"Long pressing the Home tab" },
                                        @{ @"icon": @"action", @"text": @"Enabling the feed header button" },
                                    ]],
        ];
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        // Keep the intro deliberate — don't let a swipe-down skip the last page's hint.
        self.modalInPresentation = YES;
    }
    return self;
}

+ (void)presentFromViewController:(UIViewController *)presenter
                         onFinish:(void (^)(void))onFinish {
    if (!presenter)
        presenter = topMostController();
    if (!presenter || presenter.presentedViewController)
        return;

    SPKOnboardingViewController *onboarding = [[SPKOnboardingViewController alloc] init];
    onboarding.overrideUserInterfaceStyle = presenter.overrideUserInterfaceStyle;
    onboarding.onFinish = onFinish;
    [presenter presentViewController:onboarding animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SPKUtils SPKColor_InstagramGroupedBackground];

    self.heroView = [[SPKOnboardingHeroView alloc] initWithFrame:CGRectZero];
    self.heroView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.heroView];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = NO;
    self.scrollView.delegate = self;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.pageControl = [[UIPageControl alloc] init];
    self.pageControl.numberOfPages = (NSInteger)self.pages.count;
    self.pageControl.currentPage = 0;
    self.pageControl.currentPageIndicatorTintColor = [SPKUtils SPKColor_InstagramBlue];
    self.pageControl.pageIndicatorTintColor = [SPKUtils SPKColor_InstagramSeparator];
    self.pageControl.userInteractionEnabled = NO;
    self.pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.pageControl];

    self.primaryButton = [[SPKGlassButton alloc] initWithFrame:CGRectZero];
    self.primaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.primaryButton addTarget:self action:@selector(primaryTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.primaryButton];

    self.skipButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.skipButton setTitle:@"Skip" forState:UIControlStateNormal];
    [self.skipButton setTitleColor:[SPKUtils SPKColor_InstagramSecondaryText] forState:UIControlStateNormal];
    self.skipButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    self.skipButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.skipButton addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.skipButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.heroView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:24.0],
        [self.heroView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.heroView.widthAnchor constraintEqualToConstant:92.0],
        [self.heroView.heightAnchor constraintEqualToConstant:92.0],

        [self.scrollView.topAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:16.0],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.pageControl.topAnchor constant:-4.0],

        [self.pageControl.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.pageControl.bottomAnchor constraintEqualToAnchor:self.primaryButton.topAnchor constant:-8.0],

        [self.primaryButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24.0],
        [self.primaryButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24.0],
        [self.primaryButton.heightAnchor constraintEqualToConstant:50.0],

        // Skip sits directly beneath the primary CTA.
        [self.skipButton.topAnchor constraintEqualToAnchor:self.primaryButton.bottomAnchor constant:8.0],
        [self.skipButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.skipButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10.0],
        [self.skipButton.heightAnchor constraintEqualToConstant:32.0],
    ]];

    [self buildPages];
    [self updateControlsForPage:0];
}

- (void)buildPages {
    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.axis = UILayoutConstraintAxisHorizontal;
    hStack.distribution = UIStackViewDistributionFillEqually;
    hStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:hStack];

    [NSLayoutConstraint activateConstraints:@[
        [hStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [hStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [hStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [hStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [hStack.heightAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.heightAnchor],
    ]];

    for (SPKOnboardingPage *page in self.pages) {
        UIView *pageView = [self viewForPage:page];
        pageView.translatesAutoresizingMaskIntoConstraints = NO;
        [hStack addArrangedSubview:pageView];
        [pageView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor].active = YES;
    }
}

- (UIView *)viewForPage:(SPKOnboardingPage *)page {
    // Each page scrolls vertically: on small screens (e.g. iPhone SE/8) the hero +
    // title + a long feature list can exceed the fixed paging region, so the content
    // must scroll rather than be compressed or clipped. On tall screens it simply
    // sits at the top with room to spare and never needs to scroll.
    UIScrollView *container = [[UIScrollView alloc] init];
    container.showsVerticalScrollIndicator = NO;
    container.alwaysBounceVertical = NO;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 14.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = page.title;
    titleLabel.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    titleLabel.textColor = [SPKUtils SPKColor_InstagramPrimaryText];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [stack addArrangedSubview:titleLabel];

    // Only add the body label when there's copy — an empty label would otherwise
    // eat its spacing and leave a dead gap between the title and the feature list.
    UIView *lastHeaderView = titleLabel;
    if (page.body.length > 0) {
        UILabel *bodyLabel = [[UILabel alloc] init];
        bodyLabel.text = page.body;
        bodyLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
        bodyLabel.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
        bodyLabel.textAlignment = NSTextAlignmentCenter;
        bodyLabel.numberOfLines = 0;
        [stack setCustomSpacing:12.0 afterView:titleLabel];
        [stack addArrangedSubview:bodyLabel];
        lastHeaderView = bodyLabel;
    }

    if (page.features.count > 0) {
        UIStackView *featureStack = [[UIStackView alloc] init];
        featureStack.axis = UILayoutConstraintAxisVertical;
        featureStack.alignment = UIStackViewAlignmentLeading;
        featureStack.spacing = 14.0;
        for (NSDictionary *feature in page.features) {
            [featureStack addArrangedSubview:[self featureRowWithIcon:feature[@"icon"] text:feature[@"text"]]];
        }
        [stack addArrangedSubview:featureStack];
        [stack setCustomSpacing:24.0 afterView:lastHeaderView];
    }

    UILayoutGuide *content = container.contentLayoutGuide;
    UILayoutGuide *frame = container.frameLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        // Pin the stack to the scroll content so content height drives scrolling.
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:12.0],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16.0],
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:32.0],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-32.0],
        // Lock the content width to the frame so it only ever scrolls vertically.
        [stack.widthAnchor constraintEqualToAnchor:frame.widthAnchor constant:-64.0],
    ]];

    return container;
}

- (UIView *)featureRowWithIcon:(NSString *)iconName text:(NSString *)text {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12.0;

    // A row with no icon is a "closer" teaser (e.g. "…and so much more!") rather
    // than a concrete feature. Keep its text aligned under the other rows' labels
    // via an empty icon-width spacer, and give it an accented, italic treatment.
    BOOL isTeaser = (iconName.length == 0);

    // IG catalog glyphs are 24pt native, so render them at 24pt.
    static const CGFloat kIconSize = 24.0;

    if (isTeaser) {
        UIView *spacer = [[UIView alloc] init];
        spacer.translatesAutoresizingMaskIntoConstraints = NO;
        [spacer.widthAnchor constraintEqualToConstant:kIconSize].active = YES;
        [row addArrangedSubview:spacer];
    } else {
        // Load the pristine catalog image at its native size (pointSize 0 = no
        // rasterising downscale) — the same path menuIconNamed: relies on.
        // Forcing a smaller pointSize routes vector-backed (.svg) glyphs like
        // Profile Analyzer's trending_up_bars through a renderer downscale that
        // iOS 16 refuses to draw, leaving them blank.
        UIImage *iconImage = [SPKAssetUtils instagramIconNamed:iconName
                                                     pointSize:0
                                                        source:SPKAssetCatalogSourceAutomatic
                                                 renderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImageView *icon = [[UIImageView alloc] initWithImage:iconImage];
        icon.tintColor = [SPKUtils SPKColor_InstagramBlue];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [icon.widthAnchor constraintEqualToConstant:kIconSize].active = YES;
        [icon.heightAnchor constraintEqualToConstant:kIconSize].active = YES;
        [row addArrangedSubview:icon];
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.numberOfLines = 0;
    if (isTeaser) {
        UIFont *base = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
        UIFontDescriptor *italicDescriptor = [base.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
        label.font = italicDescriptor ? [UIFont fontWithDescriptor:italicDescriptor size:16.0] : base;
        label.textColor = [SPKUtils SPKColor_InstagramBlue];
    } else {
        label.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
        label.textColor = [SPKUtils SPKColor_InstagramPrimaryText];
    }
    [row addArrangedSubview:label];

    return row;
}

#pragma mark - Paging

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat width = scrollView.bounds.size.width;
    if (width > 0.0) {
        CGFloat progress = scrollView.contentOffset.x / width;
        [self.heroView setScrollProgress:progress];
    }

    if (scrollView.isDragging || scrollView.isDecelerating) {
        if (width <= 0.0)
            return;
        NSInteger page = (NSInteger)lround(scrollView.contentOffset.x / width);
        page = MAX(0, MIN(page, (NSInteger)self.pages.count - 1));
        if (page != self.currentPage)
            [self updateControlsForPage:page];
    }
}

- (void)updateControlsForPage:(NSInteger)page {
    self.currentPage = page;
    self.pageControl.currentPage = page;
    BOOL isLast = (page == (NSInteger)self.pages.count - 1);
    [self.primaryButton setTextAnimated:(isLast ? @"Get Started" : @"Continue")];
    self.skipButton.hidden = isLast;
}

- (void)primaryTapped {
    if (self.currentPage >= (NSInteger)self.pages.count - 1) {
        [self finish];
        return;
    }
    NSInteger next = self.currentPage + 1;
    [self updateControlsForPage:next];

    CGPoint offset = CGPointMake(self.scrollView.bounds.size.width * next, 0.0);
    [self.scrollView setContentOffset:offset animated:YES];
}

- (void)finish {
    if (self.didFinish)
        return;
    self.didFinish = YES;
    void (^completion)(void) = self.onFinish;
    [self dismissViewControllerAnimated:YES completion:^{
        if (completion)
            completion();
    }];
}

@end
