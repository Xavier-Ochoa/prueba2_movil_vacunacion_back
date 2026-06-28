// GENERADO MANUALMENTE (no requiere build_runner).
//
// Si en algún momento agregas/quitas campos en VacunacionLocal, debes
// reflejar el cambio aquí también: añadir su HiveField en write() y
// read() respetando el número de campo asignado en el modelo.

part of 'vacunacion_local.dart';

class VacunacionLocalAdapter extends TypeAdapter<VacunacionLocal> {
  @override
  final int typeId = 0;

  @override
  VacunacionLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VacunacionLocal(
      clienteId: fields[0] as String,
      mongoId: fields[1] as String?,
      propietarioNombre: fields[2] as String,
      propietarioCedula: fields[3] as String,
      propietarioTelefono: fields[4] as String,
      mascotaTipo: fields[5] as String,
      mascotaNombre: fields[6] as String,
      mascotaEdad: fields[7] as int,
      mascotaSexo: fields[8] as String,
      vacuna: fields[9] as String,
      observaciones: fields[10] as String,
      imagenLocalPath: fields[11] as String,
      imagenUrlRemota: fields[12] as String?,
      latitud: fields[13] as double?,
      longitud: fields[14] as double?,
      barrioId: fields[15] as String?,
      fechaRegistro: fields[16] as DateTime,
      estado: fields[17] as String,
      intentos: fields[18] as int,
      ultimoError: fields[19] as String?,
      barrioNombre: fields[20] as String?,
      barrioSector: fields[21] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, VacunacionLocal obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.clienteId)
      ..writeByte(1)
      ..write(obj.mongoId)
      ..writeByte(2)
      ..write(obj.propietarioNombre)
      ..writeByte(3)
      ..write(obj.propietarioCedula)
      ..writeByte(4)
      ..write(obj.propietarioTelefono)
      ..writeByte(5)
      ..write(obj.mascotaTipo)
      ..writeByte(6)
      ..write(obj.mascotaNombre)
      ..writeByte(7)
      ..write(obj.mascotaEdad)
      ..writeByte(8)
      ..write(obj.mascotaSexo)
      ..writeByte(9)
      ..write(obj.vacuna)
      ..writeByte(10)
      ..write(obj.observaciones)
      ..writeByte(11)
      ..write(obj.imagenLocalPath)
      ..writeByte(12)
      ..write(obj.imagenUrlRemota)
      ..writeByte(13)
      ..write(obj.latitud)
      ..writeByte(14)
      ..write(obj.longitud)
      ..writeByte(15)
      ..write(obj.barrioId)
      ..writeByte(16)
      ..write(obj.fechaRegistro)
      ..writeByte(17)
      ..write(obj.estado)
      ..writeByte(18)
      ..write(obj.intentos)
      ..writeByte(19)
      ..write(obj.ultimoError)
      ..writeByte(20)
      ..write(obj.barrioNombre)
      ..writeByte(21)
      ..write(obj.barrioSector);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VacunacionLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
