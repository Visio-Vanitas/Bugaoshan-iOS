import 'dart:io';

import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/settings/add_widget/add_widget_page.dart';
import 'package:bugaoshan/pages/settings/set_dock_page.dart';
import 'package:bugaoshan/pages/settings/set_duration_page.dart';
import 'package:bugaoshan/pages/settings/set_language_page.dart';
import 'package:bugaoshan/pages/settings/set_course_style_page.dart';
import 'package:bugaoshan/pages/settings/set_theme_color_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class SoftwareSettingPage extends StatelessWidget {
  const SoftwareSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();

    return ListenableBuilder(
      listenable: Listenable.merge([appConfig.widgetShowTomorrow]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(localizations.softwareSetting)),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // General settings card
              InfoCard(
                children: [
                  IconTile(
                    icon: Icons.language,
                    label: localizations.modifyLanguage,
                    onTap: () => popupOrNavigate(context, SetLanguagePage()),
                  ),
                  IconTile(
                    icon: Icons.timer,
                    label: localizations.animationDuration,
                    onTap: () => popupOrNavigate(context, SetDurationPage()),
                  ),
                  IconTile(
                    icon: Icons.color_lens,
                    label: localizations.themeColor,
                    onTap: () => popupOrNavigate(context, SetThemeColorPage()),
                  ),
                  IconTile(
                    icon: Icons.dock_outlined,
                    label: localizations.customDock,
                    onTap: () => popupOrNavigate(context, const SetDockPage()),
                  ),
                  IconTile(
                    icon: Icons.style,
                    label: localizations.courseStyleSetting,
                    onTap: () =>
                        popupOrNavigate(context, const SetCourseStylePage()),
                  ),
                ],
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 12),
                // Widget settings card
                InfoCard(
                  children: [
                    IconTile(
                      icon: Icons.widgets_outlined,
                      label: localizations.addWidgetPageTitle,
                      onTap: () =>
                          popupOrNavigate(context, const AddWidgetPage()),
                    ),
                    BaseTile(
                      child: Row(
                        children: [
                          const TileIcon(icon: Icons.calendar_today_outlined),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              localizations.widgetShowTomorrowAfterEnd,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          Switch(
                            value: appConfig.widgetShowTomorrow.value,
                            onChanged: (v) async {
                              appConfig.widgetShowTomorrow.value = v;
                              final service = getIt<WidgetUpdateService>();
                              try {
                                await service.updateWidgetData(force: true);
                              } catch (e, st) {
                                debugPrint('WidgetUpdate toggle failed: $e');
                                debugPrint('$st');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Danger zone card
              InfoCard(
                children: [
                  IconTile(
                    icon: Icons.delete,
                    iconColor: Colors.red,
                    label: localizations.clearAllData,
                    labelColor: Colors.red,
                    onTap: () async {
                      final confirm = await showYesNoDialog(
                        title: localizations.clearAllData,
                        content: localizations.confirmMessage,
                      );
                      if (confirm == true) {
                        final scuAuth = getIt<ScuAuthProvider>();
                        await scuAuth.logout();
                        await scuAuth.clearCredentials();
                        await appConfig.clearAll();
                        final courseProvider = getIt<CourseProvider>();
                        await courseProvider.clearAllData();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
