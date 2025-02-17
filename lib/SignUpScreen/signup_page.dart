import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../HomeScreen/home_page.dart';
import '../LoginScreen/login_page.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _categories = ["Admin", "Farmer", "Vendor"];
  String? _selectedUserCategory;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _selectedUserCategory = _categories.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Check if the mobile number is already registered
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('mobile', isEqualTo: _mobileController.text.trim())
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _showErrorDialog(
            "This mobile number is already registered. Please log in.");
        setState(() => _isLoading = false);
        return;
      }

      // Proceed with registration if mobile number is unique
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'email': _emailController.text.trim(),
        'category': _selectedUserCategory,
      });

      // Navigate to HomePage after successful registration
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showErrorDialog("This email is already registered. Please log in.");
      } else {
        _showErrorDialog("Registration failed: ${e.message}");
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled sign-in

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
        (route) => false,
      );
    } catch (e) {
      _showErrorDialog("Google sign-in failed: ${e.toString()}");
    }
  }

  Future<void> _signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        final AuthCredential credential =
            FacebookAuthProvider.credential(result.accessToken!.token);

        await FirebaseAuth.instance.signInWithCredential(credential);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
          (route) => false,
        );
      } else {
        _showErrorDialog("Facebook sign-in failed: ${result.message}");
      }
    } catch (e) {
      _showErrorDialog("Facebook sign-in failed: ${e.toString()}");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              if (message.contains("already registered")) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // Center the header
        title: const Text(
          "Sign Up",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildDropdown(),
                const SizedBox(height: 5),
                _buildTextField(_nameController, Icons.person, "Name",
                    (val) => val!.isEmpty ? 'Enter name' : null),
                const SizedBox(height: 5),
                _buildTextField(
                    _mobileController,
                    Icons.phone,
                    "Mobile",
                    (val) => val!.length != 10 ? 'Enter 10-digit number' : null,
                    TextInputType.phone),
                const SizedBox(height: 5),
                _buildTextField(_emailController, Icons.email, "Email",
                    _validateEmail, TextInputType.emailAddress),
                const SizedBox(height: 5),
                _buildPasswordField(_passwordController, "Password", false),
                const SizedBox(height: 5),
                _buildPasswordField(
                    _confirmPasswordController, "Confirm Password", true),
                const SizedBox(height: 20),
                _isLoading ? CircularProgressIndicator() : _buildSignUpButton(),
                const SizedBox(height: 20),
                _buildSocialLoginButtons(),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => LoginPage())),
                  child: RichText(
                    text: const TextSpan(
                      text: "Already have an account? ",
                      style: TextStyle(color: Colors.black),
                      children: [
                        TextSpan(
                          text: "Log in",
                          style: TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedUserCategory,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        labelText: "Select Category",
        fillColor: Colors.white, // Set background color to white
        filled: true, // Enable background color
      ),
      items: _categories
          .map((category) =>
              DropdownMenuItem(value: category, child: Text(category)))
          .toList(),
      onChanged: (value) => setState(() => _selectedUserCategory = value),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon,
      String hint, String? Function(String?)? validator,
      [TextInputType keyboardType = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          labelText: hint,
          fillColor: Colors.white, // Set background color to white
          filled: true, // Enable background color
        ),
        validator: validator,
      ),
    );
  }

  // Widget _buildPasswordField(TextEditingController controller, String hint) {
  //   return _buildTextField(controller, Icons.lock, hint, _validatePassword);
  // }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: _registerUser,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 145),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      child:
          Text("Sign Up", style: TextStyle(fontSize: 18, color: Colors.white)),
    );
  }

  Widget _buildSocialLoginButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _signInWithGoogle, // ✅ Call the Google sign-in function
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          icon: Icon(Icons.login, color: Colors.white),
          label: Text("Google", style: TextStyle(color: Colors.white)),
        ),
        SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed:
              _signInWithFacebook, // ✅ Call the Facebook sign-in function
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          icon: Icon(Icons.facebook, color: Colors.white),
          label: Text("Facebook", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
      TextEditingController controller, String hint, bool isConfirm) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText:
            isConfirm ? !_isConfirmPasswordVisible : !_isPasswordVisible,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          labelText: hint,
          fillColor: Colors.white,
          filled: true,
          suffixIcon: IconButton(
            icon: Icon(
              isConfirm
                  ? (_isConfirmPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off)
                  : (_isPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
            ),
            onPressed: () {
              setState(() {
                if (isConfirm) {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                } else {
                  _isPasswordVisible = !_isPasswordVisible;
                }
              });
            },
          ),
        ),
        validator: _validatePassword,
      ),
    );
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Enter email';
    String pattern = r'^[^@]+@[^@]+\.[^@]+';
    if (!RegExp(pattern).hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    if (!RegExp(r'^(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'Include at least 1 uppercase letter & 1 number';
    }
    return null;
  }
}
