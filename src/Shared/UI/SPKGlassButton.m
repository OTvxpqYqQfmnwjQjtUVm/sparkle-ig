#import "SPKGlassButton.h"
#import "../../Utils.h"

@interface SPKGlassButton () {
    BOOL _isGlass;
}
@end

@implementation SPKGlassButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        Class configClass = NSClassFromString(@"UIButtonConfiguration");
        SEL prominentGlassSel = NSSelectorFromString(@"prominentGlassButtonConfiguration");
        SEL filledSel = NSSelectorFromString(@"filledButtonConfiguration");
        
        id titleTransformer = ^(NSDictionary *incoming) {
            NSMutableDictionary *mut = [incoming mutableCopy] ?: [NSMutableDictionary dictionary];
            mut[NSFontAttributeName] = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
            return mut;
        };
        
        if (configClass && [configClass respondsToSelector:prominentGlassSel]) {
            _isGlass = YES;
            id config = ((id (*)(id, SEL))[configClass methodForSelector:prominentGlassSel])(configClass, prominentGlassSel);
            [config setValue:titleTransformer forKey:@"titleTextAttributesTransformer"];
            self.configuration = config;
        } else if (configClass && [configClass respondsToSelector:filledSel]) {
            _isGlass = NO;
            id config = ((id (*)(id, SEL))[configClass methodForSelector:filledSel])(configClass, filledSel);
            [config setValue:titleTransformer forKey:@"titleTextAttributesTransformer"];
            
            id backgroundConfig = [config valueForKey:@"background"];
            if (backgroundConfig) {
                [backgroundConfig setValue:@(25.0) forKey:@"cornerRadius"];
            }
            self.configuration = config;
        }
        
        [self applyColors];
    }
    return self;
}

- (void)applyColors {
    UIColor *baseColor = [SPKUtils SPKColor_InstagramPrimaryText];
    UIColor *textColor = [SPKUtils SPKColor_InstagramBackground];
    
    self.tintColor = baseColor;
    
    if (self.configuration && !_isGlass) {
        id config = self.configuration;
        [config setValue:baseColor forKey:@"baseBackgroundColor"];
        [config setValue:textColor forKey:@"baseForegroundColor"];
        self.configuration = config;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    [self applyColors];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (void)setText:(NSString *)text {
    if (self.configuration) {
        id config = self.configuration;
        [config setValue:text forKey:@"title"];
        self.configuration = config;
    } else {
        [self setTitle:text forState:UIControlStateNormal];
    }
}

- (void)setTextAnimated:(NSString *)text {
    NSString *currentTitle = nil;
    if (self.configuration) {
        currentTitle = [self.configuration valueForKey:@"title"];
    } else {
        currentTitle = [self titleForState:UIControlStateNormal];
    }
    
    if ([currentTitle isEqualToString:text])
        return;
    
    if (!currentTitle.length) {
        [self setText:text];
        return;
    }
    
    [UIView transitionWithView:self
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self setText:text];
                    }
                    completion:nil];
}

@end
