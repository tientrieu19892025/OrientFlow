ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
  ARCHS ?= arm64 arm64e
  TARGET ?= iphone:clang:latest:15.0
else ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
  ARCHS ?= arm64 arm64e
  TARGET ?= iphone:clang:latest:15.0
else
  ARCHS ?= arm64 arm64e
  TARGET ?= iphone:clang:latest:13.0
endif

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = OrientFlowPrefs

OrientFlowPrefs_FILES = OFRootListController.m ../src/OFPrefs.m
OrientFlowPrefs_FRAMEWORKS = UIKit CoreGraphics QuartzCore
OrientFlowPrefs_PRIVATE_FRAMEWORKS = Preferences
OrientFlowPrefs_LDFLAGS = -F$(THEOS_PROJECT_DIR)/stubs
OrientFlowPrefs_INSTALL_PATH = /Library/PreferenceBundles
OrientFlowPrefs_CFLAGS = -fobjc-arc -I../include -I../src -Wno-deprecated-declarations -Wno-unused-variable
OrientFlowPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
