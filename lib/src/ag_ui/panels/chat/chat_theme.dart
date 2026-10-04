// ignore_for_file: deprecated_member_use_from_same_package
import '../../theme/ag_theme_data.dart';

/// Deprecated — use [AgThemeData] from `package:agentivity_sdk/agentivity_sdk.dart`.
///
/// [AgUiChatTheme] is now a type alias for [AgThemeData]. All chat-panel tokens
/// (bubble colours, input decoration, send-icon colour, font / spacing scales)
/// are unified in [AgThemeData] together with runnable, HIL, shell, and
/// assistant tokens.
@Deprecated('Use AgThemeData from agentivity_sdk.dart')
typedef AgUiChatTheme = AgThemeData;
