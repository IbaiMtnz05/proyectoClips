; =========================
; othello.clp - Paso 1
; Plantillas + regla de inicializacion
; =========================

(deftemplate init-request
  (slot size (type INTEGER))) ; Dimension N (par): 4,6,8,10,...

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

(deftemplate recompute-valid-moves)

(deftemplate valid-move
  (slot row (type INTEGER))
  (slot col (type INTEGER))
  (slot color (type SYMBOL) (allowed-symbols black white)))

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

(deffunction direction-captures (?r ?c ?dr ?dc ?turn ?opp ?size)
  (bind ?nr (+ ?r ?dr))
  (bind ?nc (+ ?c ?dc))

  ; La primera casilla en la direccion debe ser rival
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

(defrule initialize-board
  ?req <- (init-request (size ?n))
  (not (game))
  (test (>= ?n 4))
  (test (= (mod ?n 2) 0))
  =>
  (retract ?req)

  ; Estado general del juego
  (assert (game (size ?n) (turn black) (status playing)))

  ; Conteo inicial: 2 fichas en tablero por jugador, resto en reserva
  (bind ?initial-reserve (- (/ (* ?n ?n) 2) 2))
  (assert (player (color black) (on-board 2) (reserve ?initial-reserve)))
  (assert (player (color white) (on-board 2) (reserve ?initial-reserve)))

  ; Centro (coordenadas desde 1):
  ; (mid1,mid1)=white, (mid1,mid2)=black, (mid2,mid1)=black, (mid2,mid2)=white
  (bind ?mid1 (/ ?n 2))
  (bind ?mid2 (+ ?mid1 1))

  (loop-for-count (?r 1 ?n)
    (loop-for-count (?c 1 ?n)
      (if (and (= ?r ?mid1) (= ?c ?mid1)) then
        (assert (cell (row ?r) (col ?c) (piece white)))
      else
        (if (and (= ?r ?mid1) (= ?c ?mid2)) then
          (assert (cell (row ?r) (col ?c) (piece black)))
        else
          (if (and (= ?r ?mid2) (= ?c ?mid1)) then
            (assert (cell (row ?r) (col ?c) (piece black)))
          else
            (if (and (= ?r ?mid2) (= ?c ?mid2)) then
              (assert (cell (row ?r) (col ?c) (piece white)))
            else
              (assert (cell (row ?r) (col ?c) (piece empty))))))))))

  (assert (recompute-valid-moves)))

(defrule rebuild-valid-moves
  ?req <- (recompute-valid-moves)
  (game (size ?n) (turn ?turn) (status playing))
  =>
  (retract ?req)

  ; Limpia cache de jugadas validas del turno anterior
  (do-for-all-facts ((?m valid-move)) TRUE
    (retract ?m))

  ; Calcula jugadas validas para el jugador actual
  (loop-for-count (?r 1 ?n)
    (loop-for-count (?c 1 ?n)
      (if (is-valid-move ?r ?c ?turn ?n) then
        (assert (valid-move (row ?r) (col ?c) (color ?turn)))))))
