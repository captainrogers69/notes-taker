import 'package:flutter/foundation.dart';

/// "this Mac" / "this PC" / "this phone" (03 prototype `here()`). Linux is
/// not prototyped; it reads "this PC".
String hereName([TargetPlatform? platform]) =>
    switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.macOS => 'this Mac',
      TargetPlatform.windows || TargetPlatform.linux => 'this PC',
      TargetPlatform.iOS ||
      TargetPlatform.android ||
      TargetPlatform.fuchsia => 'this phone',
    };

/// Whether shortcuts use ⌘ (Apple) rather than Ctrl.
bool usesCommandKey([TargetPlatform? platform]) =>
    switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };

/// The modifier as the 03 prototype prints it before a key: "⌘" or "Ctrl+"
/// (`mod()`), e.g. "⌘K" / "Ctrl+K".
String modifierLabel([TargetPlatform? platform]) =>
    usesCommandKey(platform) ? '⌘' : 'Ctrl+';
