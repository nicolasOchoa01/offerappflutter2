import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/src/application/auth/auth_notifier.dart';
import 'package:myapp/src/application/main/main_notifier.dart';
import 'package:myapp/src/presentation/widgets/custom_header.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _productController = TextEditingController();
  final _brandController = TextEditingController();
  final _storeController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _finalPriceController = TextEditingController();
  final _otherPromotionController = TextEditingController();

  String _location = '';
  double _latitude = 0.0;
  double _longitude = 0.0;
  File? _imageFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _selectedCategory;
  String? _selectedPromotionType;
  String? _lastEditedField;

  final List<String> _categories = [
    "Alimentos", "Tecnología", "Moda", "Deportes", "Construcción",
    "Animales", "Electrodomésticos", "Servicios", "Educación",
    "Juguetes", "Vehículos", "Otros"
  ];

  final List<String> _promotionTypes = [
    "2x1", "3x1", "3x2", "25% OFF", "30% OFF", "50% OFF", "Liquidación", "Otros"
  ];

  @override
  void initState() {
    super.initState();
    _productController.addListener(_updateDescription);
    _brandController.addListener(_updateDescription);
    _otherPromotionController.addListener(_updateDescription);
    _originalPriceController.addListener(() => setState(() { _lastEditedField = "original"; _calculatePrices(); }));
    _finalPriceController.addListener(() => setState(() { _lastEditedField = "final"; _calculatePrices(); }));
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _productController.removeListener(_updateDescription);
    _brandController.removeListener(_updateDescription);
    _otherPromotionController.removeListener(_updateDescription);
    _originalPriceController.dispose();
    _finalPriceController.dispose();
    _descriptionController.dispose();
    _productController.dispose();
    _brandController.dispose();
    _storeController.dispose();
    _otherPromotionController.dispose();
    super.dispose();
  }

  void _updateDescription() {
    String promotionDetail = _selectedPromotionType == "Otros" ? _otherPromotionController.text : _selectedPromotionType ?? '';
    String productText = _productController.text;
    String brandText = _brandController.text.isNotEmpty ? "de ${_brandController.text}" : '';
    
    if (mounted) {
      setState(() {
        _descriptionController.text = "$promotionDetail en $productText $brandText".trim().replaceAll(RegExp(r'\s+'), ' ');
      });
    }
  }

  void _calculatePrices() {
    if (_selectedPromotionType == "Liquidación" || _selectedPromotionType == "Otros" || _selectedPromotionType == null) {
      if (mounted) setState(() {});
      return;
    }

    final originalPrice = double.tryParse(_originalPriceController.text);

    if (mounted && originalPrice != null) {
      setState(() {
        _finalPriceController.text = _getFinalPrice(originalPrice, _selectedPromotionType!)?.toStringAsFixed(2) ?? '';
      });
    }
  }

  double? _getFinalPrice(double originalPrice, String promotion) {
    switch (promotion) {
      case "2x1": return originalPrice / 2;
      case "3x1": return originalPrice / 3;
      case "3x2": return originalPrice * 2 / 3;
      case "25% OFF": return originalPrice * 0.75;
      case "30% OFF": return originalPrice * 0.70;
      case "50% OFF": return originalPrice * 0.50;
      default: return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
         if (mounted) setState(() => _location = "Permiso de ubicación denegado");
         if (mounted) setState(() => _isLoading = false);
         return;
      }

      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _location = placemarks.first.subLocality ?? placemarks.first.locality ?? 'Ubicación Desconocida';
        });
      }
    } catch (e) {
       if (mounted) setState(() => _location = "Error al obtener ubicación");
    } 
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageFile = null;
        });
      } else {
        setState(() {
          _imageFile = File(image.path);
          _imageBytes = null;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || (_imageFile == null && _imageBytes == null)) {
      return;
    }
    final originalPrice = double.tryParse(_originalPriceController.text) ?? 0.0;
    final finalPrice = double.tryParse(_finalPriceController.text) ?? 0.0;
    if (finalPrice >= originalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El precio final debe ser menor al precio original.')));
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final router = GoRouter.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final mainNotifier = context.read<MainNotifier>();

    try {
      await mainNotifier.addPost(
        description: _descriptionController.text,
        imageFile: _imageFile,
        imageBytes: _imageBytes,
        location: _location,
        latitude: _latitude,
        longitude: _longitude,
        category: _selectedCategory!,
        price: originalPrice,
        discountPrice: finalPrice,
        store: _storeController.text.isNotEmpty ? _storeController.text : 'desconocido',
      );
      
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Publicación creada con éxito')));
      router.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error al crear la publicación: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  bool _isFormValid() {
    if ((_imageFile == null && _imageBytes == null) || _selectedCategory == null || _isLoading) return false;
    if (_originalPriceController.text.isEmpty || _finalPriceController.text.isEmpty) return false;

    final originalPrice = double.tryParse(_originalPriceController.text) ?? 0.0;
    final finalPrice = double.tryParse(_finalPriceController.text) ?? 0.0;

    return finalPrice < originalPrice;
  }

  @override
  Widget build(BuildContext context) {
    final mainNotifier = context.read<MainNotifier>();
    final authNotifier = context.read<AuthNotifier>();

    final outlineInputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(8),
    );

    final inputDecoration = InputDecoration(
      border: outlineInputBorder,
      enabledBorder: outlineInputBorder,
      focusedBorder: outlineInputBorder.copyWith(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
    );

    final isFixedDiscount = _selectedPromotionType != "Liquidación" && _selectedPromotionType != "Otros" && _selectedPromotionType != null;

    return Scaffold(
      appBar: CustomHeader(
        username: mainNotifier.user.username,
        title: 'Crear Publicación',
        onBackClicked: () => context.pop(),
        onProfileClick: () {
          context.go('/profile/${mainNotifier.user.id}');
        },
        onSessionClicked: () {
          authNotifier.logout();
          context.go('/login');
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                     const Text("Descripción", style: TextStyle(fontSize: 12)),
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        child: Text(_descriptionController.text.isEmpty ? "Aquí aparecerá la descripción autogenerada..." : _descriptionController.text),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPromotionType,
                      hint: const Text('Tipo de Promoción'),
                      decoration: inputDecoration.copyWith(labelText: 'Tipo de Promoción'),
                      items: _promotionTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPromotionType = value;
                          _updateDescription();
                          if (!isFixedDiscount) {
                            _finalPriceController.clear();
                          }
                        });
                      },
                      validator: (value) => value == null ? 'Campo requerido' : null,
                    ),
                    if (_selectedPromotionType == 'Otros') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otherPromotionController,
                        decoration: inputDecoration.copyWith(labelText: 'Especifique la Promoción'),
                        onChanged: (_) => _updateDescription(),
                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _productController,
                      decoration: inputDecoration.copyWith(labelText: 'Producto'),
                      onChanged: (_) => _updateDescription(),
                      validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _brandController,
                      decoration: inputDecoration.copyWith(labelText: 'Marca'),
                      onChanged: (_) => _updateDescription(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _storeController,
                      decoration: inputDecoration.copyWith(labelText: 'Comercio (Tienda)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _originalPriceController,
                      decoration: inputDecoration.copyWith(labelText: 'Precio Original'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Debe ingresar el precio original.';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Ingrese un número válido (ej: 100.00)';
                        }
                        return null;
                      },
                      onChanged: (_) => _calculatePrices(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _finalPriceController,
                      decoration: inputDecoration.copyWith(labelText: 'Precio Final (con descuento)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      hint: const Text('Categoría'),
                      decoration: inputDecoration.copyWith(labelText: 'Categoría'),
                      items: _categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                      onChanged: (value) => setState(() => _selectedCategory = value),
                      validator: (value) => value == null ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: kIsWeb
                          ? _imageBytes == null
                              ? const Text('No se ha seleccionado ninguna imagen.')
                              : Image.memory(_imageBytes!, height: 150, width: 150, fit: BoxFit.cover)
                          : _imageFile == null
                              ? const Text('No se ha seleccionado ninguna imagen.')
                              : Image.file(_imageFile!, height: 150, width: 150, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: _pickImage, 
                      label: const Text('Tomar foto'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      onPressed: _isFormValid() ? _submit : null,
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: _isFormValid() ? Theme.of(context).colorScheme.primary : Colors.grey,
                        foregroundColor: _isFormValid() ? Theme.of(context).colorScheme.onPrimary : Colors.white,
                      ),                      
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
