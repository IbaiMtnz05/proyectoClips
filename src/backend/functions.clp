; ==========================================================
; functions.clp
; Funciones reutilizables: reglas de captura, heuristica de IA
; y salida por consola.
; ==========================================================

; ---------- Utilidades basicas ----------

(deffunction opponent-color (?color)
	; Devuelve el color contrario al recibido.
	(if (eq ?color black) then
		(return white)
	 else
		(return black)))

(deffunction in-bounds (?r ?c ?size)
	; Comprueba si una coordenada esta dentro del tablero.
	(if (and (>= ?r 1) (<= ?r ?size) (>= ?c 1) (<= ?c ?size)) then
		(return TRUE)
	 else
		(return FALSE)))

(deffunction piece-at (?r ?c)
	; Busca la ficha de una casilla concreta.
	(bind ?result unknown)
	(do-for-fact ((?cell cell)) (and (= ?cell:row ?r) (= ?cell:col ?c))
		(bind ?result ?cell:piece))
	(return ?result))

(deffunction set-piece-at (?r ?c ?piece)
	; Modifica una casilla ya creada.
	(do-for-fact ((?cell cell)) (and (= ?cell:row ?r) (= ?cell:col ?c))
		(modify ?cell (piece ?piece))))

(deffunction clear-move-results ()
	; Elimina el resultado anterior de jugada.
	(do-for-all-facts ((?mr move-result)) TRUE
		(retract ?mr)))

(deffunction clear-turn-events ()
	; Borra los eventos narrativos anteriores para no repetir mensajes.
	(do-for-all-facts ((?ev turn-event)) TRUE
		(retract ?ev)))

(deffunction clear-valid-moves ()
	; Limpia el listado de jugadas validas del turno actual.
	(do-for-all-facts ((?m valid-move)) TRUE
		(retract ?m)))

(deffunction clear-render-requests ()
	; Evita que se imprima mas de una vez la misma foto del tablero.
	(do-for-all-facts ((?r render-request)) TRUE
		(retract ?r)))

; ---------- Capturas y jugadas validas ----------

(deffunction direction-captures (?r ?c ?dr ?dc ?turn ?opp ?size)
	; Comprueba si en una direccion concreta se encierra al rival.
	(bind ?nr (+ ?r ?dr))
	(bind ?nc (+ ?c ?dc))

	; Check 1: la casilla ADYACENTE en esa direccion debe contener ficha rival (y no salir del tablero).
	(if (not (in-bounds ?nr ?nc ?size)) then
		(return FALSE))
	(if (neq (piece-at ?nr ?nc) ?opp) then
		(return FALSE))

	(bind ?nr (+ ?nr ?dr))
	(bind ?nc (+ ?nc ?dc))
	; Check 2: siguiendo en esa direccion, debe haber una ficha del jugador encerrando al rival (y sin salir del tablero).
	(while (in-bounds ?nr ?nc ?size) do
		(bind ?p (piece-at ?nr ?nc))
		(if (eq ?p ?opp) then
			(bind ?nr (+ ?nr ?dr))
			(bind ?nc (+ ?nc ?dc))
		 else
			(if (eq ?p ?turn) then
				(return TRUE)
			 else
				(return FALSE))))

	(return FALSE))

(deffunction is-valid-move (?r ?c ?turn ?size)
	; Una jugada es valida si la casilla esta vacia y captura al menos una ficha.
	(if (neq (piece-at ?r ?c) empty) then
		(return FALSE))

	(bind ?opp (opponent-color ?turn))

	(if (or
				(direction-captures ?r ?c -1 -1 ?turn ?opp ?size)
				(direction-captures ?r ?c -1  0 ?turn ?opp ?size)
				(direction-captures ?r ?c -1  1 ?turn ?opp ?size)
				(direction-captures ?r ?c  0 -1 ?turn ?opp ?size)
				(direction-captures ?r ?c  0  1 ?turn ?opp ?size)
				(direction-captures ?r ?c  1 -1 ?turn ?opp ?size)
				(direction-captures ?r ?c  1  0 ?turn ?opp ?size)
				(direction-captures ?r ?c  1  1 ?turn ?opp ?size)) then
		(return TRUE)
	 else
		(return FALSE)))

