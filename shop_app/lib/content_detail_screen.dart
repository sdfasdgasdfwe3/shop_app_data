import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';

class ContentDetailScreen extends StatelessWidget {
  final Article item;
  final String pageTitle;
  final String shareEmoji;
  final bool canDelete;
  final VoidCallback? onDelete;

  const ContentDetailScreen({
    super.key,
    required this.item,
    required this.pageTitle,
    required this.shareEmoji,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.image.isNotEmpty
        ? "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${item.image}"
        : "";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pageTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Удаление'),
                    content: const Text(
                      'Вы уверены, что хотите удалить эту запись?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx); // Закрываем диалог
                          Navigator.pop(context); // Закрываем экран статьи
                          if (onDelete != null) onDelete!();
                        },
                        child: const Text(
                          'Удалить',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final shareText = '$shareEmoji ${item.title}\n\n${item.content}';

              if (imageUrl.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Загрузка фото для отправки...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                try {
                  final response = await http.get(Uri.parse(imageUrl));
                  final tempDir = await getTemporaryDirectory();
                  final file = await File(
                    '${tempDir.path}/share_${item.image}',
                  ).create();
                  await file.writeAsBytes(response.bodyBytes);
                  await Share.shareXFiles([XFile(file.path)], text: shareText);
                } catch (e) {
                  Share.share('$shareText\n\n🖼️ Фото: $imageUrl');
                }
              } else {
                Share.share(shareText);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: 350,
                fit: BoxFit.cover, // Растягиваем на весь экран
                placeholder: (context, url) => const SizedBox(
                  height: 350,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  height: 350,
                  child: Icon(Icons.broken_image, size: 100),
                ),
              ),
            Container(
              transform: item.image.isNotEmpty
                  ? Matrix4.translationValues(0, -20, 0)
                  : null,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: item.image.isNotEmpty
                    ? const BorderRadius.vertical(top: Radius.circular(24))
                    : null,
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    item.content,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
