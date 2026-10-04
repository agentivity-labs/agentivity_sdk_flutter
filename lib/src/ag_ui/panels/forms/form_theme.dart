// ignore_for_file: deprecated_member_use_from_same_package
import '../../theme/ag_theme_data.dart';

/// Deprecated — use [AgThemeData] from `package:agentivity_sdk/agentivity_sdk.dart`.
///
/// [AgUiFormTheme] is now a type alias for [AgThemeData]. All HIL-form tokens
/// (card colour, title/description/field-label styles, approve/reject/submit
/// colours, border radius) are unified in [AgThemeData] with the `form` prefix.
@Deprecated('Use AgThemeData from agentivity_sdk.dart')
typedef AgUiFormTheme = AgThemeData;
