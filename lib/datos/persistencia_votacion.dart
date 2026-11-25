import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/votacion.dart';

class PersistenciaVotacion {
  static const _claveVotos = 'vota_dolores_votos';
  static const _claveVotantes = 'vota_dolores_votantes';
  static const _claveVotosPorUsuario = 'vota_dolores_votos_por_usuario';
  static const _claveEsAnonima = 'vota_dolores_es_anonima';
  static const _claveIdUsuario = 'vota_dolores_id_usuario';

  Future<void> guardar(Votacion votacion) async {
    final prefs = await SharedPreferences.getInstance();

    final mapaVotos = {for (final o in votacion.opciones) o.id: o.votos};
    await prefs.setString(_claveVotos, jsonEncode(mapaVotos));
    await prefs.setStringList(_claveVotantes, votacion.votantes.toList());
    await prefs.setBool(_claveEsAnonima, votacion.esAnonima);

    if (votacion.esAnonima) {
      await prefs.remove(_claveVotosPorUsuario);
    } else {
      await prefs.setString(
        _claveVotosPorUsuario,
        jsonEncode(votacion.votosPorUsuario),
      );
    }
  }

  Future<void> cargar(Votacion votacion) async {
    final prefs = await SharedPreferences.getInstance();

    final votosJson = prefs.getString(_claveVotos);
    if (votosJson != null) {
      final mapaVotos = jsonDecode(votosJson) as Map<String, dynamic>;
      for (final opcion in votacion.opciones) {
        final cantidad = mapaVotos[opcion.id];
        if (cantidad is int) {
          opcion.votos = cantidad;
        }
      }
    }

    final votantesGuardados = prefs.getStringList(_claveVotantes);
    if (votantesGuardados != null) {
      votacion.votantes
        ..clear()
        ..addAll(votantesGuardados);
    }

    votacion.votosPorUsuario.clear();
    if (!votacion.esAnonima) {
      final porUsuarioJson = prefs.getString(_claveVotosPorUsuario);
      if (porUsuarioJson != null) {
        final mapa = jsonDecode(porUsuarioJson) as Map<String, dynamic>;
        for (final entry in mapa.entries) {
          if (entry.value is String) {
            votacion.votosPorUsuario[entry.key] = entry.value as String;
          }
        }
      }
    }
  }

  Future<bool> cargarModoAnonimo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveEsAnonima) ?? false;
  }

  Future<String> obtenerOCrearIdUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final existente = prefs.getString(_claveIdUsuario);
    if (existente != null) return existente;
    return crearNuevoUsuario();
  }

  Future<String> crearNuevoUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final nuevoId = 'invitado-${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(_claveIdUsuario, nuevoId);
    return nuevoId;
  }

  Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveVotos);
    await prefs.remove(_claveVotantes);
    await prefs.remove(_claveVotosPorUsuario);
    await prefs.remove(_claveEsAnonima);
    await prefs.remove(_claveIdUsuario);
  }
}
