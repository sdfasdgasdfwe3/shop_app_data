import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models.dart';
import '../../data_manager.dart';

class ProfileTab extends StatefulWidget {
  final bool isLoggedIn;
  final String currentUser;
  final AppData appData;
  final UserData userData;
  final DataManager dataManager;
  final String githubToken;
  final void Function(String username, bool rememberMe) onLogin;
  final void Function() onLogout;
  final void Function() onUserDataChanged;

  const ProfileTab({
    super.key,
    required this.isLoggedIn,
    required this.currentUser,
    required this.appData,
    required this.userData,
    required this.dataManager,
    required this.githubToken,
    required this.onLogin,
    required this.onLogout,
    required this.onUserDataChanged,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;

  String _adminAddType = 'Статья';
  final TextEditingController _adminTitleController = TextEditingController();
  final TextEditingController _adminContentController = TextEditingController();
  final TextEditingController _adminImageController = TextEditingController();
  Uint8List? _selectedImageBytes;
  bool _isPublishing = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _adminTitleController.dispose();
    _adminContentController.dispose();
    _adminImageController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final login = _loginController.text.trim();
    final pass = _passwordController.text.trim();
    if ((login == 'Иман' && pass == '01012026') ||
        (login == 'Альфред' && pass == '01012026') ||
        (login == 'Лола' && pass == '01012026') ||
        (login == 'Айшат' && pass == '01012026')) {
      widget.onLogin(login, _rememberMe);
      _loginController.clear();
      _passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Неверный логин или пароль'),
        ),
      );
    }
  }

  Future<void> _addNewContent() async {
    final title = _adminTitleController.text.trim();
    final content = _adminContentController.text.trim();
    String imageFileName = _adminImageController.text.trim();

    if (widget.githubToken.contains('ВАШ_ТОКЕН') ||
        widget.githubToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ошибка: Вставьте ваш реальный GitHub токен в код (main.dart)',
          ),
        ),
      );
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните заголовок')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      if (_selectedImageBytes != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Загрузка картинки на server...')),
        );
        imageFileName = 'user_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String? imgError = await widget.dataManager.uploadImageToGitHub(
          _selectedImageBytes!,
          imageFileName,
          widget.githubToken,
        );
        if (imgError != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $imgError')),
          );
          return;
        }
      }

      int newId = 1;
      final allItems = _adminAddType == 'Статья'
          ? [...widget.userData.articles, ...widget.appData.articles]
          : [...widget.userData.reviews, ...widget.appData.reviews];
      if (allItems.isNotEmpty) {
        newId = allItems.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
      }

      final newItem = Article(
        id: newId,
        title: title,
        content: content,
        image: imageFileName,
      );

      if (_adminAddType == 'Статья') {
        widget.userData.articles.insert(0, newItem);
      } else {
        widget.userData.reviews.insert(0, newItem);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сохранение и отправка на GitHub...')),
        );
      }

      await widget.dataManager.saveLocalUserData(widget.userData);

      _adminTitleController.clear();
      _adminContentController.clear();
      _adminImageController.clear();

      bool success = await widget.dataManager.uploadUserDataToGitHub(
        widget.userData,
        widget.githubToken,
      );

      widget.onUserDataChanged();

      if (!mounted) return;

      setState(() {
        _selectedImageBytes = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Успешно добавлено: $_adminAddType')),
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успешно опубликовано у всех: $_adminAddType'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка отправки на сервер! (Проверьте токен)'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoggedIn) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Авторизация',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _loginController,
                        decoration: const InputDecoration(
                          labelText: 'Логин',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (bool? value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                          const Text('Запомнить меня'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: _handleLogin,
                        child: const Text('Войти'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Привет, ${widget.currentUser}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: widget.onLogout,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Добавление контента',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _adminAddType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Тип контента',
            ),
            items: ['Статья', 'Отзыв'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() {
                  _adminAddType = newValue;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _adminTitleController,
            decoration: const InputDecoration(
              labelText: 'Заголовок',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _adminContentController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Текст (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _adminImageController,
            decoration: const InputDecoration(
              labelText: 'Имя файла картинки (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 70, // Сжимаем качество до 70%
                maxWidth: 1200, // Ограничиваем ширину (кроп)
              );
              if (pickedFile != null) {
                final bytes = await pickedFile.readAsBytes();
                setState(() {
                  _selectedImageBytes = bytes;
                  _adminImageController.clear();
                });
              }
            },
            icon: Icon(
              _selectedImageBytes != null ? Icons.check : Icons.photo_library,
            ),
            label: Text(
              _selectedImageBytes != null
                  ? 'Картинка выбрана'
                  : 'Выбрать из галереи',
            ),
          ),
          if (_selectedImageBytes != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Row(
                children: [
                  Image.memory(
                    _selectedImageBytes!,
                    height: 40,
                    width: 40,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Изображение прикреплено')),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() {
                      _selectedImageBytes = null;
                    }),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _isPublishing ? null : _addNewContent,
            child: _isPublishing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Опубликовать'),
          ),
          const SizedBox(height: 100), // Отступ для нижней панели
        ],
      ),
    );
  }
}
