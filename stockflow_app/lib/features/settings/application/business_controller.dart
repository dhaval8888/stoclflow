import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exceptions.dart';
import '../data/models/business_model.dart';
import '../data/repositories/business_repository.dart';

enum BusinessStatus { initial, loading, loaded, error }

class BusinessState {
  final BusinessModel? business;
  final BusinessStatus status;
  final String? errorMessage;

  const BusinessState({
    this.business,
    this.status = BusinessStatus.initial,
    this.errorMessage,
  });

  bool get isLoading => status == BusinessStatus.loading;
  bool get hasError => status == BusinessStatus.error;

  BusinessState copyWith({
    BusinessModel? business,
    BusinessStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BusinessState(
      business: business ?? this.business,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final businessControllerProvider =
    StateNotifierProvider.autoDispose<BusinessController, BusinessState>((ref) {
  return BusinessController(ref.read(businessRepositoryProvider));
});

class BusinessController extends StateNotifier<BusinessState> {
  final BusinessRepository _repository;

  BusinessController(this._repository) : super(const BusinessState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: BusinessStatus.loading, clearError: true);
    try {
      final b = await _repository.getBusiness();
      state = state.copyWith(
        business: b,
        status: BusinessStatus.loaded,
      );
    } catch (e) {
      state = state.copyWith(
        status: BusinessStatus.error,
        errorMessage: ApiException.getErrorMessage(e),
      );
    }
  }

  Future<bool> updateBusiness({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? currency,
    String? timezone,
  }) async {
    state = state.copyWith(status: BusinessStatus.loading, clearError: true);
    try {
      final updated = await _repository.updateBusiness(
        name: name,
        address: address,
        phone: phone,
        email: email,
        currency: currency,
        timezone: timezone,
      );
      state = state.copyWith(
        business: updated,
        status: BusinessStatus.loaded,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: BusinessStatus.loaded,
        errorMessage: ApiException.getErrorMessage(e),
      );
      return false;
    }
  }
}
