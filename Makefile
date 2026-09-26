export THEOS ?= $(HOME)/theos
export THEOS_PLATFORM_DEB_COMPRESSION_TYPE ?= gzip
export THEOS_PLATFORM_DEB_COMPRESSION_LEVEL ?= 9

XCTOOLCHAIN ?= /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
export TARGET_CC ?= $(XCTOOLCHAIN)/clang
export TARGET_CXX ?= $(XCTOOLCHAIN)/clang++
export TARGET_LD ?= $(XCTOOLCHAIN)/clang
export TARGET_STRIP ?= $(XCTOOLCHAIN)/strip
export TARGET_LIPO ?= $(XCTOOLCHAIN)/lipo
export TARGET_CODESIGN_ALLOCATE ?= $(XCTOOLCHAIN)/codesign_allocate
export TARGET_LIBTOOL ?= $(XCTOOLCHAIN)/libtool
export TARGET_DSYMUTIL ?= $(XCTOOLCHAIN)/dsymutil

INSTALL_TARGET_PROCESSES = SpringBoard

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
  ARCHS = arm64 arm64e
  TARGET = iphone:clang:latest:15.0
else ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
  ARCHS = arm64 arm64e
  TARGET = iphone:clang:latest:15.0
else
  ARCHS = arm64 arm64e
  TARGET = iphone:clang:latest:13.0
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OrientFlow

OrientFlow_FILES = Tweak.x src/OFPrefs.m src/OFButtonWindow.m
OrientFlow_CFLAGS = -fobjc-arc -Iinclude -Isrc -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations
OrientFlow_FRAMEWORKS = UIKit CoreGraphics QuartzCore AudioToolbox CoreMotion
include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "sbreload || killall -9 SpringBoard"
