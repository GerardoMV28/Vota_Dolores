import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vota_dolores_hidalgo/datos/persistencia_votacion.dart';
import 'package:vota_dolores_hidalgo/logica/resultado_voto.dart';
import 'package:vota_dolores_hidalgo/logica/servicio_votacion.dart';
import 'package:vota_dolores_hidalgo/modelos/opcion_votacion.dart';
import 'package:vota_dolores_hidalgo/modelos/votacion.dart';

Votacion _nuevaVotacion({bool esAnonima = false}) {
  return Votacion(
    pregunta: 'Pregunta persistente',
    opciones: [
      OpcionVotacion(id: 'jardin', texto: 'Jardín'),
      OpcionVotacion(id: 'parque', texto: 'Parque'),
    ],
    fechaCierre: DateTime.now().add(const Duration(days: 7)),
    esAnonima: esAnonima,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // RETO 5 — Persistencia con shared_preferences
  test('los votos y votantes sobreviven al recargar desde shared_preferences', () async {
    final persistencia = PersistenciaVotacion();

    final votacionOriginal = _nuevaVotacion();
    final servicioOriginal = ServicioVotacion(votacionOriginal);
    servicioOriginal.registrarVoto(idUsuario: 'vecino1', idOpcion: 'jardin');
    servicioOriginal.registrarVoto(idUsuario: 'vecino2', idOpcion: 'jardin');
    servicioOriginal.registrarVoto(idUsuario: 'vecino3', idOpcion: 'parque');

    await persistencia.guardar(votacionOriginal);

    // Simulamos cerrar y volver a abrir la app con una nueva instancia de Votacion
    final votacionRecargada = _nuevaVotacion();
    await persistencia.cargar(votacionRecargada);
    final servicioRecargado = ServicioVotacion(votacionRecargada);

    expect(votacionRecargada.opciones[0].votos, 2);
    expect(votacionRecargada.opciones[1].votos, 1);
    expect(
      servicioRecargado.registrarVoto(idUsuario: 'vecino1', idOpcion: 'parque'),
      ResultadoVoto.usuarioYaVoto,
    );
  });

  test('en modo anonimo no persiste que opcion eligio cada usuario', () async {
    final persistencia = PersistenciaVotacion();

    final votacionAnonima = _nuevaVotacion(esAnonima: true);
    final servicio = ServicioVotacion(votacionAnonima);
    servicio.registrarVoto(idUsuario: 'vecino1', idOpcion: 'jardin');

    await persistencia.guardar(votacionAnonima);

    final modoGuardado = await persistencia.cargarModoAnonimo();
    final votacionRecargada = _nuevaVotacion(esAnonima: modoGuardado);
    await persistencia.cargar(votacionRecargada);

    expect(modoGuardado, true);
    expect(votacionRecargada.opciones[0].votos, 1);
    expect(votacionRecargada.votantes.contains('vecino1'), true);
    expect(votacionRecargada.votosPorUsuario.isEmpty, true);
  });

  test('limpiar elimina los votos guardados en shared_preferences', () async {
    final persistencia = PersistenciaVotacion();

    final votacion = _nuevaVotacion();
    ServicioVotacion(votacion).registrarVoto(
      idUsuario: 'vecino1',
      idOpcion: 'jardin',
    );
    await persistencia.guardar(votacion);
    await persistencia.limpiar();

    final votacionLimpia = _nuevaVotacion();
    await persistencia.cargar(votacionLimpia);

    expect(votacionLimpia.opciones[0].votos, 0);
    expect(votacionLimpia.votantes.isEmpty, true);
  });
}
