import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CityDto {
  const CityDto({required this.id, required this.name});

  final String id;
  final String name;

  factory CityDto.fromJson(Map<String, dynamic> json) {
    return CityDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class TariffDto {
  const TariffDto({
    required this.id,
    required this.cityId,
    required this.name,
    required this.price,
  });

  final String id;
  final String cityId;
  final String name;
  final double price;

  factory TariffDto.fromJson(Map<String, dynamic> json) {
    return TariffDto(
      id: json['id'] as String? ?? '',
      cityId: json['cityId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BusDto {
  const BusDto({
    required this.id,
    required this.cityId,
    required this.cityName,
    required this.number,
    required this.routeNumber,
    required this.tariffId,
    required this.tariffName,
    required this.price,
    required this.bluetoothEnabled,
    required this.qrToken,
  });

  final String id;
  final String cityId;
  final String cityName;
  final String number;
  final String routeNumber;
  final String tariffId;
  final String tariffName;
  final double price;
  final bool bluetoothEnabled;
  final String qrToken;

  factory BusDto.fromJson(Map<String, dynamic> json) {
    return BusDto(
      id: json['id'] as String? ?? '',
      cityId: json['cityId'] as String? ?? '',
      cityName: json['cityName'] as String? ?? '',
      number: json['number'] as String? ?? '',
      routeNumber: json['routeNumber'] as String? ?? '',
      tariffId: json['tariffId'] as String? ?? '',
      tariffName: json['tariffName'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      bluetoothEnabled: json['bluetoothEnabled'] as bool? ?? false,
      qrToken: json['qrToken'] as String? ?? '',
    );
  }
}

class TicketDto {
  const TicketDto({
    required this.id,
    required this.phoneNumber,
    required this.cityId,
    required this.cityName,
    required this.busId,
    required this.busNumber,
    required this.routeNumber,
    required this.tariffName,
    required this.amount,
    required this.paymentMethod,
    required this.qrValue,
    required this.paidAt,
    required this.validUntil,
  });

  final String id;
  final String phoneNumber;
  final String cityId;
  final String cityName;
  final String busId;
  final String busNumber;
  final String routeNumber;
  final String tariffName;
  final double amount;
  final String paymentMethod;
  final String qrValue;
  final DateTime paidAt;
  final DateTime validUntil;

  factory TicketDto.fromJson(Map<String, dynamic> json) {
    return TicketDto(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      cityId: json['cityId'] as String? ?? '',
      cityName: json['cityName'] as String? ?? '',
      busId: json['busId'] as String? ?? '',
      busNumber: json['busNumber'] as String? ?? '',
      routeNumber: json['routeNumber'] as String? ?? '',
      tariffName: json['tariffName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod'] as String? ?? 'wallet',
      qrValue: json['qrValue'] as String? ?? '',
      paidAt:
          DateTime.tryParse(json['paidAt'] as String? ?? '') ?? DateTime.now(),
      validUntil:
          DateTime.tryParse(json['validUntil'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class TransportApi {
  static String get _baseUrl {
    const configured = String.fromEnvironment('AVTOBUS_API_URL');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      return 'http://localhost:4000/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:4000/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://localhost:4000/api';
      case TargetPlatform.fuchsia:
        return 'http://localhost:4000/api';
    }
  }

  static Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final query = <String, String>{};
    if (queryParameters != null) {
      for (final entry in queryParameters.entries) {
        if (entry.value.isNotEmpty) {
          query[entry.key] = entry.value;
        }
      }
    }
    return Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  static Future<List<CityDto>> getCities() async {
    final response = await _requestList('/cities');
    return response.map(CityDto.fromJson).toList();
  }

  static Future<List<TariffDto>> getTariffs(String cityId) async {
    final response = await _requestList('/tariffs', {'cityId': cityId});
    return response.map(TariffDto.fromJson).toList();
  }

  static Future<List<BusDto>> getBuses(
    String cityId, {
    String number = '',
    String qrToken = '',
  }) async {
    final response = await _requestList('/buses', {
      'cityId': cityId,
      'number': number,
      'qrToken': qrToken,
    });
    return response.map(BusDto.fromJson).toList();
  }

  static Future<BusDto> addBus({
    required String cityId,
    required String tariffId,
    required String number,
    required String routeNumber,
  }) async {
    final response = await _requestObject(
      '/buses',
      method: 'POST',
      body: {
        'cityId': cityId,
        'tariffId': tariffId,
        'number': number,
        'routeNumber': routeNumber,
        'bluetoothEnabled': true,
      },
    );
    return BusDto.fromJson(response);
  }

  static Future<List<TicketDto>> getTickets(String phoneNumber) async {
    final response = await _requestList('/tickets', {'phone': phoneNumber});
    return response.map(TicketDto.fromJson).toList();
  }

  static Future<TicketDto> createTicket({
    required String phoneNumber,
    required String busId,
    String paymentMethod = 'wallet',
  }) async {
    final response = await _requestObject(
      '/tickets',
      method: 'POST',
      body: {
        'phoneNumber': phoneNumber,
        'busId': busId,
        'paymentMethod': paymentMethod,
      },
    );
    return TicketDto.fromJson(response);
  }

  static Future<List<Map<String, dynamic>>> _requestList(
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    final uri = _uri(path, queryParameters);
    final response = await http.get(uri);
    return _decodeList(response);
  }

  static Future<Map<String, dynamic>> _requestObject(
    String path, {
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path);
    final response = switch (method) {
      'POST' => await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
      'PATCH' => await http.patch(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
      _ => throw UnsupportedError('Unsupported method: $method'),
    };
    return _decodeObject(response);
  }

  static List<Map<String, dynamic>> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Transport API failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body);
    if (payload is! List) {
      throw const FormatException('Expected list response');
    }

    return payload.whereType<Map<String, dynamic>>().toList();
  }

  static Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Transport API failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Expected object response');
    }

    return payload;
  }
}
