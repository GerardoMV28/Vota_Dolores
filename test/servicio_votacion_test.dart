import 'package:flutter_test/flutter_test.dart';
import 'package:vota_dolores_hidalgo/logica/resultado_voto.dart';
import 'package:vota_dolores_hidalgo/logica/servicio_votacion.dart';
import 'package:vota_dolores_hidalgo/modelos/opcion_votacion.dart';
import 'package:vota_dolores_hidalgo/modelos/votacion.dart';

Votacion _crearVotacionDePrueba({
  DateTime? fechaCierre,
  int? limiteVotantes,
  bool esAnonima = false,
}) {
  return Votacion(
    pregunta: 'Pregunta de prueba',
    opciones: [
      OpcionVotacion(id: 'op1', texto: 'Opcion 1'),
      OpcionVotacion(id: 'op2', texto: 'Opcion 2'),
    ],
    fechaCierre: fechaCierre ?? DateTime.now().add(const Duration(days: 7)),
    limiteVotantes: limiteVotantes,
    esAnonima: esAnonima,
  );
}

void main() {
  // RONDA 1 — Registrar un voto válido
  test('registrar un voto valido incrementa el contador de esa opcion', () {
    final votacion = _crearVotacionDePrueba();
    final servicio = ServicioVotacion(votacion);

    final resultado = servicio.registrarVoto(
      idUsuario: 'user1',
      idOpcion: 'op1',
    );

    expect(resultado, ResultadoVoto.exitoso);
    expect(votacion.opciones[0].votos, 1);
  });

  // RONDA 2 — Rechazar votos a opciones que no existen
  test('votar por una opcion que no existe regresa opcionInvalida', () {
    final votacion = _crearVotacionDePrueba();
    final servicio = ServicioVotacion(votacion);

    final resultado = servicio.registrarVoto(
      idUsuario: 'user1',
      idOpcion: 'no-existe',
    );

    expect(resultado, ResultadoVoto.opcionInvalida);
  });

  // RONDA 3 — Un usuario no puede votar dos veces
  test('un mismo usuario no puede votar dos veces', () {
    final votacion = _crearVotacionDePrueba();
    final servicio = ServicioVotacion(votacion);

    servicio.registrarVoto(idUsuario: 'user1', idOpcion: 'op1');
    final segundoIntento = servicio.registrarVoto(
      idUsuario: 'user1',
      idOpcion: 'op2',
    );

    expect(segundoIntento, ResultadoVoto.usuarioYaVoto);
    expect(votacion.opciones[1].votos, 0); // op2 no debió incrementarse
  });

  // RONDA 4 — Calcular resultados con porcentajes
  test('calcula el porcentaje de cada opcion correctamente', () {
    final votacion = _crearVotacionDePrueba();
    final servicio = ServicioVotacion(votacion);
    servicio.registrarVoto(idUsuario: 'u1', idOpcion: 'op1');
    servicio.registrarVoto(idUsuario: 'u2', idOpcion: 'op1');
    servicio.registrarVoto(idUsuario: 'u3', idOpcion: 'op1');
    servicio.registrarVoto(idUsuario: 'u4', idOpcion: 'op2');

    final resultados = servicio.obtenerResultados();

    final op1 = resultados.firstWhere((r) => r.opcion.id == 'op1');
    final op2 = resultados.firstWhere((r) => r.opcion.id == 'op2');
    expect(op1.porcentaje, 75.0);
    expect(op2.porcentaje, 25.0);
  });

  test('si no hay ningun voto, todos los porcentajes son 0', () {
    final votacion = _crearVotacionDePrueba();
    final servicio = ServicioVotacion(votacion);

    final resultados = servicio.obtenerResultados();

    expect(resultados.every((r) => r.porcentaje == 0), true);
  });

  // RONDA 5 — Determinar el ganador
  test('determinarGanador regresa la opcion con mas votos', () {
    final votacion = _crearVotacionDePrueba();
    final servicio = ServicioVotacion(votacion);
    servicio.registrarVoto(idUsuario: 'u1', idOpcion: 'op1');
    servicio.registrarVoto(idUsuario: 'u2', idOpcion: 'op1');
    servicio.registrarVoto(idUsuario: 'u3', idOpcion: 'op2');

    final ganadores = servicio.determinarGanador();

    expect(ganadores.length, 1);
    expect(ganadores.first.id, 'op1');
  });

  // RONDA 6 — Reconocer un empate (no elegir al azar)
  test('si hay empate, determinarGanador regresa mas de una opcion', () {
    final votacion = Votacion(
      pregunta: 'Pregunta de prueba',
      opciones: [
        OpcionVotacion(id: 'op1', texto: 'Opcion 1'),
        OpcionVotacion(id: 'op2', texto: 'Opcion 2'),
        OpcionVotacion(id: 'op3', texto: 'Opcion 3'),
      ],
      fechaCierre: DateTime.now().add(const Duration(days: 7)),
    );
    final servicio = ServicioVotacion(votacion);
    servicio.registrarVoto(idUsuario: 'u1', idOpcion: 'op1');
    servicio.registrarVoto(idUsuario: 'u2', idOpcion: 'op2');
    servicio.registrarVoto(idUsuario: 'u3', idOpcion: 'op3');

    final ganadores = servicio.determinarGanador();

    expect(ganadores.length, 3);
  });

  // RONDA 7 — No se puede votar después del cierre
  test('no se puede votar si la votacion ya cerro', () {
    final votacionCerrada = _crearVotacionDePrueba(
      fechaCierre: DateTime(2000, 1, 1), // una fecha muy en el pasado
    );
    final servicio = ServicioVotacion(votacionCerrada);

    final resultado = servicio.registrarVoto(
      idUsuario: 'user1',
      idOpcion: 'op1',
    );

    expect(resultado, ResultadoVoto.votacionCerrada);
    expect(votacionCerrada.opciones[0].votos, 0);
  });

  test('si la votacion sigue abierta, el voto se registra normalmente', () {
    final votacionAbierta = _crearVotacionDePrueba(
      fechaCierre: DateTime.now().add(const Duration(days: 1)),
    );
    final servicio = ServicioVotacion(votacionAbierta);

    final resultado = servicio.registrarVoto(
      idUsuario: 'user1',
      idOpcion: 'op1',
    );

    expect(resultado, ResultadoVoto.exitoso);
  });

  // Prueba de integración — Un plebiscito completo
  test('simulacion completa: varios vecinos votan y se determina un ganador', () {
    final votacion = Votacion(
      pregunta: 'Que obra prioritaria debe realizar el municipio?',
      opciones: [
        OpcionVotacion(
          id: 'jardin',
          texto: 'Rehabilitacion del Jardin Principal',
        ),
        OpcionVotacion(id: 'biblioteca', texto: 'Nueva Biblioteca Digital'),
        OpcionVotacion(
          id: 'alumbrado',
          texto: 'Alumbrado en el Barrio de Analco',
        ),
      ],
      fechaCierre: DateTime.now().add(const Duration(days: 3)),
    );
    final servicio = ServicioVotacion(votacion);

    servicio.registrarVoto(idUsuario: 'vecino1', idOpcion: 'jardin');
    servicio.registrarVoto(idUsuario: 'vecino2', idOpcion: 'jardin');
    servicio.registrarVoto(idUsuario: 'vecino3', idOpcion: 'biblioteca');
    servicio.registrarVoto(
      idUsuario: 'vecino1',
      idOpcion: 'alumbrado',
    ); // repetido: no debe contar

    final resultados = servicio.obtenerResultados();
    final totalVotos = resultados.fold<double>(0, (s, r) => s + r.opcion.votos);
    final ganadores = servicio.determinarGanador();

    expect(totalVotos, 3); // el intento repetido de vecino1 no debió contar
    expect(ganadores.length, 1);
    expect(ganadores.first.id, 'jardin');
  });

  // RETO 1 — Reloj inyectado en ServicioVotacion
  test('reloj inyectado permite probar cierre sin depender de la fecha real', () {
    final fechaCierre = DateTime(2026, 6, 15, 18, 0);
    final votacion = _crearVotacionDePrueba(fechaCierre: fechaCierre);

    DateTime fechaActual = DateTime(2026, 6, 15, 17, 59);
    final servicio = ServicioVotacion(votacion, ahora: () => fechaActual);

    // Un minuto antes del cierre: voto permitido
    final antes = servicio.registrarVoto(idUsuario: 'u1', idOpcion: 'op1');
    expect(antes, ResultadoVoto.exitoso);

    // Un minuto después del cierre: votación cerrada
    fechaActual = DateTime(2026, 6, 15, 18, 1);
    final despues = servicio.registrarVoto(idUsuario: 'u2', idOpcion: 'op2');
    expect(despues, ResultadoVoto.votacionCerrada);
    expect(votacion.opciones[1].votos, 0);
  });

  // RETO 2 — Límite de votantes totales (máximo 500)
  test('rechaza el voto 501 cuando el limite de votantes es 500', () {
    final votacion = _crearVotacionDePrueba(limiteVotantes: 500);
    final servicio = ServicioVotacion(votacion);

    for (var i = 1; i <= 500; i++) {
      final res = servicio.registrarVoto(
        idUsuario: 'vecino$i',
        idOpcion: i.isEven ? 'op1' : 'op2',
      );
      expect(res, ResultadoVoto.exitoso);
    }

    final voto501 = servicio.registrarVoto(
      idUsuario: 'vecino501',
      idOpcion: 'op1',
    );
    expect(voto501, ResultadoVoto.limiteAlcanzado);
    expect(votacion.votantes.length, 500);
    expect(votacion.opciones[0].votos + votacion.opciones[1].votos, 500);
  });

  // RETO 3 — Modo de votación anónima
  test(
    'en modo anonimo no guarda que opcion eligio el usuario pero impide votar dos veces',
    () {
      final votacion = _crearVotacionDePrueba(esAnonima: true);
      final servicio = ServicioVotacion(votacion);

      final primero = servicio.registrarVoto(
        idUsuario: 'user1',
        idOpcion: 'op1',
      );
      final segundo = servicio.registrarVoto(
        idUsuario: 'user1',
        idOpcion: 'op2',
      );

      expect(primero, ResultadoVoto.exitoso);
      expect(segundo, ResultadoVoto.usuarioYaVoto);
      expect(votacion.votantes.contains('user1'), true);
      expect(votacion.votosPorUsuario.isEmpty, true);
      expect(servicio.obtenerOpcionDeUsuario('user1'), isNull);
    },
  );

  test('en modo normal si guarda que opcion eligio cada usuario', () {
    final votacion = _crearVotacionDePrueba(esAnonima: false);
    final servicio = ServicioVotacion(votacion);

    servicio.registrarVoto(idUsuario: 'user1', idOpcion: 'op2');

    expect(servicio.obtenerOpcionDeUsuario('user1'), 'op2');
  });
}
