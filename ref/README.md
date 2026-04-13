# Proyecto Othello (Reversi) - IA + Sistemas Expertos

Arquitectura objetivo:
- Frontend: Python + Pygame
- Backend: CLIPS
- Puente: clipspy

La logica del juego se ejecuta en CLIPS:
- validacion de movimientos
- volteo de fichas
- cambio de turno y pases
- regla de cesion de ficha
- fin de partida y ganador
- agente IA heuristico

## Estructura
- `src/frontend/`: interfaz y controlador de eventos
- `src/backend/`: base de conocimiento CLIPS
- `src/bridge/`: integracion Python <-> CLIPS

## Instalacion
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Ejecucion (placeholder inicial)
```bash
python -m src.frontend.main
```

## Ejecucion con tamano de tablero
```bash
python -m src.frontend.main --size 8
python -m src.frontend.main --size 6
python -m src.frontend.main --size 10
```

Notas:
- Coordenadas de CLIPS y de clics comienzan en fila 1, columna 1.
- Jugador humano: negras.
- IA: blancas.
