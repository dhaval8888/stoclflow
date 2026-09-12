import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_app/core/network/api_exceptions.dart';
import 'package:stockflow_app/features/settings/application/business_controller.dart';
import 'package:stockflow_app/features/settings/data/models/business_model.dart';
import 'package:stockflow_app/features/settings/data/repositories/business_repository.dart';

class FakeBusinessRepository extends BusinessRepository {
  BusinessModel currentBusiness;
  Exception? error;

  FakeBusinessRepository(this.currentBusiness) : super(Dio());

  @override
  Future<BusinessModel> getBusiness() async {
    if (error != null) throw error!;
    return currentBusiness;
  }

  @override
  Future<BusinessModel> updateBusiness({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? currency,
    String? timezone,
  }) async {
    if (error != null) throw error!;
    currentBusiness = BusinessModel(
      id: currentBusiness.id,
      name: name ?? currentBusiness.name,
      address: address ?? currentBusiness.address,
      phone: phone ?? currentBusiness.phone,
      email: email ?? currentBusiness.email,
      currency: currency ?? currentBusiness.currency,
      timezone: timezone ?? currentBusiness.timezone,
    );
    return currentBusiness;
  }
}

void main() {
  group('BusinessController Unit Tests', () {
    late FakeBusinessRepository repo;

    setUp(() {
      repo = FakeBusinessRepository(
        const BusinessModel(
          id: 'biz_test_1',
          name: 'Apex Supermarket',
          address: '456 Broadway',
          phone: '+1 800 555 1234',
          email: 'info@apex.com',
          currency: 'USD',
        ),
      );
    });

    test('initial load populates business with loaded status', () async {
      final controller = BusinessController(repo);
      await Future.delayed(Duration.zero);

      expect(controller.state.status, BusinessStatus.loaded);
      expect(controller.state.business?.name, 'Apex Supermarket');
      expect(controller.state.business?.currency, 'USD');
    });

    test('updateBusiness updates state and returns true', () async {
      final controller = BusinessController(repo);
      await Future.delayed(Duration.zero);

      final ok = await controller.updateBusiness(
        name: 'Apex Global Store',
        currency: 'EUR',
      );

      expect(ok, true);
      expect(controller.state.business?.name, 'Apex Global Store');
      expect(controller.state.business?.currency, 'EUR');
    });

    test('updateBusiness failure retains state and sets errorMessage', () async {
      final controller = BusinessController(repo);
      await Future.delayed(Duration.zero);

      repo.error = const ApiException(message: 'Permission denied', statusCode: 403);
      final ok = await controller.updateBusiness(name: 'Unauthorized Edit');

      expect(ok, false);
      expect(controller.state.errorMessage, 'Permission denied');
      expect(controller.state.business?.name, 'Apex Supermarket');
    });
  });
}
