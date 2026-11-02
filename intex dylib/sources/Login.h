// Login.h
#ifndef LOGIN_H
#define LOGIN_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <Security/Security.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <dlfcn.h>

#include <string>
#include <thread>
#include <chrono>
#include <sstream>
#include <iomanip>
#include <random>
#include <ctime>

#include "json.hpp"
using json = nlohmann::ordered_json;

// ═══════════════════════════════════════════════════════════════
// TIZStorage — CHỈ KHAI BÁO
// ═══════════════════════════════════════════════════════════════
namespace TIZStorage {
    NSString* getPlistPath(void);
    void saveKey(NSString* key);
    NSString* loadKey(void);
    void clearKey(void);
}

// ═══════════════════════════════════════════════════════════════
// TIZGuard — kiểm tra môi trường
// ═══════════════════════════════════════════════════════════════
namespace TIZGuard {
    bool isDebuggerAttached();
    bool hasSuspiciousInjectedLibraries();
    bool runAllChecks();
    void silentTerminate();
}

// ═══════════════════════════════════════════════════════════════
// AuthSystem — CHỈ KHAI BÁO
// ═══════════════════════════════════════════════════════════════
class AuthSystem {
public:
    static bool bValid;
    static std::string currentUser;
    static std::string expiryDate;
    static std::string currentVersion;
    static int remainingDays;

    static std::string md5(const std::string& input);
    static std::string sha256Hex(const std::string& input);
    static std::string hmacSha256Hex(const std::string& secret, const std::string& data);
    static std::string genNonce();
    static std::string getDeviceID();
    static std::string generateChecksum(const std::string& userKey, const std::string& deviceID);

    // 3 hàm check với 3 URL khác nhau
    static std::string DoLogin1(std::string userKey, std::string deviceUUID);
    static std::string DoLogin2(std::string userKey, std::string deviceUUID);
    static std::string DoLogin3(std::string userKey, std::string deviceUUID);

    static bool VerifyKeyExists(const std::string& userKey, const std::string& deviceID, bool* gotDefinitiveAnswer = nullptr);
    static bool CheckSavedKey();
    static void Logout();
    static std::string GetLicenseInfo();
    static void StartProtection();

private:
    static void startHeartbeat();
    static bool heartbeatRunning;
};

#endif // LOGIN_H