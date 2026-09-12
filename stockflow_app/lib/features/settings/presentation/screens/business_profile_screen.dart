import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/business_controller.dart';

class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _currencyController = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _populate(dynamic b) {
    if (b == null) return;
    _nameController.text = b.name ?? '';
    _addressController.text = b.address ?? '';
    _phoneController.text = b.phone ?? '';
    _emailController.text = b.email ?? '';
    _currencyController.text = b.currency ?? 'USD';
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await ref.read(businessControllerProvider.notifier).updateBusiness(
          name: _nameController.text.trim(),
          address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
          phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          currency: _currencyController.text.trim().toUpperCase(),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } else {
      final err = ref.read(businessControllerProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Failed to update business profile'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final isOwner = user?.isOwner ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    if (!_initialized && state.business != null) {
      _populate(state.business);
    }

    if (state.isLoading && state.business == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Business Profile')),
        body: const LoadingView(message: 'Loading business profile...'),
      );
    }

    if (state.hasError && state.business == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Business Profile')),
        body: ErrorStateView(
          message: state.errorMessage ?? 'Failed to load business profile',
          onRetry: () => ref.read(businessControllerProvider.notifier).load(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.space20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOwner
                      ? 'Update your organization details and store information.'
                      : 'View your organization details. Only owners can make edits.',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.space24),

                AppTextField(
                  label: 'Business Name',
                  hint: 'e.g. Apex Store',
                  controller: _nameController,
                  enabled: isOwner,
                  prefixIcon: Icons.store_outlined,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Business name is required';
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.space16),

                AppTextField(
                  label: 'Contact Email',
                  hint: 'contact@store.com',
                  controller: _emailController,
                  enabled: isOwner,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.space16),

                AppTextField(
                  label: 'Contact Phone',
                  hint: '+1 (555) 123-4567',
                  controller: _phoneController,
                  enabled: isOwner,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: AppDimensions.space16),

                AppTextField(
                  label: 'Store Address',
                  hint: '123 Market St, Suite 100',
                  controller: _addressController,
                  enabled: isOwner,
                  maxLines: 2,
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: AppDimensions.space16),

                AppTextField(
                  label: 'Default Currency Code',
                  hint: 'USD, EUR, GBP, INR...',
                  controller: _currencyController,
                  enabled: isOwner,
                  prefixIcon: Icons.currency_exchange_rounded,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Currency code is required';
                    if (val.trim().length > 4) return 'Code must be 3-4 letters';
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.space32),

                if (isOwner)
                  AppButton(
                    text: 'Save Changes',
                    icon: Icons.check_rounded,
                    isLoading: _isSaving,
                    onPressed: _save,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
