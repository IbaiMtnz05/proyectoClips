; ==========================================================
; rules.clp
; Reglas del juego: inicializacion, turnos, jugadas, IA y fin.
; ==========================================================

; ---------- Inicializacion ----------

(defrule initialize-board
    ; Crea el tablero inicial con las cuatro fichas centrales.
    ?req <- (init-request (size ?n))
    (not (game))
    (test (>= ?n 4))
    (test (= (mod ?n 2) 0))
    =>
    (retract ?req)
    (clear-move-results)
    (clear-turn-events)
    (clear-render-requests)

    (assert (game (size ?n) (turn black) (status playing)))

    ; Cada jugador empieza con dos fichas en el centro.
    (bind ?initial-reserve (- (div (* ?n ?n) 2) 2))
    (assert (player (color black) (on-board 2) (reserve ?initial-reserve)))
    (assert (player (color white) (on-board 2) (reserve ?initial-reserve)))

    (bind ?mid1 (div ?n 2))
    (bind ?mid2 (+ ?mid1 1))

    ; Primero construimos todas las casillas vacias.
    (loop-for-count (?r 1 ?n)
        (loop-for-count (?c 1 ?n)
            (assert (cell (row ?r) (col ?c) (piece empty)))))

    ; Y despues colocamos la configuracion inicial tipica.
    (set-piece-at ?mid1 ?mid1 white)
    (set-piece-at ?mid1 ?mid2 black)
    (set-piece-at ?mid2 ?mid1 black)
    (set-piece-at ?mid2 ?mid2 white)

    (assert (recompute-valid-moves))
    (assert (render-request (message "Partida iniciada"))))

; ---------- Recalculo de jugadas ----------

(defrule rebuild-valid-moves
    ; Recalcula las jugadas posibles del turno actual.
    ?req <- (recompute-valid-moves)
    (game (size ?n) (turn ?turn) (status playing))
    =>
    (retract ?req)
    (clear-valid-moves)

    (loop-for-count (?r 1 ?n)
        (loop-for-count (?c 1 ?n)
            (if (is-valid-move ?r ?c ?turn ?n) then
                (assert (valid-move (row ?r) (col ?c) (color ?turn)))))))

; ---------- Estadisticas ----------

(defrule rebuild-player-stats
    ; Actualiza las fichas sobre el tablero de ambos jugadores.
    ?req <- (recompute-player-stats)
    =>
    (retract ?req)
    (refresh-player-onboard))

; ---------- Jugada del humano ----------

(defrule apply-move
    ; Procesa una peticion de jugada si es legal.
    (declare (salience 30))
    ?req <- (move-request (row ?r) (col ?c))
    ?g <- (game (size ?n) (turn ?turn) (status playing))
    ?p <- (player (color ?turn) (reserve ?reserve&:(> ?reserve 0)))
    =>
    (if (and (in-bounds ?r ?c ?n) (is-valid-move ?r ?c ?turn ?n)) then
        (retract ?req)
        (clear-move-results)
        (clear-render-requests)

        (set-piece-at ?r ?c ?turn)
        (modify ?p (reserve (- ?reserve 1)))

        (bind ?flipped 0)
        (bind ?flipped (+ ?flipped (flip-direction ?r ?c -1 -1 ?turn ?n)))
        (bind ?flipped (+ ?flipped (flip-direction ?r ?c -1  0 ?turn ?n)))
        (bind ?flipped (+ ?flipped (flip-direction ?r ?c -1  1 ?turn ?n)))
        (bind ?flipped (+ ?flipped (flip-direction ?r ?c  0 -1 ?turn ?n)))
        (bind ?flipped (+ ?flipped (flip-direction ?r ?c  0  1 ?turn ?n)))
        (bind ?flipped (+ ?flipped (flip-direction ?r ?c  1 -1 ?turn ?n)))
        (bind ?flipped (+ ?flipped (flip-direction ?r ?c  1  0 ?turn ?n)))
        (bind ?flipped (+ ?flipped (flip-direction ?r ?c  1  1 ?turn ?n)))

        ; Cambiamos de turno despues de ejecutar la jugada.
        (modify ?g (turn (opponent-color ?turn)))

        (assert (move-result (row ?r) (col ?c) (color ?turn) (status ok) (flipped ?flipped)))
        (assert (recompute-player-stats))
        (assert (recompute-valid-moves))
        (assert (render-request (message "Movimiento correcto")))))

(defrule reject-invalid-move
    ; Si la jugada no cumple las reglas, se rechaza sin tocar el tablero.
    ?req <- (move-request (row ?r) (col ?c))
    (game (turn ?turn) (status playing))
    =>
    (retract ?req)
    (clear-move-results)
    (clear-render-requests)
    (assert (move-result (row ?r) (col ?c) (color ?turn) (status invalid) (flipped 0)))
    (assert (render-request (message "Movimiento invalido"))))

