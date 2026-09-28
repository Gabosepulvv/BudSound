/// Transacción asociada a una solicitud aceptada con propina.
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.requestId,
    required this.montoBrutoClp,
    required this.comisionClp,
    required this.montoNetoClp,
    required this.status,
  });

  final String id;
  final String requestId;
  final int montoBrutoClp;
  final int comisionClp;
  final int montoNetoClp;
  final String status; // 'PENDIENTE' | 'APROBADA' | 'RECHAZADA'

  bool get aprobada => status == 'APROBADA';

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      montoBrutoClp: (json['monto_bruto_clp'] as num).toInt(),
      comisionClp: (json['comision_clp'] as num).toInt(),
      montoNetoClp: (json['monto_neto_clp'] as num).toInt(),
      status: json['status'] as String,
    );
  }
}
