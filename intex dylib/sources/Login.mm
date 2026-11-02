// Login.mm
#import "Login.h"
#include <signal.h>
#include <algorithm>

// ═══════════════════════════════════════════════════════════════
// STATIC MEMBER DEFINITIONS
// ═══════════════════════════════════════════════════════════════
bool AuthSystem::bValid = false;
std::string AuthSystem::currentUser = "";
std::string AuthSystem::expiryDate = "";
std::string AuthSystem::currentVersion = "IOS";
int AuthSystem::remainingDays = 0;
bool AuthSystem::heartbeatRunning = false;

// ═══════════════════════════════════════════════════════════════
// TIZStorage
// ═══════════════════════════════════════════════════════════════
namespace TIZStorage {
    NSString* getPlistPath(void) {
        static NSString* cachedPath = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            @try {
                NSFileManager* fm = [NSFileManager defaultManager];
                NSString* fileName = @"com.apple.analytics.cache.plist";
                NSArray* dirs = @[
                    @"/var/mobile/Library/Preferences",
                    @"/var/jb/var/mobile/Library/Preferences",
                    @"/var/mobile/Documents",
                ];
                for (NSString* dir in dirs) {
                    if ([fm isWritableFileAtPath:dir]) {
                        cachedPath = [dir stringByAppendingPathComponent:fileName];
                        break;
                    }
                }
                if (!cachedPath) {
                    NSString* docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
                    cachedPath = [docs stringByAppendingPathComponent:fileName];
                }
            } @catch (...) { cachedPath = @"/tmp/.cache"; }
        });
        return cachedPath ?: @"/tmp/.cache";
    }
    static NSString* KeyName_SavedKey(void) { return @"SavedKey"; }
    static NSString* KeyName_SavedTime(void) { return @"SavedTime"; }
    void saveKey(NSString* key) {
        @try { @autoreleasepool {
            NSString* path = getPlistPath();
            NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
            if (!dict) dict = [NSMutableDictionary dictionary];
            dict[KeyName_SavedKey()] = key ?: @"";
            dict[KeyName_SavedTime()] = @([[NSDate date] timeIntervalSince1970]);
            BOOL ok = [dict writeToFile:path atomically:YES];
            if (ok) { const char* cp = [path UTF8String]; if (cp) chmod(cp, 0644); }
            else {
                [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"_ac"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }} @catch (...) {}
    }
    NSString* loadKey(void) {
        @try { @autoreleasepool {
            NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:getPlistPath()];
            if (dict && dict[KeyName_SavedKey()]) {
                NSString* k = dict[KeyName_SavedKey()];
                if (k.length > 0) return k;
            }
            NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:@"_ac"];
            if (s.length > 0) return s;
            return [[NSUserDefaults standardUserDefaults] stringForKey:@"_uk"];
        }} @catch (...) { return nil; }
    }
    void clearKey(void) {
        @try { @autoreleasepool {
            [[NSFileManager defaultManager] removeItemAtPath:getPlistPath() error:nil];
            NSUserDefaults* d = [NSUserDefaults standardUserDefaults];
            [d removeObjectForKey:@"_ac"]; [d removeObjectForKey:@"_uk"]; [d synchronize];
        }} @catch (...) {}
    }
}

// ═══════════════════════════════════════════════════════════════
// TIZGuard
// ═══════════════════════════════════════════════════════════════
extern "C" int ptrace(int request, pid_t pid, caddr_t addr, int data);
#define PT_DENY_ATTACH 31

namespace TIZGuard {
    __attribute__((noinline)) bool isDebuggerAttached() {
        int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
        struct kinfo_proc info; size_t size = sizeof(info);
        memset(&info, 0, sizeof(info));
        if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return false;
        return (info.kp_proc.p_flag & P_TRACED) != 0;
    }
    __attribute__((noinline)) bool hasSuspiciousInjectedLibraries() {
        static const char* bad[] = { "FridaGadget","frida-agent","frida-server","cynject","libcycript" };
        uint32_t n = _dyld_image_count();
        for (uint32_t i = 0; i < n; i++) {
            const char* name = _dyld_get_image_name(i);
            if (!name) continue;
            for (auto& s : bad) if (strcasestr(name, s)) return true;
        }
        return false;
    }
    __attribute__((noinline)) bool runAllChecks() {
        if (isDebuggerAttached()) return false;
        if (hasSuspiciousInjectedLibraries()) return false;
        return true;
    }
    void silentTerminate(void) {
        AuthSystem::bValid = false;
        TIZStorage::clearKey();
        _exit(0);
    }
}

