import 'package:flutter/material.dart';
import 'profile_selection_screen.dart';
import '../widgets/onboarding_content.dart'; // Make sure this import is correct

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> pages = [
    {
      'image': 'lib/assets/images/teleneuro.png',
      'title': 'Welcome to TeleNeuro',
      'description': 'Quality healthcare at the comfort of your Home',
      'showSkip': true,
      'button': null,
      'link': null,
    },
    {
      'image': 'lib/assets/images/companion.png',
      'title': 'Your personalized Healthcare companion',
      'description': 'Book appointments, Consult with doctors and manage your health journey effortlessly',
      'showSkip': true,
      'button': null,
      'link': null,
    },
    {
      'image': 'lib/assets/images/consult.png',
      'title': 'Multiple Consultation Options',
      'description': 'Connect with Healthcare Professionals through Video Calls, Phone Calls, or In-Person Visits - Your Choice, Your Comfort',
      'showSkip': true,
      'button': null,
      'link': null,
    },
    {
      'image': 'lib/assets/images/community .png',
      'title': 'Join Our Community',
      'description': 'Register as a Client, Doctor, Today and Be a Part of the TeleNeuro Family!',
      'showSkip': false,
      'button': {
        'text': 'Get Started',
        'onTap': () {
          // Replace with your navigation logic to login/signup
          print("Get Started clicked");
        },
      },
      'link': {
        'text': 'Log In',
        'onTap': () {
          // Replace with your navigation logic to login
          print("Log In clicked");
        },
      },
    },
    {
      'image': 'lib/assets/images/started.png',
      'title': 'Let\'s Get Started',
      'description': null,
      'showSkip': false,
      'button': {
        'text': 'Login',
        'onTap': () {
          // Replace with your navigation logic to login
          print("Login clicked");
        },
      },
      'secondaryButton': {
        'text': 'Sign Up',
        'onTap': () {
          // Replace with your navigation logic to sign up
          print("Sign Up clicked");
        },
      },
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final page = pages[index];
              return OnboardingContent(
                image : page['image'] ?? 'lib/assets/images/default.png', // Provide a default image if null
                title: page['title'],
                description: page['description'] ?? '',
              );
            },
          ),
          if (pages[_currentIndex]['showSkip'])
            Positioned(
              bottom: 20,
              left: 20,
              child: TextButton(
                onPressed: () {
                  _controller.jumpToPage(pages.length - 1);
                },
                child: Text(
                  'Skip',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            right: 20,
            child: IconButton(
              onPressed: () {
                if (_currentIndex < pages.length - 1) {
                  _controller.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeIn,
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ProfileSelectionScreen()),
                  );
                }
              },
              icon: Icon(
                Icons.arrow_forward,
                color: Colors.blue[600], // color for the forward icon
              ),
            ),
          ),
        ],
      ),
    );
  }
}