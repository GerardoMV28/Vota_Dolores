import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vota_dolores_hidalgo/presentation/confeti_overlay.dart';
import 'package:vota_dolores_hidalgo/presentation/votacion_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // RETO 4 — Animación de confeti con CustomPainter solo cuando hay ganador sin empate
  testWidgets('muestra ConfetiOverlay cuando se revela un ganador sin empate', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VotacionScreen()));
    await tester.pumpAndSettle();

    // Votamos por la primera opción para tener un ganador único
    await tester.tap(find.text('Votar por esta opción').first);
    await tester.pumpAndSettle();

    // Abrimos el diálogo de resultado (haciendo scroll hasta que el botón quede visible)
    final botonResultado = find.text('Ver resultado del plebiscito');
    await tester.scrollUntilVisible(botonResultado, 200);
    await tester.ensureVisible(botonResultado);
    await tester.pumpAndSettle();
    await tester.tap(botonResultado);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Resultado del plebiscito'), findsOneWidget);
    expect(find.textContaining('La opción ganadora es:'), findsOneWidget);
    expect(find.byType(ConfetiOverlay), findsOneWidget);
  });

  testWidgets('no muestra ConfetiOverlay cuando hay empate', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VotacionScreen()));
    await tester.pumpAndSettle();

    // Sin votos, todas las opciones están empatadas en 0
    final botonResultado = find.text('Ver resultado del plebiscito');
    await tester.scrollUntilVisible(botonResultado, 200);
    await tester.ensureVisible(botonResultado);
    await tester.pumpAndSettle();
    await tester.tap(botonResultado);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Resultado del plebiscito'), findsOneWidget);
    expect(find.textContaining('Hay un empate entre:'), findsOneWidget);
    expect(find.byType(ConfetiOverlay), findsNothing);
  });

  // RETO 5 (UI) — Persistencia al cerrar y reabrir la app
  testWidgets(
    'los votos y el estado de usuario ya voto persisten al reabrir la pantalla',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VotacionScreen(key: ValueKey('sesion1'))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Votar por esta opción').first);
      await tester.pumpAndSettle();

      expect(find.text('Participación: 1 / 500 votantes'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Votar por esta opción'), findsNothing);

      // Simulamos cerrar y volver a abrir la app con una nueva instancia
      await tester.pumpWidget(
        const MaterialApp(home: VotacionScreen(key: ValueKey('sesion2'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Participación: 1 / 500 votantes'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Votar por esta opción'), findsNothing);
    },
  );

  // RETO 3 (UI) — Modo votación anónima en interfaz + bloqueo al iniciar votos
  testWidgets(
    'activar modo anonimo en la UI funciona, se bloquea tras votar y no guarda votos por usuario',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VotacionScreen()));
      await tester.pumpAndSettle();

      final interruptor = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(interruptor).value, false);

      await tester.tap(interruptor);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(interruptor).value, true);

      // Emitimos un voto en modo anónimo
      await tester.tap(find.text('Votar por esta opción').first);
      await tester.pumpAndSettle();

      // Una vez iniciada la votación, el switch queda deshabilitado
      expect(tester.widget<SwitchListTile>(interruptor).onChanged, isNull);

      // Verificamos en SharedPreferences que no se guardó el mapa votos_por_usuario
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('vota_dolores_es_anonima'), true);
      expect(prefs.getString('vota_dolores_votos_por_usuario'), isNull);
    },
  );

  // RETO 2 (UI) — Límite de votantes en la interfaz
  testWidgets(
    'al alcanzar el limite de votantes se deshabilitan los botones de voto',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VotacionScreen(limiteVotantes: 2)),
      );
      await tester.pumpAndSettle();

      // Vecino 1 vota
      await tester.tap(find.text('Votar por esta opción').first);
      await tester.pumpAndSettle();
      expect(find.text('Participación: 1 / 2 votantes'), findsOneWidget);

      // Simulamos vecino 2
      await tester.tap(find.byTooltip('Simular otro vecino'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Votar por esta opción').at(1));
      await tester.pumpAndSettle();
      expect(find.text('Participación: 2 / 2 votantes'), findsOneWidget);

      // Incluso si simulamos un vecino 3, ya no puede votar por límite alcanzado
      await tester.tap(find.byTooltip('Simular otro vecino'));
      await tester.pumpAndSettle();
      expect(find.text('Votar por esta opción'), findsNothing);
    },
  );

  // RETO 1 (UI) — Reloj inyectado detectando votación cerrada en la interfaz
  testWidgets(
    'con reloj inyectado posterior al cierre muestra aviso y no registra voto',
    (tester) async {
      final fechaFutura = DateTime.now().add(const Duration(days: 30));
      await tester.pumpWidget(
        MaterialApp(home: VotacionScreen(ahora: () => fechaFutura)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Votar por esta opción').first);
      await tester.pumpAndSettle();

      expect(find.text('Esta votación ya cerró.'), findsOneWidget);
      expect(find.text('Participación: 0 / 500 votantes'), findsOneWidget);
    },
  );

  // Flujo adicional: Simular otro vecino + empate real (1 vs 1) + reiniciar plebiscito
  testWidgets(
    'simular otro vecino permite empatar sin confeti y reiniciar limpia todo',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VotacionScreen()));
      await tester.pumpAndSettle();

      // Vecino 1 vota por opción 1
      await tester.tap(find.text('Votar por esta opción').first);
      await tester.pumpAndSettle();

      // Vecino 2 vota por opción 2 -> empate 50% / 50%
      await tester.tap(find.byTooltip('Simular otro vecino'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Votar por esta opción').at(1));
      await tester.pumpAndSettle();

      expect(find.text('50%'), findsNWidgets(2));

      // Esperamos a que se oculte el SnackBar antes de pulsar el botón inferior
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Ver resultado: empate sin confeti
      final botonResultado = find.text('Ver resultado del plebiscito');
      await tester.scrollUntilVisible(botonResultado, 200);
      await tester.ensureVisible(botonResultado);
      await tester.pumpAndSettle();
      await tester.tap(botonResultado);
      await tester.pumpAndSettle();

      expect(find.textContaining('Hay un empate entre:'), findsOneWidget);
      expect(find.byType(ConfetiOverlay), findsNothing);

      // Cerrar diálogo y reiniciar plebiscito
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reiniciar plebiscito'));
      await tester.pumpAndSettle();

      expect(find.text('Participación: 0 / 500 votantes'), findsOneWidget);
      expect(find.text('Votar por esta opción'), findsNWidgets(4));
    },
  );
}
