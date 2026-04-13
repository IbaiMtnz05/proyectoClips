; =========================
; othello.clp - Proyecto completo
; Toda la logica del juego y de IA en CLIPS
; =========================

(deftemplate init-request
  (slot size (type INTEGER)))

(deftemplate game
  (slot size (type INTEGER))
  (slot turn (type SYMBOL) (allowed-symbols black white))
  (slot status (type SYMBOL) (allowed-symbols setup playing finished)))

(deftemplate cell
  (slot row (type INTEGER))
  (slot col (type INTEGER))
  (slot piece (type SYMBOL) (allowed-symbols empty black white)))

(deftemplate player
  (slot color (type SYMBOL) (allowed-symbols black white))
  (slot on-board (type INTEGER))
  (slot reserve (type INTEGER)))

(deftemplate valid-move
  (slot row (type INTEGER))
  (slot col (type INTEGER))
  (slot color (type SYMBOL) (allowed-symbols black white)))

(deftemplate recompute-valid-moves)
(deftemplate recompute-player-stats)

(deftemplate move-request
  (slot row (type INTEGER))
  (slot col (type INTEGER)))

(deftemplate move-result
  (slot row (type INTEGER))
  (slot col (type INTEGER))
  (slot color (type SYMBOL) (allowed-symbols black white))
  (slot status (type SYMBOL) (allowed-symbols ok invalid))
  (slot flipped (type INTEGER) (default 0)))

(deftemplate ai-request
  (slot color (type SYMBOL) (allowed-symbols black white) (default white)))

(deftemplate game-result
  (slot winner (type SYMBOL) (allowed-symbols black white draw))
  (slot black-count (type INTEGER))
  (slot white-count (type INTEGER)))

(deftemplate turn-event
  (slot type (type SYMBOL) (allowed-symbols pass cede ai-play game-over))
  (slot color (type SYMBOL) (allowed-symbols black white draw))
  (slot row (type INTEGER) (default 0))
  (slot col (type INTEGER) (default 0))
  (slot info (type STRING) (default "")))

; ---------- Utilidades basicas ----------

(deffunction opponent-color (?color)
  (if (eq ?color black) then
    (return white)
   else
    (return black)))

(deffunction in-bounds (?r ?c ?size)
  (if (and (>= ?r 1) (<= ?r ?size) (>= ?c 1) (<= ?c ?size)) then
    (return TRUE)
   else
    (return FALSE)))

(deffunction piece-at (?r ?c)
  (bind ?result unknown)
  (do-for-fact ((?cell cell))
               (and (= ?cell:row ?r) (= ?cell:col ?c))
    (bind ?result ?cell:piece))
  (return ?result))

(deffunction set-piece-at (?r ?c ?piece)
  (do-for-fact ((?cell cell))
               (and (= ?cell:row ?r) (= ?cell:col ?c))
    (modify ?cell (piece ?piece))))

(deffunction clear-move-results ()
  (do-for-all-facts ((?mr move-result)) TRUE
    (retract ?mr)))

(deffunction clear-turn-events ()
  (do-for-all-facts ((?ev turn-event)) TRUE
    (retract ?ev)))

(deffunction clear-valid-moves ()
  (do-for-all-facts ((?m valid-move)) TRUE
    (retract ?m)))

; ---------- Reglas de captura ----------

(deffunction direction-captures (?r ?c ?dr ?dc ?turn ?opp ?size)
  (bind ?nr (+ ?r ?dr))
  (bind ?nc (+ ?c ?dc))

  (if (not (in-bounds ?nr ?nc ?size)) then
    (return FALSE))
  (if (neq (piece-at ?nr ?nc) ?opp) then
    (return FALSE))

  (bind ?nr (+ ?nr ?dr))
  (bind ?nc (+ ?nc ?dc))

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
  (bind ?opp (opponent-color ?turn))

  (if (not (direction-captures ?r ?c ?dr ?dc ?turn ?opp ?size)) then
    (return 0))

  (bind ?count 0)
  (bind ?nr (+ ?r ?dr))
  (bind ?nc (+ ?c ?dc))

  (while (and (in-bounds ?nr ?nc ?size) (eq (piece-at ?nr ?nc) ?opp)) do
    (set-piece-at ?nr ?nc ?turn)
    (bind ?count (+ ?count 1))
    (bind ?nr (+ ?nr ?dr))
    (bind ?nc (+ ?nc ?dc)))

  (return ?count))

; ---------- Estadisticas ----------

