import 'package:flutter/material.dart';
import '../../models.dart';
import '../../item_card.dart';
import '../../content_detail_screen.dart';
import '../../widgets/search_bar_widget.dart';

class ArticlesTab extends StatefulWidget {
  final List<Article> appArticles;
  final List<Article> userArticles;
  final String repoUrl;
  final bool isLoggedIn;
  final void Function(Article article) onDeleteArticle;
  final Future<void> Function() onRefresh;

  const ArticlesTab({
    super.key,
    required this.appArticles,
    required this.userArticles,
    required this.repoUrl,
    required this.isLoggedIn,
    required this.onDeleteArticle,
    required this.onRefresh,
  });

  @override
  State<ArticlesTab> createState() => _ArticlesTabState();
}

class _ArticlesTabState extends State<ArticlesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var allArticles = [...widget.userArticles, ...widget.appArticles];
    var filteredArticles = allArticles.where((a) {
      return a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        SearchBarWidget(
          controller: _searchController,
          hintText: 'Поиск статей...',
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: filteredArticles.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.article_outlined,
                                size: 32,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Статьи не найдены',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Попробуйте ввести другой поисковый запрос',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 120,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.54,
                    ),
                    itemCount: filteredArticles.length,
                    itemBuilder: (context, index) {
                      final article = filteredArticles[index];
                      final isUserAdded = widget.userArticles.any((e) => e.id == article.id);
                      final imageUrl = article.image.isNotEmpty
                          ? "${widget.repoUrl}/images/${article.image}"
                          : "";

                      return ItemCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContentDetailScreen(
                                item: article,
                                pageTitle: 'Статья',
                                shareEmoji: '📄',
                                canDelete: widget.isLoggedIn && isUserAdded,
                                onDelete: () => widget.onDeleteArticle(article),
                              ),
                            ),
                          );
                        },
                        imageUrl: imageUrl,
                        placeholderIcon: Icons.article,
                        title: article.title,
                        description: article.content,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
