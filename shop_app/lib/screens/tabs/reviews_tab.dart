import 'package:flutter/material.dart';
import '../../models.dart';
import '../../item_card.dart';
import '../../content_detail_screen.dart';
import '../../widgets/search_bar_widget.dart';

class ReviewsTab extends StatefulWidget {
  final List<Article> appReviews;
  final List<Article> userReviews;
  final String repoUrl;
  final bool isLoggedIn;
  final void Function(Article review) onDeleteReview;
  final Future<void> Function() onRefresh;

  const ReviewsTab({
    super.key,
    required this.appReviews,
    required this.userReviews,
    required this.repoUrl,
    required this.isLoggedIn,
    required this.onDeleteReview,
    required this.onRefresh,
  });

  @override
  State<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<ReviewsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final isQueryEmpty = query.isEmpty;
    var allReviews = [...widget.userReviews, ...widget.appReviews];
    var filteredReviews = isQueryEmpty
        ? allReviews
        : allReviews.where((r) {
            return r.title.toLowerCase().contains(query) ||
                r.content.toLowerCase().contains(query);
          }).toList();

    return Column(
      children: [
        SearchBarWidget(
          controller: _searchController,
          hintText: 'Поиск отзывов...',
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: filteredReviews.isEmpty
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
                                Icons.rate_review_outlined,
                                size: 32,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Отзывы не найдены',
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
                    itemCount: filteredReviews.length,
                    itemBuilder: (context, index) {
                      final review = filteredReviews[index];
                      final isUserAdded = widget.userReviews.any((e) => e.id == review.id);
                      final imageUrl = review.image.isNotEmpty
                          ? "${widget.repoUrl}/images/${review.image}"
                          : "";

                      return ItemCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContentDetailScreen(
                                item: review,
                                pageTitle: 'Отзыв',
                                shareEmoji: '',
                                canDelete: widget.isLoggedIn && isUserAdded,
                                onDelete: () => widget.onDeleteReview(review),
                              ),
                            ),
                          );
                        },
                        imageUrl: imageUrl,
                        placeholderIcon: Icons.rate_review,
                        title: review.title,
                        description: review.content,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