(deffunction count-pieces (?color)
  (bind ?count 0)
  (do-for-all-facts ((?cell cell)) (eq ?cell:piece ?color)
    (bind ?count (+ ?count 1)))
  (return ?count))

(deffunction count-valid-moves-for (?color ?size)
  (bind ?count 0)
  (loop-for-count (?r 1 ?size)
    (loop-for-count (?c 1 ?size)
      (if (is-valid-move ?r ?c ?color ?size) then
        (bind ?count (+ ?count 1)))))
  (return ?count))

(deffunction board-has-empty ()
  (bind ?has FALSE)
  (do-for-fact ((?cell cell)) (eq ?cell:piece empty)
    (bind ?has TRUE))
  (return ?has))

(deffunction refresh-player-onboard ()
  (do-for-all-facts ((?p player)) TRUE
    (modify ?p (on-board (count-pieces ?p:color)))))

; ---------- Heuristica IA ----------

(deffunction is-corner (?r ?c ?size)
  (if (or
        (and (= ?r 1) (= ?c 1))
        (and (= ?r 1) (= ?c ?size))
        (and (= ?r ?size) (= ?c 1))
        (and (= ?r ?size) (= ?c ?size))) then
    (return TRUE)
   else
    (return FALSE)))

(deffunction adjacent-to-empty-corner (?r ?c ?size)
  (bind ?pen FALSE)

  (if (and (eq (piece-at 1 1) empty)
           (<= ?r 2) (<= ?c 2)
           (not (and (= ?r 1) (= ?c 1)))) then
    (bind ?pen TRUE))

  (if (and (eq (piece-at 1 ?size) empty)
           (<= ?r 2) (>= ?c (- ?size 1))
           (not (and (= ?r 1) (= ?c ?size)))) then
    (bind ?pen TRUE))

  (if (and (eq (piece-at ?size 1) empty)
           (>= ?r (- ?size 1)) (<= ?c 2)
           (not (and (= ?r ?size) (= ?c 1)))) then
    (bind ?pen TRUE))

  (if (and (eq (piece-at ?size ?size) empty)
           (>= ?r (- ?size 1)) (>= ?c (- ?size 1))
           (not (and (= ?r ?size) (= ?c ?size)))) then
    (bind ?pen TRUE))

  (return ?pen))

(deffunction evaluate-move (?r ?c ?turn ?size)
  (bind ?opp (opponent-color ?turn))

  ; Diferencia de fichas aproximada tras la jugada
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
   else
    (bind ?piece-diff (+ (- ?white ?black) (+ 1 (* 2 ?flips)))))

  ; Movilidad actual (aproximada)
  (bind ?mobility-diff (- (count-valid-moves-for ?turn ?size)
                          (count-valid-moves-for ?opp ?size)))

  ; Esquinas capturadas (valor alto)
  (bind ?corner-bonus 0)
  (if (is-corner ?r ?c ?size) then
    (bind ?corner-bonus 1))

  ; Penaliza jugar junto a una esquina vacia
  (bind ?adj-penalty 0)
  (if (adjacent-to-empty-corner ?r ?c ?size) then
    (bind ?adj-penalty 1))

  (return (+ (* 10 ?piece-diff)
             (* 6 ?mobility-diff)
             (* 30 ?corner-bonus)
             (* -20 ?adj-penalty))))

