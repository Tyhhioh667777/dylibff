#import "icons.h"
#import <UIKit/UIKit.h>

// ============================================================
// _0xIC2872_.mm
// 1) Nếu base64String hợp lệ → trả về ảnh từ Base64
// 2) Nếu base64String hỏng     → trả về ảnh chứa chữ "TIZ"
// Không log, không assert, UI dùng như cũ.
// ============================================================

#pragma mark - Decode Base64 an toàn

static UIImage *TIZDecodeBase64Image(NSString *b64) {
    if (!b64 || b64.length == 0) return nil;

    NSCharacterSet *allowed = [[NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="]
        invertedSet];
    NSString *clean = [[b64 componentsSeparatedByCharactersInSet:allowed]
                        componentsJoinedByString:@""];

    if (clean.length == 0) return nil;

    NSData *data = [[NSData alloc] initWithBase64EncodedString:clean
                                                       options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!data || data.length == 0) return nil;

    return [UIImage imageWithData:data];
}

#pragma mark - Render chữ "TIZ" thành UIImage

static UIImage *TIZRenderTextImage(NSString *text,
                                   CGFloat width,
                                   CGFloat height,
                                   UIFont *font,
                                   UIColor *textColor) {
    if (text.length == 0) text = @"TIZ";
    if (!font) font = [UIFont boldSystemFontOfSize:14.0];
    if (!textColor) textColor = UIColor.whiteColor;

    CGSize size = CGSizeMake(width > 0 ? width : 44.0,
                             height > 0 ? height : 44.0);

    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.opaque = NO;
    fmt.scale  = UIScreen.mainScreen.scale;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: textColor
        };
        CGSize textSize = [text sizeWithAttributes:attrs];
        CGFloat x = (size.width  - textSize.width)  / 2.0f;
        CGFloat y = (size.height - textSize.height) / 2.0f;
        [text drawAtPoint:CGPointMake(roundf(x), roundf(y)) withAttributes:attrs];
    }];
}

#pragma mark - Hàm chính

UIImage *FloatButtonIcon(void) {
    static UIImage *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{

        // ⚠️ THAY CHUỖI NÀY BẰNG BASE64 THẬT CỦA BẠN
        // (placeholder: PNG 1x1 trong suốt hợp lệ)
        static NSString *base64String =
            @"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
             "YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";

        // 1) Thử ảnh từ Base64
        cached = TIZDecodeBase64Image(base64String);

        // 2) Nếu hỏng → ảnh chữ "TIZ"
        if (!cached) {
            cached = TIZRenderTextImage(@"TIZ",
                                        44.0f,
                                        44.0f,
                                        [UIFont boldSystemFontOfSize:14.0f],
                                        UIColor.whiteColor);
        }
    });
    return cached;
}
