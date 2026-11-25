class MercadoPagoConfig {
  static const accessToken = String.fromEnvironment(
    'MP_ACCESS_TOKEN',
    defaultValue: 'APP_USR-4965895815822526-112422-01741e9e84d4805b01d23235d0e5e1b3-3871016463',
  );

  static bool get configurado =>
      accessToken.isNotEmpty && !accessToken.startsWith('MP_ACCESS_TOKEN');
}