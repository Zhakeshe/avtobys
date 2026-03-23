import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'wallet_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code, this.supportTelegram});

  final String message;
  final int? statusCode;
  final String? code;
  final String? supportTelegram;

  @override
  String toString() => message;
}

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
    this.validatorName = '',
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
  final String validatorName;

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
      validatorName: json['validatorName'] as String? ?? '',
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

class UserDto {
  const UserDto({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.cityName,
    required this.telegramChatId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.rideAccessEnabled,
    required this.trialRidesRemaining,
    required this.accessRequestedAt,
    required this.accessNote,
  });

  final String id;
  final String phoneNumber;
  final String fullName;
  final String cityName;
  final String telegramChatId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool rideAccessEnabled;
  final int trialRidesRemaining;
  final DateTime? accessRequestedAt;
  final String accessNote;

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      cityName: json['cityName'] as String? ?? '',
      telegramChatId: json['telegramChatId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      rideAccessEnabled: json['rideAccessEnabled'] as bool? ?? false,
      trialRidesRemaining: json['trialRidesRemaining'] as int? ?? 0,
      accessRequestedAt: DateTime.tryParse(
        json['accessRequestedAt'] as String? ?? '',
      ),
      accessNote: json['accessNote'] as String? ?? '',
    );
  }
}

class PublicConfigDto {
  const PublicConfigDto({
    required this.appName,
    required this.supportPhone,
    required this.supportTelegram,
    required this.accessRequestTelegram,
    required this.telegramBotUsername,
    required this.loginDeliveryMode,
    required this.defaultLanguage,
    required this.shareUrl,
    required this.currencySymbol,
    required this.newUserBonusBalance,
    required this.minimumTopUpAmount,
    required this.maintenanceMode,
    required this.trialRideCount,
  });

  final String appName;
  final String supportPhone;
  final String supportTelegram;
  final String accessRequestTelegram;
  final String telegramBotUsername;
  final String loginDeliveryMode;
  final String defaultLanguage;
  final String shareUrl;
  final String currencySymbol;
  final double newUserBonusBalance;
  final double minimumTopUpAmount;
  final bool maintenanceMode;
  final int trialRideCount;

  factory PublicConfigDto.fromJson(Map<String, dynamic> json) {
    return PublicConfigDto(
      appName: json['appName'] as String? ?? 'Avtobys',
      supportPhone: json['supportPhone'] as String? ?? '',
      supportTelegram: json['supportTelegram'] as String? ?? '',
      accessRequestTelegram: json['accessRequestTelegram'] as String? ?? '@aqxrx',
      telegramBotUsername: json['telegramBotUsername'] as String? ?? '',
      loginDeliveryMode: json['loginDeliveryMode'] as String? ?? 'telegram',
      defaultLanguage: json['defaultLanguage'] as String? ?? 'Русский',
      shareUrl: json['shareUrl'] as String? ?? '',
      currencySymbol: json['currencySymbol'] as String? ?? '₸',
      newUserBonusBalance:
          (json['newUserBonusBalance'] as num?)?.toDouble() ?? 0,
      minimumTopUpAmount:
          (json['minimumTopUpAmount'] as num?)?.toDouble() ?? 0,
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
      trialRideCount: json['trialRideCount'] as int? ?? 0,
    );
  }
}

class TelegramBindDto {
  const TelegramBindDto({
    required this.token,
    required this.botUsername,
    required this.deepLink,
    required this.command,
    required this.instructions,
    required this.expiresAt,
  });

  final String token;
  final String botUsername;
  final String deepLink;
  final String command;
  final String instructions;
  final DateTime expiresAt;

  bool get hasBotUsername => botUsername.isNotEmpty;
  bool get hasDeepLink => deepLink.isNotEmpty;

