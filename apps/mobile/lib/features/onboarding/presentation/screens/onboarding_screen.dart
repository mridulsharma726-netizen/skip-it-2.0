import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skipit/core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Rent anything nearby',
      'description': 'Find exactly what you need from people in your neighborhood.',
      'icon': 'search',
    },
    {
      'title': 'Earn from your items',
      'description': 'List your unused items and start making money today.',
      'icon': 'attach_money',
    },
    {
      'title': 'Premium & Secure',
      'description': 'Every rental is protected with secure payments and ID verification.',
      'icon': 'verified_user',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGlow.withValues(alpha: 0.2),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            _getIcon(_pages[index]['icon']!),
                            size: 60,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 60),
                        Text(
                          _pages[index]['title']!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _pages[index]['description']!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentIndex == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentIndex == _pages.length - 1) {
                        context.go('/login');
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Icon(
                      _currentIndex == _pages.length - 1
                          ? Icons.check
                          : Icons.arrow_forward,
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

  IconData _getIcon(String name) {
    switch (name) {
      case 'search':
        return Icons.search_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'verified_user':
        return Icons.verified_user_rounded;
      default:
        return Icons.star;
    }
  }
}
