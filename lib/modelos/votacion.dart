import 'opcion_votacion.dart';

class Votacion {
  final String pregunta;
  final List<OpcionVotacion> opciones;
  final DateTime fechaCierre;
  final int? limiteVotantes;
  final bool esAnonima;
  final Set<String> votantes = {};
  final Map<String, String> votosPorUsuario = {};

  Votacion({
    required this.pregunta,
    required this.opciones,
    required this.fechaCierre,
    this.limiteVotantes,
    this.esAnonima = false,
  });
}