  factory TelegramBindDto.fromJson(Map<String, dynamic> json) {
    return TelegramBindDto(
      token: json['token'] as String? ?? '',
      botUsername: json['botUsername'] as String? ?? '',
      deepLink: json['deepLink'] as String? ?? '',
      command: json['command'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class TelegramBindStatusDto {
  const TelegramBindStatusDto({
    required this.phoneNumber,
    required this.isBound,
    required this.telegramChatId,
    required this.botUsername,
  });

  final String phoneNumber;
  final bool isBound;
  final String telegramChatId;
  final String botUsername;

  factory TelegramBindStatusDto.fromJson(Map<String, dynamic> json) {
    return TelegramBindStatusDto(
      phoneNumber: json['phoneNumber'] as String? ?? '',
      isBound: json['isBound'] as bool? ?? false,
      telegramChatId: json['telegramChatId'] as String? ?? '',
      botUsername: json['botUsername'] as String? ?? '',
    );
  }
}

class AuthCodeRequestDto {
  const AuthCodeRequestDto({
    required this.ok,
    required this.phoneNumber,
    required this.expiresAt,
    this.debugCode,
    this.deliveryStatus,
    this.deliveryError,
    this.supportTelegram,
    this.telegramBind,
  });

  final bool ok;
  final String phoneNumber;
  final DateTime expiresAt;
  final String? debugCode;
  final String? deliveryStatus;
  final String? deliveryError;
  final String? supportTelegram;
  final TelegramBindDto? telegramBind;

  factory AuthCodeRequestDto.fromJson(Map<String, dynamic> json) {
    final delivery = json['delivery'] as Map<String, dynamic>?;
    final telegramBind = json['telegramBind'] as Map<String, dynamic>?;
    return AuthCodeRequestDto(
      ok: json['ok'] as bool? ?? false,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now(),
      debugCode: json['debugCode'] as String?,
      deliveryStatus: delivery?['status'] as String?,
      deliveryError: delivery?['error'] as String?,
      supportTelegram: json['supportTelegram'] as String?,
      telegramBind: telegramBind == null
          ? null
          : TelegramBindDto.fromJson(telegramBind),
    );
  }
}

class AuthSessionDto {
  const AuthSessionDto({
    required this.token,
    required this.user,
    required this.wallet,
    required this.config,
  });

  final String token;
  final UserDto user;
  final WalletState wallet;
  final PublicConfigDto config;

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) {
    return AuthSessionDto(
      token: json['token'] as String? ?? '',
      user: UserDto.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
      wallet: WalletState.fromJson(
        json['wallet'] as Map<String, dynamic>? ?? const {},
      ),
      config: PublicConfigDto.fromJson(
        json['config'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class RideAccessRequestDto {
  const RideAccessRequestDto({
    required this.ok,
    required this.telegramUsername,
    required this.message,
  });

  final bool ok;
  final String telegramUsername;
  final String message;

  factory RideAccessRequestDto.fromJson(Map<String, dynamic> json) {
    return RideAccessRequestDto(
      ok: json['ok'] as bool? ?? false,
      telegramUsername: json['telegramUsername'] as String? ?? '@aqxrx',
      message: json['message'] as String? ?? '',
    );
  }
}

class TransportApi {
  static String? _sessionToken;

  static String get baseUrl {
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
      default:
        return 'http://localhost:4000/api';
    }
  }

  static void setSessionToken(String? value) {
    _sessionToken = value;
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
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static Future<PublicConfigDto> getPublicConfig() async {
    final response = await _requestObject('/config/public', omitAuth: true);
    return PublicConfigDto.fromJson(response);
  }

  static Future<AuthCodeRequestDto> requestAuthCode({
    required String phoneNumber,
    String? cityName,
  }) async {
    final body = <String, dynamic>{'phoneNumber': phoneNumber};
    if (cityName != null && cityName.isNotEmpty) {
      body['cityName'] = cityName;
    }
    final response = await _requestObject(
      '/auth/request-code',
      method: 'POST',
      omitAuth: true,
      body: body,
    );
    return AuthCodeRequestDto.fromJson(response);
  }

  static Future<AuthSessionDto> verifyAuthCode({
    required String phoneNumber,
    required String code,
    String? cityName,
  }) async {
    final body = <String, dynamic>{
      'phoneNumber': phoneNumber,
      'code': code,
    };
    if (cityName != null && cityName.isNotEmpty) {
      body['cityName'] = cityName;
    }
    final response = await _requestObject(
      '/auth/verify-code',
      method: 'POST',
      omitAuth: true,
      body: body,
    );
    return AuthSessionDto.fromJson(response);
  }

  static Future<AuthSessionDto> getAuthSession() async {
    final response = await _requestObject('/auth/me');
    return AuthSessionDto.fromJson(response);
  }

  static Future<void> logoutAuth() async {
    await _requestObject('/auth/logout', method: 'POST');
  }

  static Future<UserDto> updateProfile({
    String? fullName,
    String? cityName,
    String? telegramChatId,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) {
      body['fullName'] = fullName;
    }
    if (cityName != null) {
      body['cityName'] = cityName;
    }
    if (telegramChatId != null) {
      body['telegramChatId'] = telegramChatId;
    }
    final response = await _requestObject(
      '/me',
      method: 'PATCH',
      body: body,
    );
    return UserDto.fromJson(response);
  }

  static Future<TelegramBindDto> createTelegramBindToken({
    String? phoneNumber,
    String? cityName,
  }) async {
    final body = <String, dynamic>{};
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      body['phoneNumber'] = phoneNumber;
    }
    if (cityName != null && cityName.isNotEmpty) {
      body['cityName'] = cityName;
    }
    final response = await _requestObject(
      '/telegram/bind-token',
      method: 'POST',
      body: body,
      omitAuth: phoneNumber != null && phoneNumber.isNotEmpty,
    );
    return TelegramBindDto.fromJson(response);
  }

  static Future<TelegramBindStatusDto> getTelegramBindStatus({
    required String phoneNumber,
  }) async {
    final response = await _requestObject(
      '/telegram/bind-status${phoneNumber.isNotEmpty ? '?phone=${Uri.encodeQueryComponent(phoneNumber)}' : ''}',
      omitAuth: phoneNumber.isNotEmpty,
    );
    return TelegramBindStatusDto.fromJson(response);
  }

  static Future<RideAccessRequestDto> requestRideAccess({
    String? phoneNumber,
    String? cityName,
  }) async {
    final body = <String, dynamic>{};
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      body['phoneNumber'] = phoneNumber;
    }
    if (cityName != null && cityName.isNotEmpty) {
      body['cityName'] = cityName;
    }
    final response = await _requestObject(
      '/access/request',
      method: 'POST',
      body: body,
    );
    return RideAccessRequestDto.fromJson(response);
  }

  static Future<WalletState> getWallet() async {
    final response = await _requestObject('/wallet');
    return WalletState.fromJson(response);
  }

  static Future<WalletCardData> addWalletCard({
    required String holderName,
    required String number,
    required String cardType,
  }) async {
    final response = await _requestObject(
      '/wallet/cards',
      method: 'POST',
      body: {
        'holderName': holderName,
        'number': number,
        'cardType': cardType,
      },
    );
    return WalletCardData.fromJson(response);
  }

  static Future<String> activateWalletCard(String cardId) async {
    final response = await _requestObject(
      '/wallet/cards/$cardId/activate',
      method: 'POST',
    );
    return response['activeCardId'] as String? ?? '';
  }

  static Future<WalletState> topUpWallet({
    required double amount,
    String? cardId,
    String targetType = 'wallet',
    String? transportCardId,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'targetType': targetType,
    };
    if (cardId != null && cardId.isNotEmpty) {
      body['cardId'] = cardId;
    }
    if (transportCardId != null && transportCardId.isNotEmpty) {
      body['transportCardId'] = transportCardId;
    }
    final response = await _requestObject(
      '/wallet/top-up',
      method: 'POST',
      body: body,
    );
    return WalletState.fromJson(response);
  }

  static Future<List<CityDto>> getCities() async {
    final response = await _requestList('/cities', omitAuth: true);
    return response.map(CityDto.fromJson).toList();
  }

  static Future<List<TariffDto>> getTariffs(String cityId) async {
    final response = await _requestList(
      '/tariffs',
      queryParameters: {'cityId': cityId},
      omitAuth: true,
    );
    return response.map(TariffDto.fromJson).toList();
  }

  static Future<List<BusDto>> getBuses(
    String cityId, {
    String number = '',
    String qrToken = '',
  }) async {
    final response = await _requestList(
      '/buses',
      queryParameters: {
        'cityId': cityId,
        if (number.isNotEmpty) 'number': number,
        if (qrToken.isNotEmpty) 'qrToken': qrToken,
      },
      omitAuth: true,
    );
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
      omitAuth: true,
    );
    return BusDto.fromJson(response);
  }

  static Future<List<TicketDto>> getTickets([String phoneNumber = '']) async {
    final response = await _requestList(
      '/tickets',
      queryParameters: phoneNumber.isEmpty ? null : {'phone': phoneNumber},
    );
    return response.map(TicketDto.fromJson).toList();
  }

  static Future<TicketDto> createTicket({
    String? phoneNumber,
    required String busId,
    String paymentMethod = 'wallet',
    String? cityId,
    String? cityName,
    String? cardId,
  }) async {
    final body = <String, dynamic>{
      'busId': busId,
      'paymentMethod': paymentMethod,
    };
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      body['phoneNumber'] = phoneNumber;
    }
    if (cityId != null && cityId.isNotEmpty) {
      body['cityId'] = cityId;
    }
    if (cityName != null && cityName.isNotEmpty) {
      body['cityName'] = cityName;
    }
    if (cardId != null && cardId.isNotEmpty) {
      body['cardId'] = cardId;
    }
    final response = await _requestObject(
      '/tickets',
      method: 'POST',
      body: body,
    );
    return TicketDto.fromJson(response);
  }

  static Future<List<Map<String, dynamic>>> _requestList(
    String path, {
    Map<String, String>? queryParameters,
    bool omitAuth = false,
  }) async {
    final response = await http.get(
      _uri(path, queryParameters),
      headers: _headers(omitAuth: omitAuth),
    );
    return _decodeList(response);
  }

  static Future<Map<String, dynamic>> _requestObject(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool omitAuth = false,
  }) async {
    final uri = _uri(path);
    late http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: _headers(omitAuth: omitAuth));
      case 'POST':
        response = await http.post(
          uri,
          headers: _headers(omitAuth: omitAuth),
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: _headers(omitAuth: omitAuth),
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
      default:
        throw UnsupportedError('Unsupported method: $method');
    }
    return _decodeObject(response);
  }

  static Map<String, String> _headers({bool omitAuth = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _sessionToken;
    if (!omitAuth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static List<Map<String, dynamic>> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _decodeError(response);
    }
    final payload = jsonDecode(response.body);
    if (payload is! List) {
      throw const FormatException('Expected list response');
    }
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  static Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _decodeError(response);
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Expected object response');
    }
    return payload;
  }

  static ApiException _decodeError(http.Response response) {
    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(
        payload['message'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
        code: payload['code'] as String?,
        supportTelegram: payload['supportTelegram'] as String?,
      );
    } catch (_) {
      return ApiException(
        'Request failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
}