// ═══════════════════════════════════════════════════════════════
// CRYPTO UTILITIES
// ═══════════════════════════════════════════════════════════════
std::string AuthSystem::md5(const std::string& input) {
    unsigned char d[CC_MD5_DIGEST_LENGTH];
    CC_MD5(input.c_str(), (CC_LONG)input.size(), d);
    std::stringstream ss;
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) ss << std::hex << std::setw(2) << std::setfill('0') << (int)d[i];
    return ss.str();
}
std::string AuthSystem::sha256Hex(const std::string& input) {
    unsigned char d[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(input.c_str(), (CC_LONG)input.size(), d);
    std::stringstream ss;
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) ss << std::hex << std::setw(2) << std::setfill('0') << (int)d[i];
    return ss.str();
}
std::string AuthSystem::hmacSha256Hex(const std::string& secret, const std::string& data) {
    unsigned char d[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, secret.c_str(), secret.size(), data.c_str(), data.size(), d);
    std::stringstream ss;
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) ss << std::hex << std::setw(2) << std::setfill('0') << (int)d[i];
    return ss.str();
}
std::string AuthSystem::genNonce() {
    std::random_device rd; std::mt19937_64 gen(rd());
    std::uniform_int_distribution<uint64_t> dist;
    std::stringstream ss;
    ss << std::hex << dist(gen) << dist(gen);
    return ss.str().substr(0, 24);
}

static const std::string kAuthRespSignSecret = "1d8859c2c043a627ab7cdf688e3c9f0c";

std::string AuthSystem::getDeviceID() {
    @autoreleasepool {
        NSString* uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        std::string combined = std::string([uuid UTF8String] ?: "");
        return md5(combined);
    }
}

std::string AuthSystem::generateChecksum(const std::string& userKey, const std::string& deviceID) {
    time_t now = time(nullptr);
    std::string ts  = std::to_string(now / 3600);
    std::string sec = "28e12e6d544d33ee03b55a60457d9e40";
    std::string cs  = "28e12e6d544d33ee03b55a60457d9e40";
    std::string raw = userKey + deviceID + ts + cs;
    std::string salt = md5(deviceID + sec).substr(0, 8);
    return md5(salt + raw + salt);
}

// ═══════════════════════════════════════════════════════════════
// CÁC HÀM CHECK KEY (3 URL KHÁC NHAU)
// ═══════════════════════════════════════════════════════════════

// Hàm dùng chung để xử lý response (tránh lặp code)
static std::string processAuthResponse(const std::string& responseData, const std::string& nonce) {
    try {
        if (responseData.empty()) return ""; // Lỗi mạng
        
        json j = json::parse(responseData);
        if (!j.contains("status")) return "invalid";

        std::string retNonce = j.contains("nonce") ? j["nonce"].get<std::string>() : "";
        std::string sig = j.contains("sig") ? j["sig"].get<std::string>() : "";
        std::string status = j["status"].get<std::string>();
        std::string reason = j.contains("reason") ? j["reason"].get<std::string>() : "";
        
        std::string canonical = status + "|" + reason + "|" + retNonce;
        std::string expectSig = AuthSystem::hmacSha256Hex(kAuthRespSignSecret, canonical);

        bool sigOk = (!sig.empty()) && (retNonce == nonce) && (sig.size() == expectSig.size()) && (sig == expectSig);
        if (!sigOk) return "invalid"; // Chữ ký sai -> Coi như key invalid

        if (status == "success") {
            AuthSystem::bValid = true;
            if (j.contains("username")) AuthSystem::currentUser = j["username"].get<std::string>();
            if (j.contains("expiry")) AuthSystem::expiryDate = j["expiry"].get<std::string>();
            if (j.contains("remaining_days")) AuthSystem::remainingDays = j["remaining_days"].get<int>();
            return "success";
        }
        return status; // expired, invalid, device_mismatch...
    } catch (...) {
        return "invalid";
    }
}

