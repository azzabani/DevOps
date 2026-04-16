// lib/views/admin/add_edit_resource_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_booking/models/resource_model.dart';
import 'package:flutter_booking/services/cloudinary_service.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';

class AddEditResourcePage extends StatefulWidget {
  final ResourceModel? resource;
  const AddEditResourcePage({super.key, this.resource});

  @override
  State<AddEditResourcePage> createState() => _AddEditResourcePageState();
}

class _AddEditResourcePageState extends State<AddEditResourcePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController        = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController    = TextEditingController();

  // Catégories normalisées en minuscules — correspond à ce qui est stocké dans Firestore
  static const _categories = ['salle', 'véhicule', 'ordinateur', 'matériel'];

  String _selectedCategory = 'salle';
  bool _isLoading         = false;
  bool _isUploadingImage  = false;

  Uint8List? _selectedImageBytes;
  String?    _selectedImageName;
  String?    _imageUrl;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  bool get _isEditing => widget.resource != null;

  String get _capacityLabel {
    switch (_selectedCategory) {
      case 'salle':    return 'Capacité (nombre de personnes)';
      case 'véhicule': return 'Capacité (nombre de places)';
      case 'ordinateur':
      case 'matériel': return 'Quantité disponible';
      default:         return 'Capacité / Quantité';
    }
  }

  IconData get _capacityIcon {
    switch (_selectedCategory) {
      case 'salle':
      case 'véhicule': return Icons.group_rounded;
      default:         return Icons.inventory_rounded;
    }
  }

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    if (_isEditing) {
      final r = widget.resource!;
      _nameController.text        = r.name;
      _descriptionController.text = r.description;
      _capacityController.text    = r.capacity.toString();
      // Normaliser la catégorie stockée (peut être 'Salle' ou 'salle')
      final cat = r.category.toLowerCase().trim();
      _selectedCategory = _categories.contains(cat) ? cat : 'salle';
      _imageUrl = r.image.isNotEmpty ? r.image : null;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  // ── Image ─────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200, maxHeight: 1200, imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName  = picked.name;
      _imageUrl           = null;
    });
  }

  Future<void> _uploadToCloudinary() async {
    if (_selectedImageBytes == null || _selectedImageName == null) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await CloudinaryService.uploadImage(
        imageBytes: _selectedImageBytes!,
        fileName: _selectedImageName!,
      );
      setState(() { _imageUrl = url; _isUploadingImage = false; });
      if (mounted) _showSnack('Image uploadée !');
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) _showSnack('Erreur upload : $e', isError: true);
    }
  }

  // ── Sauvegarde ────────────────────────────────────────────────────────────

  Future<void> _saveResource() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImageBytes != null && _imageUrl == null) {
      await _uploadToCloudinary();
      if (_imageUrl == null) return;
    }

    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
        'name':        _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image':       _imageUrl ?? '',
        'capacity':    int.parse(_capacityController.text.trim()),
        'category':    _selectedCategory, // toujours minuscule
        'updatedAt':   FieldValue.serverTimestamp(),
      };

      if (!_isEditing) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('resources').add(data);
        if (mounted) _showSnack('Ressource ajoutée !');
      } else {
        await FirebaseFirestore.instance
            .collection('resources')
            .doc(widget.resource!.id)
            .update(data);
        if (mounted) _showSnack('Ressource modifiée !');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteResource() async {
    if (!_isEditing) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la ressource',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Voulez-vous vraiment supprimer "${widget.resource!.name}" ?\nCette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('resources')
          .doc(widget.resource!.id)
          .delete();
      if (mounted) {
        _showSnack('Ressource supprimée');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la ressource' : 'Ajouter une ressource'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              tooltip: 'Supprimer',
              onPressed: _deleteResource,
            ),
        ],
      ),
      body: Stack(
        children: [
          const FallingResourcesBg(count: 12, globalOpacity: 0.5),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildImageSection(),
                            const SizedBox(height: 20),
                            _buildCard(children: [
                              _buildField(
                                controller: _nameController,
                                label: 'Nom de la ressource',
                                icon: Icons.label_rounded,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Champ requis'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _buildCategoryDropdown(),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _capacityController,
                                label: _capacityLabel,
                                icon: _capacityIcon,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                                  final n = int.tryParse(v.trim());
                                  if (n == null) return 'Nombre invalide';
                                  if (n < 1) return 'Minimum 1';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _descriptionController,
                                label: 'Description',
                                icon: Icons.description_rounded,
                                maxLines: 3,
                              ),
                            ]),
                            const SizedBox(height: 24),
                            _buildSaveButton(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      ),
      validator: validator,
    );
  }

  Widget _buildCategoryDropdown() {
    // S'assurer que la valeur est dans la liste
    final safeValue = _categories.contains(_selectedCategory)
        ? _selectedCategory
        : _categories.first;

    final labels = {
      'salle':      '🏢  Salle de réunion',
      'véhicule':   '🚗  Véhicule',
      'ordinateur': '💻  Ordinateur',
      'matériel':   '🔧  Matériel',
    };

    return DropdownButtonFormField<String>(
      value: safeValue,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: const InputDecoration(
        labelText: 'Catégorie',
        prefixIcon: Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
      ),
      items: _categories
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(labels[c] ?? c.toUpperCase()),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedCategory = v);
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _saveResource,
        icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
        label: Text(
          _isEditing ? 'Enregistrer les modifications' : 'Ajouter la ressource',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isEditing ? AppColors.primary : AppColors.success,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Section image ─────────────────────────────────────────────────────────

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.image_rounded, color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Text('Image de la ressource',
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 12),

          // Aperçu
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 180,
              color: AppColors.surfaceVariant,
              child: _buildImagePreview(),
            ),
          ),
          const SizedBox(height: 12),

          // Boutons
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploadingImage ? null : _pickImage,
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('Choisir'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (_selectedImageBytes != null && _imageUrl == null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploadingImage ? null : _uploadToCloudinary,
                  icon: _isUploadingImage
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(_isUploadingImage ? 'Upload...' : 'Uploader'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ]),

          if (_imageUrl != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 15),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Image uploadée sur Cloudinary',
                    style: TextStyle(fontSize: 12, color: AppColors.success)),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _imageUrl = null;
                  _selectedImageBytes = null;
                  _selectedImageName = null;
                }),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: EdgeInsets.zero),
                child: const Text('Changer', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Image.network(_imageUrl!, fit: BoxFit.cover,
          loadingBuilder: (_, child, p) =>
              p == null ? child : const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, __, ___) => _imagePlaceholder());
    }
    if (_selectedImageBytes != null) {
      return Stack(fit: StackFit.expand, children: [
        Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
        if (_isUploadingImage)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          )
        else
          Positioned(top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Non uploadée',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
      ]);
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.add_photo_alternate_rounded,
          size: 44, color: AppColors.textTertiary),
      const SizedBox(height: 8),
      const Text('Aucune image',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
    ],
  );
}