; ---------- Flujo de turnos ----------

(defrule cede-piece-when-needed
    ; Regla de cesion: si el jugador actual no tiene reserva y el rival si,
    ; se transfiere una ficha para que el turno siga siendo jugable.
    (declare (salience 20))
    (game (size ?n) (turn ?turn) (status playing))
    (not (recompute-valid-moves))
    ?pcur <- (player (color ?turn) (reserve 0))
    ?popp <- (player (color ?opp) (reserve ?other-r&:(> ?other-r 0)))
    (test (eq ?opp (opponent-color ?turn)))
    (valid-move (color ?turn))
    =>
    (clear-turn-events)
    (clear-render-requests)
    (modify ?pcur (reserve 1))
    (modify ?popp (reserve (- ?other-r 1)))
    (assert (turn-event (type cede) (color ?turn) (info "El rival cede una ficha")))
    (assert (render-request (message "Cesion de ficha"))))

(defrule finish-game-when-board-full
    ; Si no quedan casillas vacias, termina la partida.
    (declare (salience 15))
    ?g <- (game (status playing))
    (not (recompute-valid-moves))
    (not (cell (piece empty)))
    =>
    (modify ?g (status finished))
    (assert (recompute-player-stats))
    (assert (turn-event (type game-over) (color draw) (info "Tablero lleno")))
    (assert (render-request (message "Fin de partida: tablero lleno"))))

(defrule finish-game-when-no-moves-both
    ; Si ningun jugador puede mover, la partida termina en ese instante.
    (declare (salience 14))
    ?g <- (game (size ?n) (turn ?turn) (status playing))
    (not (recompute-valid-moves))
    (not (valid-move (color ?turn)))
    (test (= (count-valid-moves-for (opponent-color ?turn) ?n) 0))
    =>
    (modify ?g (status finished))
    (assert (recompute-player-stats))
    (assert (turn-event (type game-over) (color draw) (info "Nadie puede mover")))
    (assert (render-request (message "Fin de partida: sin movimientos"))))

(defrule pass-turn-when-no-valid-moves
    ; Si el turno actual no tiene movimientos, pasa al rival.
    (declare (salience 10))
    ?g <- (game (size ?n) (turn ?turn) (status playing))
    (not (recompute-valid-moves))
    (not (valid-move (color ?turn)))
    (test (> (count-valid-moves-for (opponent-color ?turn) ?n) 0))
    =>
    (bind ?next (opponent-color ?turn))
    (clear-turn-events)
    (clear-render-requests)
    (modify ?g (turn ?next))
    (assert (turn-event (type pass) (color ?turn) (info "Sin jugadas validas: pasa turno")))
    (assert (recompute-valid-moves))
    (assert (render-request (message "Pasa el turno"))))

(defrule compute-final-result
    ; Una vez cerrada la partida, calcula quien gano.
    (declare (salience 5))
    (game (status finished))
    (not (game-result))
    =>
    (bind ?b (count-pieces black))
    (bind ?w (count-pieces white))
    (if (> ?b ?w) then
        (assert (game-result (winner black) (black-count ?b) (white-count ?w)))
     else
        (if (> ?w ?b) then
            (assert (game-result (winner white) (black-count ?b) (white-count ?w)))
         else
            (assert (game-result (winner draw) (black-count ?b) (white-count ?w)))))
    (clear-valid-moves))

; ---------- IA ----------

(defrule ai-play
    ; La IA elige la mejor jugada disponible y la convierte en una peticion normal.
    (declare (salience 25))
    ?req <- (ai-request (color ?who))
    (game (size ?n) (turn ?turn) (status playing))
    (test (eq ?who ?turn))
    (valid-move (color ?turn))
    =>
    (retract ?req)
    (bind ?choice (best-valid-move ?turn ?n))
    (bind ?r (nth$ 1 ?choice))
    (bind ?c (nth$ 2 ?choice))
    (if (and (> ?r 0) (> ?c 0)) then
        (clear-turn-events)
        (assert (turn-event (type ai-play) (color ?turn) (row ?r) (col ?c) (info "La IA elige la mejor jugada")))
        (assert (move-request (row ?r) (col ?c)))))

(defrule ai-ignore-when-no-move
    ; Si la IA no tiene jugadas, la peticion se consume sin hacer nada.
    ?req <- (ai-request (color ?who))
    (game (turn ?who) (status playing))
    (not (valid-move (color ?who)))
    =>
    (retract ?req))

; ---------- Salida por consola ----------

(defrule print-console-board
    ; Cada vez que se pide renderizar, imprimimos el estado actual.
    (declare (salience -100))
    ?req <- (render-request)
    =>
    (retract ?req)
    (render-board))