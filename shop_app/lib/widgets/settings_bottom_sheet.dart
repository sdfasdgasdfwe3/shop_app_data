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

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Настройки',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Отправлять без цены и баллов',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: const Text(
                            'Скрывать стоимость и баллы при отправке описания товара',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: currentHide,
                          activeThumbColor: Colors.green,
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
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          title: const Text(
                            'Отправлять с розничной ценой',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: const Text(
                            'При отправке указывать розничную цену вместо партнерской',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: currentRetail,
                          activeThumbColor: Colors.green,
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