(deffunction count-flips-direction (?r ?c ?dr ?dc ?turn ?size)
	; Cuenta cuantas fichas se voltearian en una direccion.
	(bind ?opp (opponent-color ?turn))

	(if (not (direction-captures ?r ?c ?dr ?dc ?turn ?opp ?size)) then
		(return 0))

	(bind ?count 0)
	(bind ?nr (+ ?r ?dr))
	(bind ?nc (+ ?c ?dc))

	(while (and (in-bounds ?nr ?nc ?size) (eq (piece-at ?nr ?nc) ?opp)) do
		(bind ?count (+ ?count 1))
		(bind ?nr (+ ?nr ?dr))
		(bind ?nc (+ ?nc ?dc)))

	(return ?count))

(deffunction flip-direction (?r ?c ?dr ?dc ?turn ?size)
	; Voltea las fichas capturadas en una direccion concreta.
	(bind ?opp (opponent-color ?turn))
	; Si no se captura nada, no se hace nada.
	(if (not (direction-captures ?r ?c ?dr ?dc ?turn ?opp ?size)) then
		(return 0))

	(bind ?count 0)
	(bind ?nr (+ ?r ?dr))
	(bind ?nc (+ ?c ?dc))
	; Voltea las fichas del rival hasta llegar a una ficha propia.
	(while (and (in-bounds ?nr ?nc ?size) (eq (piece-at ?nr ?nc) ?opp)) do
		(set-piece-at ?nr ?nc ?turn)
		; Contamos cuantas volteamos para el resultado de la jugada.
		(bind ?count (+ ?count 1))
		(bind ?nr (+ ?nr ?dr))
		(bind ?nc (+ ?nc ?dc)))

	(return ?count))

; ---------- Estadisticas del tablero ----------

(deffunction count-pieces (?color)
	; Cuenta cuantas fichas de un color hay sobre el tablero.
	(bind ?count 0)
	(do-for-all-facts ((?cell cell)) (eq ?cell:piece ?color)
		(bind ?count (+ ?count 1)))
	(return ?count))

(deffunction count-valid-moves-for (?color ?size)
	; Cuenta cuantas jugadas validas tiene un color dado.
	(bind ?count 0)
	(loop-for-count (?r 1 ?size)
		(loop-for-count (?c 1 ?size)
			(if (is-valid-move ?r ?c ?color ?size) then
				(bind ?count (+ ?count 1)))))
	(return ?count))

(deffunction refresh-player-onboard ()
	; Actualiza la estadistica on-board de forma segura.
	; Evitamos modificar hechos dentro de un do-for-all-facts global,
	; porque puede provocar ciclos largos en algunas ejecuciones de CLIPS.
	(bind ?black-count (count-pieces black))
	(bind ?white-count (count-pieces white))

	(do-for-fact ((?pb player)) (eq ?pb:color black)
		(modify ?pb (on-board ?black-count)))

	(do-for-fact ((?pw player)) (eq ?pw:color white)
		(modify ?pw (on-board ?white-count))))

; ---------- Heuristica de la IA ----------

(deffunction is-corner (?r ?c ?size)
	; Detecta si una casilla es una esquina.
	(if (or
				(and (= ?r 1) (= ?c 1))
				(and (= ?r 1) (= ?c ?size))
				(and (= ?r ?size) (= ?c 1))
				(and (= ?r ?size) (= ?c ?size))) then
		(return TRUE)
	 else
		(return FALSE)))

