import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/utils/globals.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/models/post.dart';
import '../board_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/community_providers.dart';
import '../providers/watch_provider.dart';

class CreateScamReportScreen extends ConsumerStatefulWidget {
  const CreateScamReportScreen({super.key});

  @override
  ConsumerState<CreateScamReportScreen> createState() => _CreateScamReportScreenState();
}

class _CreateScamReportScreenState extends ConsumerState<CreateScamReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  final _lossItemController = TextEditingController();
  final _lossAmountController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  final List<Uint8List> _selectedImageBytes = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _lossItemController.dispose();
    _lossAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) return;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImages.add(file);
          _selectedImageBytes.add(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _selectedImageBytes.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages(String uid) async {
    final urls = <String>[];
    for (int i = 0; i < _selectedImages.length; i++) {
      final bytes = _selectedImageBytes[i];
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;
      
      final oriented = img.bakeOrientation(decoded);
      final resized = img.copyResize(oriented, width: oriented.width > 1200 ? 1200 : null);
      final finalBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
      
      final path = 'scams/$uid/${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.jpg';
      // Match storage rules path by using child('post-images/...')
      final ref = firebaseStorage.ref().child('post-images/$path');
      await ref.putData(finalBytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = ref.read(authProvider);
    if (auth.user == null || auth.user!.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must sign in or register to report a scam.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = auth.user!.uid;
      final imageLinks = await _uploadImages(uid);

      final title = sanitizeInput(_titleController.text);
      final desc = sanitizeInput(_descController.text);
      final name = sanitizeInput(_nameController.text);
      final company = sanitizeInput(_companyController.text);
      final phone = sanitizeInput(_phoneController.text);
      final email = sanitizeInput(_emailController.text);
      final location = sanitizeInput(_locationController.text);
      final lossItem = sanitizeInput(_lossItemController.text);
      final lossAmount = double.parse(_lossAmountController.text);

      final keywords = buildSearchKeywords(
        title: title,
        content: desc,
        name: name,
        email: email,
        phone: phone,
        company: company,
        lossItem: lossItem,
      );

      final docRef = firestore.collection('posts').doc();
      final Map<String, dynamic> data = {
        'id': docRef.id,
        'title': title,
        'content': desc,
        'category': 'Scams',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'comment_count': 0,
        'vote_count': 0,
        'thumbs_up_count': 0,
        'thumbs_down_count': 0,
        'partial_count': 0,
        'funny_count': 0,
        'user_id': uid,
        'is_anonymous': false,
        'author_username': auth.profile?.username ?? 'Verified Farmer',
        'author_verified': true,
        'is_deleted': false,
        'image_urls': imageLinks,
        'image_url': imageLinks.isNotEmpty ? imageLinks.first : null,
        
        // Scam Fields
        'scammer_name': name,
        'scammer_company': company,
        'scammer_phone': phone,
        'scammer_email': email,
        'scam_location': location,
        'loss_item': lossItem,
        'loss_amount': lossAmount,
        'search_keywords': keywords,
      };

      await firestore.runTransaction((transaction) async {
        transaction.set(docRef, data);
        final statsRef = firestore.collection('stats').doc('global');
        transaction.set(statsRef, {'total_posts': FieldValue.increment(1)}, SetOptions(merge: true));
      });

      // Track watch list
      await ref.read(watchedThreadsProvider.notifier).watch(Post.fromMap({
        ...data,
        'created_at': DateTime.now().toIso8601String(),
      }));

      // Add reputation points
      await ref.read(authProvider.notifier).addReputationPoints(5, 'post');

      // Refresh post feeds
      final currentCategories =
          ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scam report published successfully. (+5 Rep)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<String> buildSearchKeywords({
    required String title,
    required String content,
    required String name,
    String? email,
    String? phone,
    String? company,
    required String lossItem,
  }) {
    final Set<String> keywords = {};
    void addTokens(String? text) {
      if (text == null || text.trim().isEmpty) return;
      final cleaned = text.toLowerCase().replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()??"'']'), ' ');
      for (final token in cleaned.split(RegExp(r'\s+'))) {
        final trimmed = token.trim();
        if (trimmed.length >= 2) {
          keywords.add(trimmed);
        }
      }
    }

    addTokens(title);
    addTokens(content);
    addTokens(name);
    addTokens(lossItem);
    if (company != null) addTokens(company);
    if (email != null && email.trim().isNotEmpty) {
      keywords.add(email.trim().toLowerCase());
    }
    if (phone != null && phone.trim().isNotEmpty) {
      keywords.add(phone.trim().toLowerCase());
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 7) {
        keywords.add(digits);
      }
    }
    return keywords.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardColors.prairie,
      appBar: AppBar(
        title: Text('File Scam Report', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: BoardColors.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: BoardColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: BoardColors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Report Title & Details'),
                    const SizedBox(height: 10),
                    _buildTextField(_titleController, 'Title', 'e.g. Non-payment for barley bales', required: true),
                    const SizedBox(height: 10),
                    _buildTextField(_descController, 'Detailed Description', 'Describe how the scam occurred...', maxLines: 5, required: true),
                    
                    const SizedBox(height: 20),
                    _buildSectionHeader('Accused Contact Details'),
                    const SizedBox(height: 10),
                    _buildTextField(_nameController, 'Scammer Name', 'Full Name of scammer', required: true),
                    const SizedBox(height: 10),
                    _buildTextField(_companyController, 'Company / Entity', 'Business name if applicable'),
                    const SizedBox(height: 10),
                    _buildTextField(_phoneController, 'Scammer Phone', 'Phone number if known'),
                    const SizedBox(height: 10),
                    _buildTextField(_emailController, 'Scammer Email', 'Email address if known'),
                    const SizedBox(height: 10),
                    _buildTextField(_locationController, 'Scam Location', 'City, Province/State where scam took place', required: true),
                    
                    const SizedBox(height: 20),
                    _buildSectionHeader('Loss Valuation'),
                    const SizedBox(height: 10),
                    _buildTextField(_lossItemController, 'Loss Item', 'What was stolen/unpaid? (e.g. Canola seed)', required: true),
                    const SizedBox(height: 10),
                    _buildTextField(_lossAmountController, 'Loss Amount ($ CAD)', 'Estimated monetary loss', keyboardType: TextInputType.number, required: true),
                    
                    const SizedBox(height: 20),
                    _buildSectionHeader('Upload Proof / Evidence'),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BoardColors.paper,
                        side: const BorderSide(color: BoardColors.line),
                      ),
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library, color: BoardColors.green),
                      label: Text('Attach Proof Image (${_selectedImages.length}/3)', style: const TextStyle(color: Colors.white)),
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: kIsWeb
                                        ? Image.memory(
                                            _selectedImageBytes[index],
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(_selectedImages[index].path),
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      color: Colors.black54,
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submitReport,
                        child: Text(
                          'Publish Scam Report',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: BoardColors.amber),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: BoardColors.muted),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: BoardColors.line), borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: BoardColors.green), borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: BoardColors.paper,
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return '$label is required';
        }
        if (required && keyboardType == TextInputType.number && double.tryParse(value!) == null) {
          return 'Please enter a valid amount';
        }
        return null;
      },
    );
  }
}
