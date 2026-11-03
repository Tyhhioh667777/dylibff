#import "icons.h"
#import <UIKit/UIKit.h>

// ============================================================
// _0xIC2872_.mm
// Chỉ hiển thị chữ "TIZ" — không ảnh, không Base64, không log
// ============================================================

UIImage *FloatButtonIcon(void) {
    static UIImage *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *text      = @"TIZ";
        UIFont   *font      = [UIFont boldSystemFontOfSize:14.0];
        UIColor  *textColor = UIColor.whiteColor;
        CGSize    size      = CGSizeMake(44.0, 44.0);

        UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
        fmt.opaque = NO;
        fmt.scale  = UIScreen.mainScreen.scale;

        UIGraphicsImageRenderer *renderer =
            [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];

        cached = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            NSDictionary *attrs = @{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: textColor
            };
            CGSize textSize = [text sizeWithAttributes:attrs];
            CGFloat x = (size.width  - textSize.width)  / 2.0f;
            CGFloat y = (size.height - textSize.height) / 2.0f;
            [text drawAtPoint:CGPointMake(roundf(x), roundf(y)) withAttributes:attrs];
        }];
    });
    return cached;
}
