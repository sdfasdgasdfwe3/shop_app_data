import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsBottomSheet {
  static void show({
    required BuildContext context,
    required bool hidePricePoints,
    required bool sendRetailPrice,
    required void Function(bool newHide, bool newRetail) onSettingsChanged,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool currentHide = hidePricePoints;
        bool currentRetail = sendRetailPrice;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
        final cardBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Настройки',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchListTile(
                          title: Text(
                            'Отправлять без цены и баллов',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            'Скрывать стоимость и баллы при отправке описания товара',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          value: currentHide,
                          activeThumbColor: Colors.white,
                          activeTrackColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                          onChanged: (bool value) async {
                            setModalState(() {
                              currentHide = value;
                              if (value) currentRetail = false;
                            });
                            onSettingsChanged(currentHide, currentRetail);
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('hide_price_points', currentHide);
                              if (value) await prefs.setBool('send_retail_price', false);
                            } catch (e) {
                              debugPrint('Ошибка сохранения настроек: $e');
                            }
                          },
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                        SwitchListTile(
                          title: Text(
                            'Отправлять с розничной ценой',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            'При отправке указывать розничную цену вместо партнерской',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          value: currentRetail,
                          activeThumbColor: Colors.white,
                          activeTrackColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                          onChanged: (bool value) async {
                            setModalState(() {
                              currentRetail = value;
                              if (value) currentHide = false;
                            });
                            onSettingsChanged(currentHide, currentRetail);
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('send_retail_price', currentRetail);
                              if (value) await prefs.setBool('hide_price_points', false);
                            } catch (e) {
                              debugPrint('Ошибка сохранения настроек: $e');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
