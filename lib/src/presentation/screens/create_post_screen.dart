import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/src/data/repositories/post_repository.dart';
import 'package:myapp/src/data/repositories/user_repository.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:provider/provider.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';

class CreatePostScreen extends StatefulWidget {
  final Post? postToEdit;

  const CreatePostScreen({super.key, this.postToEdit});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _image;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _discountPriceController;
  late TextEditingController _storeController;

  String? _selectedCategory;
  String? _selectedStatus;

  bool get _isEditing => widget.postToEdit != null;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.postToEdit?.description);
    _priceController = TextEditingController(text: widget.postToEdit?.price.toString());
    _discountPriceController = TextEditingController(text: widget.postToEdit?.discountPrice.toString());
    _storeController = TextEditingController(text: widget.postToEdit?.store);
    _selectedCategory = widget.postToEdit?.category;
    _selectedStatus = widget.postToEdit?.status;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_image == null && !_isEditing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona una imagen.')),
        );
        return;
      }

      final authRepo = context.read<AuthRepository>();
      final userRepo = context.read<UserRepository>();
      final postRepo = context.read<PostRepository>();
      
      final currentUser = authRepo.currentUser;
      if (currentUser == null) return;

      try {
        if (_isEditing) {
          await postRepo.updatePostDetails(
            postId: widget.postToEdit!.id,
            description: _descriptionController.text,
            price: double.parse(_priceController.text),
            discountPrice: double.parse(_discountPriceController.text),
            category: _selectedCategory!,
            store: _storeController.text,
          );
           if (_selectedStatus != null && _selectedStatus != widget.postToEdit!.status) {
              await postRepo.updatePostStatus(widget.postToEdit!.id, _selectedStatus!);
          }
        } else {
          final user = await userRepo.getUserStream(currentUser.uid).first;
          if (user == null) return;

          final newPost = Post(
            id: '', 
            userId: currentUser.uid,
            description: _descriptionController.text,
            price: double.parse(_priceController.text),
            discountPrice: double.parse(_discountPriceController.text),
            imageUrl: '',
            user: user,
            category: _selectedCategory!,
            store: _storeController.text,
            scores: [],
            status: 'activa',
          );

          await postRepo.addPost(post: newPost, imageFile: _image!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Publicación ${ _isEditing ? 'actualizada' : 'creada'} con éxito!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Oferta' : 'Crear Oferta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildImagePicker(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildPriceFields(),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              _buildStoreField(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _image != null
                ? Image.file(_image!, fit: BoxFit.cover)
                : (_isEditing && widget.postToEdit!.imageUrl.isNotEmpty
                    ? Image.network(widget.postToEdit!.imageUrl, fit: BoxFit.cover)
                    : const Center(child: Text('Toca para seleccionar una imagen'))),
          ),
          TextButton.icon(
            icon: const Icon(Icons.image),
            label: const Text('Seleccionar Imagen'),
            onPressed: _pickImage,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
      validator: (value) => value!.isEmpty ? 'La descripción no puede estar vacía' : null,
      maxLines: 3,
    );
  }

  Widget _buildPriceFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _priceController,
            decoration: const InputDecoration(labelText: 'Precio Original', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            validator: (value) => value!.isEmpty ? 'Introduce un precio' : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _discountPriceController,
            decoration: const InputDecoration(labelText: 'Precio con Descuento', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            validator: (value) => value!.isEmpty ? 'Introduce un precio' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = ['Tecnología', 'Hogar', 'Moda', 'Alimentación', 'Viajes'];
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
      initialValue: _selectedCategory,
      items: categories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedCategory = newValue;
        });
      },
      validator: (value) => value == null ? 'Selecciona una categoría' : null,
    );
  }

  Widget _buildStoreField() {
    return TextFormField(
      controller: _storeController,
      decoration: const InputDecoration(labelText: 'Tienda', border: OutlineInputBorder()),
      validator: (value) => value!.isEmpty ? 'Introduce el nombre de la tienda' : null,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      icon: Icon(_isEditing ? Icons.save : Icons.add),
      label: Text(_isEditing ? 'Guardar Cambios' : 'Publicar Oferta'),
      onPressed: _submitForm,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18),
      ),
    );
  }
}