(deffunction adjacent-to-corner (?r ?c ?size)
	; Penaliza jugar cerca de una esquina.
	(bind ?pen FALSE)

	(if (and 
					 (<= ?r 2) (<= ?c 2)
					 (not (and (= ?r 1) (= ?c 1)))) then
		(bind ?pen TRUE))

	(if (and 
					 (<= ?r 2) (>= ?c (- ?size 1))
					 (not (and (= ?r 1) (= ?c ?size)))) then
		(bind ?pen TRUE))

	(if (and 
					 (>= ?r (- ?size 1)) (<= ?c 2)
					 (not (and (= ?r ?size) (= ?c 1)))) then
		(bind ?pen TRUE))

	(if (and
					 (>= ?r (- ?size 1)) (>= ?c (- ?size 1))
					 (not (and (= ?r ?size) (= ?c ?size)))) then
		(bind ?pen TRUE))

	(return ?pen))

(deffunction evaluate-move (?r ?c ?turn ?size)
	; Puntuacion simple para que la IA elija una jugada decente.
	; Diferencia de fichas aproximada tras la jugada.
	(bind ?flips 0)
	(bind ?flips (+ ?flips (count-flips-direction ?r ?c -1 -1 ?turn ?size)))
	(bind ?flips (+ ?flips (count-flips-direction ?r ?c -1  0 ?turn ?size)))
	(bind ?flips (+ ?flips (count-flips-direction ?r ?c -1  1 ?turn ?size)))
	(bind ?flips (+ ?flips (count-flips-direction ?r ?c  0 -1 ?turn ?size)))
	(bind ?flips (+ ?flips (count-flips-direction ?r ?c  0  1 ?turn ?size)))
	(bind ?flips (+ ?flips (count-flips-direction ?r ?c  1 -1 ?turn ?size)))
	(bind ?flips (+ ?flips (count-flips-direction ?r ?c  1  0 ?turn ?size)))
	(bind ?flips (+ ?flips (count-flips-direction ?r ?c  1  1 ?turn ?size)))

	(bind ?black (count-pieces black))
	(bind ?white (count-pieces white))

	(bind ?piece-diff 0)
	(if (eq ?turn black) then
		(bind ?piece-diff (+ (- ?black ?white) (+ 1 (* 2 ?flips))))
		; El +1 es porque el jugador va a colocar una ficha mas, 
		; y el *2 es porque cada ficha volteada cambia la diferencia en 2.
	 else
		(bind ?piece-diff (+ (- ?white ?black) (+ 1 (* 2 ?flips)))))

	; Esquinas capturadas: valen mucho.
	(bind ?corner-bonus 0)
	(if (is-corner ?r ?c ?size) then
		(bind ?corner-bonus 1))

	; Penaliza jugar junto a una esquina vacia.
	(bind ?adj-penalty 0)
	(if (adjacent-to-corner ?r ?c ?size) then
		(bind ?adj-penalty 1))

	; Nota: evitamos recalcular movilidad en cada evaluacion para no
	; bloquear el modo interactivo en tableros grandes.
	(return (+ (* 12 ?piece-diff)
						 (* 120 ?corner-bonus)
						 (* -80 ?adj-penalty))))

(deffunction best-valid-move (?turn ?size)
	; Devuelve la mejor jugada encontrada por la heuristica.
	(bind ?best-r 0)
	(bind ?best-c 0)
	(bind ?best-score -999999)

	(do-for-all-facts ((?m valid-move)) (eq ?m:color ?turn)
		(bind ?score (evaluate-move ?m:row ?m:col ?turn ?size))
		(if (> ?score ?best-score) then
			(bind ?best-score ?score)
			(bind ?best-r ?m:row)
			(bind ?best-c ?m:col)))

	(return (create$ ?best-r ?best-c ?best-score)))

; ---------- Salida por consola ----------

