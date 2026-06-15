class Device {
  final String id;
  final String name;
  final String type;
  final String status;
  final double pricePerDay;
  final int quantityTotal;
  final int quantityAvailable;
  final String description;
  final List<String> images;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.pricePerDay,
    required this.quantityTotal,
    required this.quantityAvailable,
    required this.description,
    required this.images,
  });

  Device copyWith({
    String? id,
    String? name,
    String? type,
    String? status,
    double? pricePerDay,
    int? quantityTotal,
    int? quantityAvailable,
    String? description,
    List<String>? images,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      quantityTotal: quantityTotal ?? this.quantityTotal,
      quantityAvailable: quantityAvailable ?? this.quantityAvailable,
      description: description ?? this.description,
      images: images ?? this.images,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      pricePerDay: (json['pricePerDay'] as num).toDouble(),
      quantityTotal: json['quantityTotal'] as int,
      quantityAvailable: json['quantityAvailable'] as int,
      description: json['description'] as String,
      images: (json['images'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'status': status,
      'pricePerDay': pricePerDay,
      'quantityTotal': quantityTotal,
      'quantityAvailable': quantityAvailable,
      'description': description,
      'images': images,
    };
  }
}
