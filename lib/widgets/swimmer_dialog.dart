import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/swimmer.dart';
import '../theme/app_theme.dart';

class SwimmerDialog extends StatefulWidget {
  final Swimmer? swimmer;
  const SwimmerDialog({super.key, this.swimmer});

  @override
  State<SwimmerDialog> createState() => _SwimmerDialogState();
}

class _SwimmerDialogState extends State<SwimmerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _clubController = TextEditingController();
  DateTime? _dob;
  File? _image;
  String? _selectedNationality;
  String? _selectedGender;
  final _dbHelper = DatabaseHelper();

  final Map<String, String> _countries = {
    'Singapore': 'SG',
    'United Kingdom': 'GB',
    'United States': 'US',
    'Australia': 'AU',
    'Malaysia': 'MY',
    'Indonesia': 'ID',
    'Thailand': 'TH',
    'Philippines': 'PH',
    'Vietnam': 'VN',
    'Hong Kong': 'HK',
    'China': 'CN',
    'Japan': 'JP',
    'South Korea': 'KR',
    'France': 'FR',
    'Germany': 'DE',
    'Italy': 'IT',
    'Spain': 'ES',
    'Canada': 'CA',
    'New Zealand': 'NZ',
    'South Africa': 'ZA',
    'Ireland': 'IE',
    'Switzerland': 'CH',
  };

  @override
  void initState() {
    super.initState();
    if (widget.swimmer != null) {
      _firstNameController.text = widget.swimmer!.firstName;
      _surnameController.text = widget.swimmer!.surname;
      _selectedNationality = widget.swimmer!.nationality.toUpperCase();
      _selectedGender = widget.swimmer!.gender;
      _clubController.text = widget.swimmer!.club ?? '';
      _dob = widget.swimmer!.dob;
      if (widget.swimmer!.photoPath != null) {
        _image = File(widget.swimmer!.photoPath!);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2010),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark ? const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ) : ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.lightTextPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      title: Text(
        widget.swimmer == null ? 'ADD NEW SWIMMER' : 'EDIT SWIMMER',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.5),
                      width: 2,
                    ),
                    image: _image != null ? DecorationImage(
                      image: FileImage(_image!),
                      fit: BoxFit.cover,
                    ) : null,
                  ),
                  child: _image == null ? Center(
                    child: Icon(Icons.add_a_photo_rounded, size: 32, color: AppColors.primary),
                  ) : null,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (v) => v!.isEmpty ? 'First name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(
                  labelText: 'Surname',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (v) => v!.isEmpty ? 'Surname is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_rounded, size: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                ],
                onChanged: (v) => setState(() => _selectedGender = v),
                validator: (v) => v == null ? 'Gender is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _countries.values.contains(_selectedNationality) ? _selectedNationality : null,
                decoration: const InputDecoration(
                  labelText: 'Nationality',
                  prefixIcon: Icon(Icons.flag_outlined, size: 20),
                ),
                items: _countries.entries.map((e) => DropdownMenuItem(
                  value: e.value,
                  child: Text(e.key),
                )).toList(),
                onChanged: (v) => setState(() => _selectedNationality = v),
                validator: (v) => v == null ? 'Nationality is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clubController,
                decoration: const InputDecoration(
                  labelText: 'Club',
                  prefixIcon: Icon(Icons.groups_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                  ),
                  child: Text(
                    _dob == null ? 'Select Date' : DateFormat('d MMM yyyy').format(_dob!),
                    style: TextStyle(
                      color: _dob == null 
                          ? (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary)
                          : (isDark ? Colors.white : AppColors.lightTextPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    ),
    actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'CANCEL',
            style: TextStyle(
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate() && _dob != null) {
              final swimmer = Swimmer(
                id: widget.swimmer?.id,
                firstName: _firstNameController.text,
                surname: _surnameController.text,
                nationality: _selectedNationality!,
                gender: _selectedGender!,
                dob: _dob!,
                photoPath: _image?.path,
                club: _clubController.text,
              );
              
              int? finalId;
              if (widget.swimmer == null) {
                finalId = await _dbHelper.insertSwimmer(swimmer);
              } else {
                await _dbHelper.updateSwimmer(swimmer);
                finalId = swimmer.id;
              }
              
              if (mounted) Navigator.pop(context, finalId);
            } else if (_dob == null) {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select Date of Birth')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'SAVE',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
          ),
        ),
      ],
    );
  }
}
