TARGET := iphone:clang
THEOS_PLATFORM_SDK_ROOT_armv6 = /Volumes/StuffUndso/Xcode/4.4.1/Xcode.app/Contents/Developer
SDKVERSION_armv6 = 5.1
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 9.0
ARCHS = armv6 armv7 arm64

TWEAK_NAME = Tactful
Tactful_FILES = Tweak.xm
Tactful_FRAMEWORKS = UIKit
Tactful_CFLAGS = -fobjc-arc
Tactful_LDFLAGS = -Wl,-segalign,4000

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Cydia SpringBoard"