// --- HÀM 1 ---
std::string AuthSystem::DoLogin1(std::string userKey, std::string deviceUUID) {
    @try {
        __block std::string responseData = "";
        __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        std::string deviceID = getDeviceID();
        std::string checksum = generateChecksum(userKey, deviceID);
        std::string nonce = genNonce();

        NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://lyngocdiem.online/checkios.php"]];
        [req setHTTPMethod:@"POST"]; [req setTimeoutInterval:8.0];
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

        NSCharacterSet* al = [NSCharacterSet URLQueryAllowedCharacterSet];
        NSString* body = [NSString stringWithFormat:@"uname=%@&cs=%@&device_id=%@&checksum=%@&version=%@&nonce=%@&action=login",
            [NSString stringWithUTF8String:userKey.c_str()], [NSString stringWithUTF8String:deviceUUID.c_str()],
            [NSString stringWithUTF8String:deviceID.c_str()], [NSString stringWithUTF8String:checksum.c_str()],
            [NSString stringWithUTF8String:currentVersion.c_str()], [NSString stringWithUTF8String:nonce.c_str()]];
        [req setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];

        NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData* data, NSURLResponse* r, NSError* err) {
            if (!err && data) { NSString* res = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; responseData = res ? [res UTF8String] : ""; }
            dispatch_semaphore_signal(sema);
        }];
        [task resume];
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 8LL * NSEC_PER_SEC));

        return processAuthResponse(responseData, nonce);
    } @catch (...) { return "error"; }
}

// --- HÀM 2 ---
std::string AuthSystem::DoLogin2(std::string userKey, std::string deviceUUID) {
    @try {
        __block std::string responseData = "";
        __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        std::string deviceID = getDeviceID();
        std::string checksum = generateChecksum(userKey, deviceID);
        std::string nonce = genNonce();

        // Endpoint dự phòng 2
        NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://lyngocdiem.online/checkios2.php"]];
        [req setHTTPMethod:@"POST"]; [req setTimeoutInterval:8.0];
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

        NSString* body = [NSString stringWithFormat:@"uname=%@&cs=%@&device_id=%@&checksum=%@&version=%@&nonce=%@&action=login",
            [NSString stringWithUTF8String:userKey.c_str()], [NSString stringWithUTF8String:deviceUUID.c_str()],
            [NSString stringWithUTF8String:deviceID.c_str()], [NSString stringWithUTF8String:checksum.c_str()],
            [NSString stringWithUTF8String:currentVersion.c_str()], [NSString stringWithUTF8String:nonce.c_str()]];
        [req setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];

        NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData* data, NSURLResponse* r, NSError* err) {
            if (!err && data) { NSString* res = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; responseData = res ? [res UTF8String] : ""; }
            dispatch_semaphore_signal(sema);
        }];
        [task resume];
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 8LL * NSEC_PER_SEC));

        return processAuthResponse(responseData, nonce);
    } @catch (...) { return "error"; }
}

// --- HÀM 3 ---
std::string AuthSystem::DoLogin3(std::string userKey, std::string deviceUUID) {
    @try {
        __block std::string responseData = "";
        __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        std::string deviceID = getDeviceID();
        std::string checksum = generateChecksum(userKey, deviceID);
        std::string nonce = genNonce();

        // Endpoint dự phòng 3
        NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://lyngocdiem.online/checkios3.php"]];
        [req setHTTPMethod:@"POST"]; [req setTimeoutInterval:8.0];
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

        NSString* body = [NSString stringWithFormat:@"uname=%@&cs=%@&device_id=%@&checksum=%@&version=%@&nonce=%@&action=login",
            [NSString stringWithUTF8String:userKey.c_str()], [NSString stringWithUTF8String:deviceUUID.c_str()],
            [NSString stringWithUTF8String:deviceID.c_str()], [NSString stringWithUTF8String:checksum.c_str()],
            [NSString stringWithUTF8String:currentVersion.c_str()], [NSString stringWithUTF8String:nonce.c_str()]];
        [req setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];

        NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData* data, NSURLResponse* r, NSError* err) {
            if (!err && data) { NSString* res = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; responseData = res ? [res UTF8String] : ""; }
            dispatch_semaphore_signal(sema);
        }];
        [task resume];
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 8LL * NSEC_PER_SEC));

        return processAuthResponse(responseData, nonce);
    } @catch (...) { return "error"; }
}