(deffunction best-valid-move (?turn ?size)
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

; ---------- Inicializacion ----------

(defrule initialize-board
  ?req <- (init-request (size ?n))
  (not (game))
  (test (>= ?n 4))
  (test (= (mod ?n 2) 0))
  =>
  (retract ?req)
  (clear-move-results)
  (clear-turn-events)

  (assert (game (size ?n) (turn black) (status playing)))

  (bind ?initial-reserve (- (div (* ?n ?n) 2) 2))
  (assert (player (color black) (on-board 2) (reserve ?initial-reserve)))
  (assert (player (color white) (on-board 2) (reserve ?initial-reserve)))

  (bind ?mid1 (div ?n 2))
  (bind ?mid2 (+ ?mid1 1))

  (loop-for-count (?r 1 ?n)
    (loop-for-count (?c 1 ?n)
      (bind ?piece empty)
      (if (and (= ?r ?mid1) (= ?c ?mid1)) then (bind ?piece white))
      (if (and (= ?r ?mid1) (= ?c ?mid2)) then (bind ?piece black))
      (if (and (= ?r ?mid2) (= ?c ?mid1)) then (bind ?piece black))
      (if (and (= ?r ?mid2) (= ?c ?mid2)) then (bind ?piece white))
      (assert (cell (row ?r) (col ?c) (piece ?piece)))))

  (assert (recompute-valid-moves)))

; ---------- Flujo de turno ----------

(defrule rebuild-valid-moves
  ?req <- (recompute-valid-moves)
  (game (size ?n) (turn ?turn) (status playing))
  =>
  (retract ?req)
  (clear-valid-moves)

  (loop-for-count (?r 1 ?n)
    (loop-for-count (?c 1 ?n)
      (if (is-valid-move ?r ?c ?turn ?n) then
        (assert (valid-move (row ?r) (col ?c) (color ?turn)))))))

(defrule cede-piece-when-needed
  (declare (salience 20))
  (game (size ?n) (turn ?turn) (status playing))
  (not (recompute-valid-moves))
  ?pcur <- (player (color ?turn) (reserve 0))
  ?popp <- (player (color ?opp) (reserve ?other-r&:(> ?other-r 0)))
  (test (eq ?opp (opponent-color ?turn)))
  (valid-move (color ?turn))
  =>
  (clear-turn-events)
  (modify ?pcur (reserve 1))
  (modify ?popp (reserve (- ?other-r 1)))
  (assert (turn-event (type cede) (color ?turn) (info "El rival cede una ficha"))))

(defrule finish-game-when-board-full
  (declare (salience 15))
  ?g <- (game (status playing))
  (not (recompute-valid-moves))
  (not (cell (piece empty)))
  =>
  (modify ?g (status finished))
  (assert (recompute-player-stats))
  (assert (turn-event (type game-over) (color draw) (info "Tablero lleno"))))

(defrule finish-game-when-no-moves-both
  (declare (salience 14))
  ?g <- (game (size ?n) (turn ?turn) (status playing))
  (not (recompute-valid-moves))
  (not (valid-move (color ?turn)))
  (test (= (count-valid-moves-for (opponent-color ?turn) ?n) 0))
  =>
  (modify ?g (status finished))
  (assert (recompute-player-stats))
  (assert (turn-event (type game-over) (color draw) (info "Nadie puede mover"))))

(defrule pass-turn-when-no-valid-moves
  (declare (salience 10))
  ?g <- (game (size ?n) (turn ?turn) (status playing))
  (not (recompute-valid-moves))
  (not (valid-move (color ?turn)))
  (test (> (count-valid-moves-for (opponent-color ?turn) ?n) 0))
  =>
  (bind ?next (opponent-color ?turn))
  (clear-turn-events)
  (modify ?g (turn ?next))
  (assert (turn-event (type pass) (color ?turn) (info "Sin jugadas validas: pasa turno")))
  (assert (recompute-valid-moves)))

(defrule compute-final-result
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

; ---------- Jugadas ----------

(defrule apply-move
  (declare (salience 30))
  ?req <- (move-request (row ?r) (col ?c))
  ?g <- (game (size ?n) (turn ?turn) (status playing))
  ?p <- (player (color ?turn) (reserve ?reserve&:(> ?reserve 0)))
  =>
  (if (and (in-bounds ?r ?c ?n) (is-valid-move ?r ?c ?turn ?n)) then
    (retract ?req)
    (clear-move-results)

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

    (modify ?g (turn (opponent-color ?turn)))

    (assert (move-result (row ?r) (col ?c) (color ?turn) (status ok) (flipped ?flipped)))
    (assert (recompute-player-stats))
    (assert (recompute-valid-moves))))

(defrule reject-invalid-move
  ?req <- (move-request (row ?r) (col ?c))
  (game (turn ?turn) (status playing))
  =>
  (retract ?req)
  (clear-move-results)
  (assert (move-result (row ?r) (col ?c) (color ?turn) (status invalid) (flipped 0))))

(defrule rebuild-player-stats
  ?req <- (recompute-player-stats)
  =>
  (retract ?req)
  (refresh-player-onboard))

; ---------- IA ----------

(defrule ai-play
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
    (assert (turn-event (type ai-play) (color ?turn) (row ?r) (col ?c) (info "IA elige mejor jugada")))
    (assert (move-request (row ?r) (col ?c)))))

(defrule ai-ignore-when-no-move
  ?req <- (ai-request (color ?who))
  (game (turn ?who) (status playing))
  (not (valid-move (color ?who)))
  =>
  (retract ?req))
