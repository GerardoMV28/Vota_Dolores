import 'package:flutter/material.dart';
import '../datos/persistencia_votacion.dart';
import '../logica/resultado_voto.dart';
import '../logica/servicio_votacion.dart';
import '../modelos/opcion_votacion.dart';
import '../modelos/resultado_opcion.dart';
import '../modelos/votacion.dart';
import 'confeti_overlay.dart';

class VotacionScreen extends StatefulWidget {
  final PersistenciaVotacion? persistencia;
  final DateTime Function()? ahora;
  final int limiteVotantes;

  const VotacionScreen({
    super.key,
    this.persistencia,
    this.ahora,
    this.limiteVotantes = 500,
  });

  @override
  State<VotacionScreen> createState() => _VotacionScreenState();
}

class _VotacionScreenState extends State<VotacionScreen> {
  late final PersistenciaVotacion _persistencia;
  late Votacion _votacion;
  late ServicioVotacion _servicio;
  bool _esAnonima = false;
  bool _yaVote = false;
  bool _cargando = true;
  String _idUsuario = 'invitado-${DateTime.now().microsecondsSinceEpoch}';

  int get _limiteVotantes => widget.limiteVotantes;

  @override
  void initState() {
    super.initState();
    _persistencia = widget.persistencia ?? PersistenciaVotacion();
    _inicializarVotacion(esAnonima: _esAnonima);
    _cargarEstadoGuardado();
  }

  void _inicializarVotacion({required bool esAnonima}) {
    _votacion = Votacion(
      pregunta: '¿Qué obra prioritaria debe realizar el municipio este año?',
      opciones: [
        OpcionVotacion(
          id: 'jardin',
          texto: 'Rehabilitación del Jardín Principal',
        ),
        OpcionVotacion(id: 'biblioteca', texto: 'Nueva Biblioteca Digital'),
        OpcionVotacion(
          id: 'alumbrado',
          texto: 'Alumbrado en el Barrio de Analco',
        ),
        OpcionVotacion(
          id: 'parque',
          texto: 'Parque Infantil en la Colonia Guanajuato',
        ),
      ],
      fechaCierre: DateTime.now().add(const Duration(days: 7)),
      limiteVotantes: _limiteVotantes,
      esAnonima: esAnonima,
    );
    _servicio = ServicioVotacion(_votacion, ahora: widget.ahora);
  }

  Future<void> _cargarEstadoGuardado() async {
    final modoAnonimo = await _persistencia.cargarModoAnonimo();
    final idUsuario = await _persistencia.obtenerOCrearIdUsuario();
    _inicializarVotacion(esAnonima: modoAnonimo);
    await _persistencia.cargar(_votacion);

    if (!mounted) return;
    setState(() {
      _esAnonima = modoAnonimo;
      _idUsuario = idUsuario;
      _yaVote = _votacion.votantes.contains(_idUsuario);
      _cargando = false;
    });
  }

  Future<void> _cambiarModoAnonimo(bool nuevoValor) async {
    if (_votacion.votantes.isNotEmpty) {
      _mensaje(
        'No se puede cambiar el modo anónimo una vez iniciada la votación.',
      );
      return;
    }
    setState(() {
      _esAnonima = nuevoValor;
      _inicializarVotacion(esAnonima: nuevoValor);
    });
    await _persistencia.guardar(_votacion);
  }

  Future<void> _votar(String idOpcion) async {
    final resultado = _servicio.registrarVoto(
      idUsuario: _idUsuario,
      idOpcion: idOpcion,
    );
    if (resultado == ResultadoVoto.exitoso) {
      await _persistencia.guardar(_votacion);
      if (!mounted) return;
      setState(() => _yaVote = true);
    } else if (resultado == ResultadoVoto.usuarioYaVoto) {
      _mensaje('Ya registramos tu voto en este plebiscito.');
    } else if (resultado == ResultadoVoto.votacionCerrada) {
      _mensaje('Esta votación ya cerró.');
    } else if (resultado == ResultadoVoto.limiteAlcanzado) {
      _mensaje('Se alcanzó el límite máximo de $_limiteVotantes votantes.');
    }
  }

  Future<void> _simularOtroVecino() async {
    final nuevoId = await _persistencia.crearNuevoUsuario();
    if (!mounted) return;
    setState(() {
      _idUsuario = nuevoId;
      _yaVote = false;
    });
    _mensaje('Turno de un nuevo vecino para votar.');
  }

  Future<void> _reiniciarPlebiscito() async {
    await _persistencia.limpiar();
    final nuevoId = await _persistencia.obtenerOCrearIdUsuario();
    if (!mounted) return;
    setState(() {
      _esAnonima = false;
      _idUsuario = nuevoId;
      _yaVote = false;
      _inicializarVotacion(esAnonima: false);
    });
    _mensaje('Plebiscito reiniciado.');
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  void _verGanador() {
    final ganadores = _servicio.determinarGanador();
    final hayGanadorUnico = ganadores.length == 1;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ganador',
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final dialogo = ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              title: const Text('Resultado del plebiscito'),
              content: Text(
                hayGanadorUnico
                    ? 'La opción ganadora es:\n\n${ganadores.first.texto}'
                    : 'Hay un empate entre:\n\n${ganadores.map((g) => g.texto).join('\n')}',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        );

        if (!hayGanadorUnico) return dialogo;

        return Stack(children: [const ConfetiOverlay(), dialogo]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _servicio.obtenerResultados();
    final totalVotantes = _votacion.votantes.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plebiscito Vecinal - Dolores Hidalgo'),
        actions: [
          IconButton(
            onPressed: _simularOtroVecino,
            tooltip: 'Simular otro vecino',
            icon: const Icon(Icons.person_add),
          ),
          IconButton(
            onPressed: _reiniciarPlebiscito,
            tooltip: 'Reiniciar plebiscito',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _votacion.pregunta,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.how_to_vote),
                        title: Text(
                          'Participación: $totalVotantes / $_limiteVotantes votantes',
                        ),
                      ),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Modo votación anónima'),
                        subtitle: const Text(
                          'Solo registra que votaste, sin guardar tu opción',
                        ),
                        value: _esAnonima,
                        onChanged: totalVotantes == 0
                            ? _cambiarModoAnonimo
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...resultados.map(
                  (r) => _BarraOpcion(
                    resultado: r,
                    puedeVotar: !_yaVote && totalVotantes < _limiteVotantes,
                    onVotar: () => _votar(r.opcion.id),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _verGanador,
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('Ver resultado del plebiscito'),
                ),
              ],
            ),
    );
  }
}

class _BarraOpcion extends StatelessWidget {
  final ResultadoOpcion resultado;
  final bool puedeVotar;
  final VoidCallback onVotar;

  const _BarraOpcion({
    required this.resultado,
    required this.puedeVotar,
    required this.onVotar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  resultado.opcion.texto,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: resultado.porcentaje),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, valor, _) =>
                    Text('${valor.toStringAsFixed(0)}%'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 18,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: resultado.porcentaje / 100,
                    ),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, valor, _) => Container(
                      height: 18,
                      width: constraints.maxWidth * valor,
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          if (puedeVotar)
            OutlinedButton(
              onPressed: onVotar,
              child: const Text('Votar por esta opción'),
            ),
        ],
      ),
    );
  }
}