(deffunction cell-mark (?r ?c)
	; Devuelve el simbolo textual de cada casilla para el modo terminal.
	; Se usan simbolos ASCII para evitar problemas de codificacion.
	(bind ?piece (piece-at ?r ?c))

	(if (eq ?piece black) then
		(return "X"))
	(if (eq ?piece white) then
		(return "O"))

	(do-for-fact ((?m valid-move)) (and (= ?m:row ?r) (= ?m:col ?c))
		(return "+"))

	(return "."))

(deffunction print-player-summary (?label ?color)
	; Imprime las fichas actuales de un jugador.
	(bind ?on-board 0)
	;(bind ?reserve 0)

	(do-for-fact ((?p player)) (eq ?p:color ?color)
		(bind ?on-board ?p:on-board)
		;(bind ?reserve ?p:reserve)
	)

	(printout t ?label ": tablero=" ?on-board crlf))

(deffunction print-valid-moves (?turn ?size)
	; Lista las jugadas posibles del turno actual.
	(bind ?count (count-valid-moves-for ?turn ?size))
	(printout t "Jugadas validas (" ?count "): ")

	(if (= ?count 0) then
		(printout t "ninguna" crlf)
	 else
		(do-for-all-facts ((?m valid-move)) (eq ?m:color ?turn)
			(printout t "(" ?m:row "," ?m:col ") "))
		(printout t crlf)))

(deffunction print-last-move ()
	; Si existe, muestra la ultima jugada procesada.
	(bind ?shown FALSE)
	(do-for-all-facts ((?m move-result)) TRUE
		(if (not ?shown) then
			(printout t "Ultima jugada: (" ?m:row "," ?m:col ") " ?m:color
									" -> " ?m:status " | volteadas=" ?m:flipped crlf)
			(bind ?shown TRUE))))

; (deffunction print-turn-event ()
; 	; Muestra el ultimo evento narrativo relevante.
; 	(bind ?shown FALSE)
; 	(do-for-all-facts ((?e turn-event)) TRUE
; 		(if (not ?shown) then
; 			(printout t "Evento: " ?e:type " | color=" ?e:color
; 									" | info=" ?e:info crlf)
; 			(bind ?shown TRUE))))

(deffunction print-game-result ()
	; Imprime el resultado final si la partida ya termino.
	(bind ?shown FALSE)
	(do-for-all-facts ((?r game-result)) TRUE
		(if (not ?shown) then
			(printout t "Resultado final: ganador=" ?r:winner
									" | negras=" ?r:black-count
									" | blancas=" ?r:white-count crlf)
			(bind ?shown TRUE))))

(deffunction pad-2 (?n)
	; Formatea numeros de 1 o 2 digitos para alinear la tabla ASCII.
	(if (< ?n 10) then
		(return (str-cat " " ?n))
	 else
		(return (str-cat ?n))))

(deffunction render-board ()
	; Dibuja por consola el tablero completo y el resumen del estado.
	; Método implementado por IA para mostrar el estado actual en modo texto.
	(bind ?size 8)
	(bind ?turn black)
	(bind ?status setup)

	(do-for-fact ((?g game)) TRUE
		(bind ?size ?g:size)
		(bind ?turn ?g:turn)
		(bind ?status ?g:status))

	(printout t crlf "==================================================" crlf)
	(printout t "Tamano: " ?size "x" ?size " | turno: " ?turn " | estado: " ?status crlf)
	(print-player-summary "Negras" black)
	(print-player-summary "Blancas" white)
	(print-valid-moves ?turn ?size)

	(printout t crlf "Tablero (X negras, O blancas, + jugada valida):" crlf)
	(printout t "   ")
	(loop-for-count (?c 1 ?size)
		(printout t (pad-2 ?c) " "))
	(printout t crlf)

	(loop-for-count (?r 1 ?size)
		(printout t (pad-2 ?r) " ")
		(loop-for-count (?c 1 ?size)
			(printout t " " (cell-mark ?r ?c) " "))
		(printout t crlf))

	(print-last-move)
	;(print-turn-event)
	(print-game-result)
	(printout t "==================================================" crlf))