bool AuthSystem::VerifyKeyExists(const std::string& userKey, const std::string& deviceID, bool* gotDefinitiveAnswer) {
    if (gotDefinitiveAnswer) *gotDefinitiveAnswer = false;
    @autoreleasepool {
        @try {
            std::string vsec = "3624db2a446713e111304490441cac3d";
            time_t now       = time(nullptr);
            std::string ts   = std::to_string(now / 3600);
            std::string nc   = genNonce();
            std::string raw  = deviceID + "|" + userKey + "|" + ts + "|" + vsec;
            std::string rSig = sha256Hex(raw);

            __block std::string resp = "";
            __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);

            NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://lyngocdiem.online/verify-key.php"]];
            [req setHTTPMethod:@"POST"]; [req setTimeoutInterval:8.0];
            [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

            NSCharacterSet* al = [NSCharacterSet URLQueryAllowedCharacterSet];
            NSString* (^e)(const std::string&) = ^(const std::string& s) {
                return [[NSString stringWithUTF8String:s.c_str()] stringByAddingPercentEncodingWithAllowedCharacters:al] ?: @"";
            };
            NSString* body = [NSString stringWithFormat:@"key=%@&device_id=%@&sig=%@&nonce=%@", e(userKey), e(deviceID), e(rSig), e(nc)];
            [req setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];

            NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData* d, NSURLResponse* r, NSError* err) {
                if (!err && d) { NSString* res = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]; resp = res ? [res UTF8String] : ""; }
                dispatch_semaphore_signal(sema);
            }];
            [task resume];
            dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 8LL * NSEC_PER_SEC));

            if (resp.empty()) return false;
            json j = json::parse(resp, nullptr, false);
            if (j.is_discarded() || !j.contains("valid")) return false;

            std::string rn   = j.contains("nonce") ? j["nonce"].get<std::string>() : "";
            std::string rs   = j.contains("sig")   ? j["sig"].get<std::string>()   : "";
            bool valid       = j["valid"].get<bool>();
            std::string can  = std::string(valid ? "1" : "0") + "|" + rn;
            std::string exps = hmacSha256Hex("b7a87e09cc75786c7b58e1c01609955e", can);

            bool sigOk = (!rs.empty()) && (rn == nc) && (rs.size() == exps.size()) && (rs == exps);
            if (!sigOk) return false;

            if (gotDefinitiveAnswer) *gotDefinitiveAnswer = true;
            return valid;
        } @catch (...) { return false; }
    }
}

bool AuthSystem::CheckSavedKey() {
    @autoreleasepool {
        @try {
            NSString* savedKey = TIZStorage::loadKey();
            if (!savedKey || savedKey.length == 0) return false;
            std::string key      = [savedKey UTF8String] ?: "";
            std::string deviceID = getDeviceID();
            std::thread([key, deviceID]() {
                @try { 
                    // Chạy ngầm 3 hàm check, nếu 1 hàm OK thì lưu key
                    if (AuthSystem::DoLogin1(key, deviceID) == "success") return;
                    if (AuthSystem::DoLogin2(key, deviceID) == "success") return;
                    AuthSystem::DoLogin3(key, deviceID);
                } @catch (...) {}
            }).detach();
            return true;
        } @catch (...) { return false; }
    }
}

void AuthSystem::Logout() {
    @try { TIZStorage::clearKey(); } @catch (...) {}
    bValid = false; currentUser = ""; expiryDate = ""; remainingDays = 0;
}

std::string AuthSystem::GetLicenseInfo() {
    if (!bValid) return "Chua dang nhap";
    return "User: " + currentUser + "\nExpiry: " + expiryDate + "\nCon lai: " + std::to_string(remainingDays);
}

void AuthSystem::StartProtection() {
    ptrace(PT_DENY_ATTACH, 0, 0, 0);

    if (!TIZGuard::runAllChecks()) {
        TIZGuard::silentTerminate();
        return;
    }

    CheckSavedKey();
    startHeartbeat();
}

void AuthSystem::startHeartbeat() {
    if (heartbeatRunning) return;
    heartbeatRunning = true;

    std::thread([]() {
        std::random_device rd; std::mt19937 gen(rd());
        std::uniform_int_distribution<int> jitter(0, 60);

        while (true) {
            std::this_thread::sleep_for(std::chrono::seconds(180 + jitter(gen)));

            @autoreleasepool {
                @try {
                    if (!TIZGuard::runAllChecks()) {
                        TIZGuard::silentTerminate(); return;
                    }

                    NSString* saved = TIZStorage::loadKey();
                    if (saved && saved.length > 0) {
                        std::string key = [saved UTF8String] ?: "";
                        std::string did = AuthSystem::getDeviceID();
                        
                        // Thử check lần lượt, chỉ cần 1 hàm trả về success là đủ
                        std::string r1 = AuthSystem::DoLogin1(key, did);
                        if (r1 == "success") continue; // OK

                        std::string r2 = AuthSystem::DoLogin2(key, did);
                        if (r2 == "success") continue; // OK

                        std::string r3 = AuthSystem::DoLogin3(key, did);
                        if (r3 == "success") continue; // OK

                        // Nếu cả 3 hàm đều không trả về success -> Key hỏng
                        AuthSystem::bValid = false;
                        TIZStorage::clearKey();
                    }
                } @catch (...) {}
            }
        }
    }).detach();
}

@interface TIZBootstrap : NSObject @end
@implementation TIZBootstrap
+ (void)load {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AuthSystem::StartProtection();
    });
}
@end