; ==========================================================
; templates.clp
; Estructura de hechos del juego Othello/Reversi.
; Aqui solo definimos los datos; la logica vive en rules.clp
; y las utilidades en functions.clp.
; ==========================================================

;=====================================================
; Bases del juego: tablero, jugadores, estado global.
(deftemplate game
    ; Estado global de la partida.
    (slot size (type INTEGER))
    (slot turn (type SYMBOL) (allowed-symbols black white))
    (slot status (type SYMBOL) (allowed-symbols setup playing finished)))

(deftemplate cell
    ; Una casilla del tablero. La coordenada empieza en 1.
    (slot row (type INTEGER))
    (slot col (type INTEGER))
    (slot piece (type SYMBOL) (allowed-symbols empty black white)))

(deftemplate player
    ; Contador de fichas de cada color.
    (slot color (type SYMBOL) (allowed-symbols black white))
    (slot on-board (type INTEGER))
    ;(slot reserve (type INTEGER))
    ; La reserva de fichas no se usara en esta implementacion
    )

; =====================================================
; Desarrollo de la partida: jugadas, eventos, resultados, etc.
(deftemplate init-request
    ; Peticion para arrancar una nueva partida con un tamano concreto.
    (slot size (type INTEGER)))

(deftemplate valid-move
    ; Jugadas validas para el turno actual.
    (slot row (type INTEGER))
    (slot col (type INTEGER))
    (slot color (type SYMBOL) (allowed-symbols black white)))

(deftemplate move-request
    ; Peticion de jugada humana o de la IA.
    (slot row (type INTEGER))
    (slot col (type INTEGER)))

(deftemplate move-result
    ; Resultado de la ultima jugada procesada.
    (slot row (type INTEGER))
    (slot col (type INTEGER))
    (slot color (type SYMBOL) (allowed-symbols black white))
    (slot status (type SYMBOL) (allowed-symbols ok invalid))
    (slot flipped (type INTEGER) (default 0)))

(deftemplate ai-request
    ; Peticion para que juegue la IA.
    (slot color (type SYMBOL) (allowed-symbols black white) (default white)))

(deftemplate game-result
    ; Resultado final de la partida.
    (slot winner (type SYMBOL) (allowed-symbols black white draw))
    (slot black-count (type INTEGER))
    (slot white-count (type INTEGER)))

(deftemplate turn-event
    ; Eventos narrativos: pase de turno, IA, fin.
    (slot type (type SYMBOL) (allowed-symbols pass ai-play game-over))
    (slot color (type SYMBOL) (allowed-symbols black white draw))
    (slot row (type INTEGER) (default 0))
    (slot col (type INTEGER) (default 0))
    (slot info (type STRING) (default "")))

(deftemplate recompute-valid-moves
    ; Marca que hay que recalcular las jugadas validas.
)

(deftemplate recompute-player-stats
    ; Marca que hay que recalcular las fichas sobre el tablero.
)

(deftemplate render-request
    ; Cuando aparece este hecho, se imprime el estado actual por consola.
    (slot message (type STRING) (default "")))