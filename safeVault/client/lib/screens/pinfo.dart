import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class PersonalInfoScreen extends StatefulWidget {
  static const routeName = '/personal-info';

  const PersonalInfoScreen({super.key});

  @override
  _PersonalInfoScreenState createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  User? _currentUser;
  String? _selectedGender;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _showPasswordFields = false;

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _addTextListeners();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      print('Loading user data...');
      final user = await AuthService.getUser();
      print('Loaded user data: ${user?.toJson()}');

      setState(() {
        _currentUser = user;
        _nameController.text = user?.name ?? '';
        _emailController.text = user?.email ?? '';
        _selectedGender = user?.gender;
        _isLoading = false;
      });

      print('User data loaded successfully');
      print('Current user ID: ${user?.id}');
      print('Current user name: ${user?.name}');
      print('Current user email: ${user?.email}');
      print('Current user gender: ${user?.gender}');
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    // Only validate fields that have been modified and have values
    bool isValid = true;

    final newName = _nameController.text.trim();
    if (newName != _currentUser?.name && newName.isNotEmpty) {
      if (newName.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Name must be at least 2 characters'),
            backgroundColor: Colors.red,
          ),
        );
        isValid = false;
      }
    }

    final newEmail = _emailController.text.trim();
    if (newEmail != _currentUser?.email && newEmail.isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(newEmail)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid email format'),
            backgroundColor: Colors.red,
          ),
        );
        isValid = false;
      }
    }

    if (_selectedGender != _currentUser?.gender &&
        _selectedGender != null &&
        _selectedGender!.isNotEmpty) {
      // Gender is valid if it's selected
    }

    if (_showPasswordFields && _newPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter your current password'),
            backgroundColor: Colors.red,
          ),
        );
        isValid = false;
      } else if (_newPasswordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New password must be at least 6 characters'),
            backgroundColor: Colors.red,
          ),
        );
        isValid = false;
      } else if (_newPasswordController.text !=
          _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red,
          ),
        );
        isValid = false;
      }
    }

    if (!isValid) return;

    final Map<String, dynamic> updateData = {};

    print('Current user data: ${_currentUser?.toJson()}');
    print(
        'Form data - Name: "${newName}", Email: "${newEmail}", Gender: "${_selectedGender}"');

    // Only add fields that have actually changed and have valid values
    if (newName != _currentUser?.name && newName.isNotEmpty) {
      updateData['name'] = newName;
      print('Adding name to update: $newName');
    }

    if (newEmail != _currentUser?.email && newEmail.isNotEmpty) {
      updateData['email'] = newEmail;
      print('Adding email to update: $newEmail');
    }

    // Handle gender field - only update if it's different and not empty
    if (_selectedGender != _currentUser?.gender) {
      if (_selectedGender != null && _selectedGender!.isNotEmpty) {
        updateData['gender'] = _selectedGender;
        print('Adding gender to update: $_selectedGender');
      } else if (_currentUser?.gender != null &&
          _currentUser!.gender!.isNotEmpty) {
        // If current user has gender but new selection is empty, don't update
        print('Skipping gender update - new value is empty');
      }
    }

    final bool hasPasswordChange =
        _showPasswordFields && _newPasswordController.text.isNotEmpty;

    print('Final update data: $updateData');
    print('Has password change: $hasPasswordChange');

    if (updateData.isEmpty && !hasPasswordChange) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No changes to update'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      if (updateData.isNotEmpty) {
        print('Sending update data: $updateData');
        await AuthService().updateProfile(updateData);

        final updatedUser = User(
          id: _currentUser!.id,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _currentUser!.role,
          gender: _selectedGender,
        );

        await AuthService.storeUser(updatedUser);

        setState(() {
          _currentUser = updatedUser;
        });
      }

      if (hasPasswordChange) {
        await AuthService().updatePassword(
          _currentPasswordController.text,
          _newPasswordController.text,
        );
      }

      setState(() {
        _isUpdating = false;
        _showPasswordFields = false;
      });

      _clearPasswordFields();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });

      String errorMessage = 'Failed to update profile';
      if (e.toString().contains('Email already exists')) {
        errorMessage = 'Email is already taken by another user';
      } else if (e.toString().contains('No valid fields to update')) {
        errorMessage = 'No changes detected to update';
      } else if (e.toString().contains('User not found')) {
        errorMessage = 'User session expired. Please login again.';
      } else if (e.toString().contains('Failed to update user profile')) {
        errorMessage = 'Server error. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearPasswordFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  void _togglePasswordFields() {
    setState(() {
      _showPasswordFields = !_showPasswordFields;
      if (!_showPasswordFields) {
        _clearPasswordFields();
      }
    });
    print('Password fields toggled: $_showPasswordFields');
    print('Has changes: ${_hasChanges()}');
  }

  bool _hasChanges() {
    if (_currentUser == null) return false;

    final nameChanged = _nameController.text.trim() != _currentUser!.name;
    final emailChanged = _emailController.text.trim() != _currentUser!.email;
    final genderChanged = _selectedGender != _currentUser!.gender;
    final passwordChanged =
        _showPasswordFields && _newPasswordController.text.isNotEmpty;

    print('=== CHANGE DETECTION ===');
    print(
        'Name changed: $nameChanged (${_currentUser!.name} -> ${_nameController.text.trim()})');
    print(
        'Email changed: $emailChanged (${_currentUser!.email} -> ${_emailController.text.trim()})');
    print(
        'Gender changed: $genderChanged (${_currentUser!.gender} -> $_selectedGender)');
    print('Password changed: $passwordChanged');
    print(
        'Total changes: ${nameChanged || emailChanged || genderChanged || passwordChanged}');
    print('=======================');

    return nameChanged || emailChanged || genderChanged || passwordChanged;
  }

  bool _isFieldModified(String fieldName) {
    switch (fieldName) {
      case 'name':
        return _nameController.text.trim() != _currentUser?.name;
      case 'email':
        return _emailController.text.trim() != _currentUser?.email;
      case 'gender':
        return _selectedGender != _currentUser?.gender;
      default:
        return false;
    }
  }

  void _addTextListeners() {
    _nameController.addListener(() {
      if (mounted) {
        setState(() {});
        print('Name changed to: ${_nameController.text}');
        print('Has changes: ${_hasChanges()}');
      }
    });
    _emailController.addListener(() {
      if (mounted) {
        setState(() {});
        print('Email changed to: ${_emailController.text}');
        print('Has changes: ${_hasChanges()}');
      }
    });
    _newPasswordController.addListener(() {
      if (mounted) {
        setState(() {});
        print('New password changed, has changes: ${_hasChanges()}');
      }
    });
  }

  void _resetChanges() {
    setState(() {
      _nameController.text = _currentUser?.name ?? '';
      _emailController.text = _currentUser?.email ?? '';
      _selectedGender = _currentUser?.gender;
      _showPasswordFields = false;
      _clearPasswordFields();
    });
  }

  @override
  Widget build(BuildContext context) {
    print('Building PersonalInfoScreen - hasChanges: ${_hasChanges()}');
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Personal Information'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      SizedBox(height: 24),
                      _buildBasicInfoSection(),
                      SizedBox(height: 24),
                      _buildPasswordSection(),
                      SizedBox(height: 32),
                      _buildUpdateButton(),
                      SizedBox(height: 16),
                      _buildResetButton(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue[100],
            child: Text(
              _currentUser?.firstNameInitial ?? 'U',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Edit Your Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _isFieldModified('name') ? Colors.orange : Colors.grey,
                  width: _isFieldModified('name') ? 2 : 1,
                ),
              ),
              prefixIcon: Icon(
                Icons.person,
                color: _isFieldModified('name') ? Colors.orange : Colors.grey,
              ),
              suffixIcon: _isFieldModified('name')
                  ? Icon(Icons.edit, color: Colors.orange, size: 16)
                  : null,
            ),
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color:
                      _isFieldModified('email') ? Colors.orange : Colors.grey,
                  width: _isFieldModified('email') ? 2 : 1,
                ),
              ),
              prefixIcon: Icon(
                Icons.email,
                color: _isFieldModified('email') ? Colors.orange : Colors.grey,
              ),
              suffixIcon: _isFieldModified('email')
                  ? Icon(Icons.edit, color: Colors.orange, size: 16)
                  : null,
            ),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color:
                      _isFieldModified('gender') ? Colors.orange : Colors.grey,
                  width: _isFieldModified('gender') ? 2 : 1,
                ),
              ),
              prefixIcon: Icon(
                Icons.person_outline,
                color: _isFieldModified('gender') ? Colors.orange : Colors.grey,
              ),
              suffixIcon: _isFieldModified('gender')
                  ? Icon(Icons.edit, color: Colors.orange, size: 16)
                  : null,
            ),
            items: _genderOptions.map((String gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedGender = newValue;
              });
              print('Gender changed to: $newValue');
              print('Current user gender: ${_currentUser?.gender}');
              print('Has changes: ${_hasChanges()}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton.icon(
                onPressed: _togglePasswordFields,
                icon: Icon(_showPasswordFields
                    ? Icons.visibility_off
                    : Icons.visibility),
                label: Text(_showPasswordFields ? 'Hide' : 'Change'),
              ),
            ],
          ),
          if (_showPasswordFields) ...[
            SizedBox(height: 20),
            TextFormField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    final bool hasChanges = _hasChanges();
    print('Building update button - hasChanges: $hasChanges');

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasChanges ? Colors.blue : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isUpdating
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                hasChanges ? 'Update Profile' : 'No Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildResetButton() {
    print('Building reset button');
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isUpdating ? null : _resetChanges,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.orange),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Reset Changes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ),
    );
  }
}
