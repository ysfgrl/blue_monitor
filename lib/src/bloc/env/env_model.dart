import 'package:equatable/equatable.dart';
import 'env_type.dart';
class EnvModel extends Equatable {
  const EnvModel({
    required this.id,
    required this.name,
    required this.type,
    this.url,
  });

  static const local = EnvModel(
    id: 'local',
    name: 'local',
    type: EnvironmentType.local,
  );

  final String id;
  final String name;
  final EnvironmentType type;
  final String? url;

  static bool isValidUrl(String value) {
    final uri = Uri.tryParse(value);
    return !RegExp(r'\s').hasMatch(value) &&
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool get isValid =>
      id.isNotEmpty &&
          name.trim().isNotEmpty &&
          (type == EnvironmentType.local
              ? url == null
              : url != null && isValidUrl(url!));

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    if (url != null) 'url': url!,
  };

  factory EnvModel.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['id'] is! String ||
        json['name'] is! String ||
        (json['type'] != 'local' && json['type'] != 'claude') ||
        (json['url'] != null && json['url'] is! String)) {
      throw const FormatException('setting.invalidEnvironmentRecord');
    }
    final environment = EnvModel(
      id: json['id'] as String,
      name: (json['name'] as String).trim(),
      type: json['type'] == 'claude'
          ? EnvironmentType.claude
          : EnvironmentType.local,
      url: json['url'] as String?,
    );
    if (!environment.isValid) {
      throw const FormatException('setting.invalidEnvironmentRecord');
    }
    return environment;
  }

  @override
  List<Object?> get props => [id, name, type, url];
}