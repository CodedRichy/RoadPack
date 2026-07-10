import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/onboarding_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactRelationController = TextEditingController();

  DateTime? _selectedDob;
  String _vehicleType = 'none';
  final _vehicleRegController = TextEditingController();
  bool _isLoading = false;

  // `ref` is not safe to read from `initState` on a `ConsumerStatefulWidget`
  // in the way the original plan assumed, so the one-time seed of the name
  // field from the existing profile happens in `build` instead, guarded by
  // this flag so later rebuilds (e.g. toggling `_isLoading`) don't clobber
  // whatever the user has since typed. The profile fetch (Task 4) is async
  // and may still be loading on the very first build, so this watches
  // `userProfileProvider` (rather than a one-off `read`) to make sure a
  // rebuild happens once the fetch resolves and the name becomes available.
  bool _profileSeeded = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactRelationController.dispose();
    _vehicleRegController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (!_profileSeeded && profile != null) {
      _profileSeeded = true;
      if (profile.name != null && profile.name!.isNotEmpty) {
        _nameController.text = profile.name!;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildNamePage(),
            _buildDobPage(),
            _buildVehiclePage(),
            _buildEmergencyContactPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return OnboardingStep(
      title: 'What should we call you?',
      onNext: () async {
        final name = _nameController.text.trim();
        if (name.length < 2) return;
        setState(() => _isLoading = true);
        try {
          await ref.read(userProfileProvider.notifier).updateName(name);
          _nextPage();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save. Please try again.'),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      isLoading: _isLoading,
      child: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Your name',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDobPage() {
    return OnboardingStep(
      title: 'Date of birth',
      subtitle: 'Needed for safety features',
      onNext: () async {
        if (_selectedDob == null) return;
        setState(() => _isLoading = true);
        try {
          await ref
              .read(userProfileProvider.notifier)
              .updateDateOfBirth(_selectedDob!);
          _nextPage();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save. Please try again.'),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      isLoading: _isLoading,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedDob != null
                  ? '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}'
                  : 'Tap to select',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year - 18),
                  firstDate: DateTime(now.year - 100),
                  lastDate: now,
                );
                if (picked != null) setState(() => _selectedDob = picked);
              },
              child: const Text('Select date'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclePage() {
    return OnboardingStep(
      title: 'Your vehicle',
      subtitle: 'Affects crash detection sensitivity',
      onNext: () async {
        setState(() => _isLoading = true);
        final type = _vehicleType == 'none' ? null : _vehicleType;
        final reg = _vehicleRegController.text.trim();
        try {
          await ref
              .read(userProfileProvider.notifier)
              .updateVehicle(type, reg.isEmpty ? null : reg);
          _nextPage();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save. Please try again.'),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      isLoading: _isLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _vehicleType,
            items: const [
              DropdownMenuItem(value: 'none', child: Text('No vehicle')),
              DropdownMenuItem(
                value: 'two_wheeler',
                child: Text('Two wheeler'),
              ),
              DropdownMenuItem(
                value: 'four_wheeler',
                child: Text('Four wheeler'),
              ),
            ],
            onChanged: (v) => setState(() => _vehicleType = v ?? 'none'),
            decoration: const InputDecoration(
              labelText: 'Vehicle type',
              border: OutlineInputBorder(),
            ),
          ),
          if (_vehicleType != 'none') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _vehicleRegController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Registration number (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencyContactPage() {
    return OnboardingStep(
      title: 'Emergency contact',
      subtitle:
          'This person will be contacted if something happens to you on '
          'the road',
      showSkip: true,
      onSkip: () => _finishOnboarding(),
      onNext: () async {
        final name = _contactNameController.text.trim();
        final phone = _contactPhoneController.text.trim();
        final relation = _contactRelationController.text.trim();
        if (name.isEmpty || phone.isEmpty) return;
        setState(() => _isLoading = true);
        try {
          await ref
              .read(userProfileProvider.notifier)
              .addEmergencyContact(
                name: name,
                phone: phone,
                relationship: relation,
              );
          _finishOnboarding();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save. Please try again.'),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      nextLabel: 'Finish',
      isLoading: _isLoading,
      child: Column(
        children: [
          TextField(
            controller: _contactNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Contact name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Phone number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contactRelationController,
            decoration: const InputDecoration(
              hintText: 'Relationship (e.g., spouse, parent)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  void _finishOnboarding() {
    // Router redirect will handle navigation to /home
    // since profile is now onboarded (DOB is set)
    ref.invalidate(userProfileProvider);
  }
}
