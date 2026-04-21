class AppData {
  final List<Product> products;
  final List<Article> articles;
  final List<String> categories;
  final List<Article> reviews;

  AppData({
    required this.products,
    required this.articles,
    required this.categories,
    required this.reviews,
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    var productsList = json['products'] as List? ?? [];
    var articlesList = json['articles'] as List? ?? [];
    var categoriesList = json['categories'] as List? ?? [];
    var reviewsList = json['reviews'] as List? ?? [];
    return AppData(
      products: productsList.map((i) => Product.fromJson(i)).toList(),
      articles: articlesList.map((i) => Article.fromJson(i)).toList(),
      categories: categoriesList.map((i) => i.toString()).toList(),
      reviews: reviewsList.map((i) => Article.fromJson(i)).toList(),
    );
  }
}

class Product {
  final int id;
  final String name;
  final String description;
  final String image;
  final int price;
  final int points;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    required this.points,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      image: json['image'],
      price: json['price'] ?? 0,
      points: json['points'] ?? json['price'] ?? 0, // Fallback на старую цену
      category: json['category'] ?? '',
    );
  }
}

class Article {
  final int id;
  final String title;
  final String content;
  final String image;

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.image,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      image: json['image'] ?? '',
    );
  }
}
