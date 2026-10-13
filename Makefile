TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FakeNFCFloat

FakeNFCFloat_FILES = Tweak.x FakeNFCViewController.m NFCMessageBuilder.m NFCInjector.m FakeNFCFloatManager.m FakeNDEFTag.m NFCTemplateManager.m NFCTagConfig.m NFCAdvancedConfigViewController.m
FakeNFCFloat_CFLAGS = -fobjc-arc
FakeNFCFloat_FRAMEWORKS = UIKit CoreGraphics CoreNFC Foundation

include $(THEOS_MAKE_PATH)/tweak.mk