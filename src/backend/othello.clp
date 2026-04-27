(deftemplate init-request
    (slot size (type INTEGER))
)

(deftemplate game
    (slot size (type INTEGER))
    (slot turn (type INTEGER))
    (slot status (type SYMBOL) (allowed-symbols setup playing finished))
)

(deftemplate cell
    (slot row (type INTEGER))
    (slot col (type INTEGER))
    (slot piece (type INTEGER) (allowed-symbols -1 0 1))
)

(deftemplate player
    (slot color (type INTEGER) (allowed-symbols -1 1))
    (slot pieces (type INTEGER))
)

(deftemplate legal-moves
    (slot row (type INTEGER))
    (slot col (type INTEGER))
    (slot piece (type INTEGER) (allowed-symbols -1 0 1))
)

(defrule init-board
    ?req <- (init-request (size ?n))
    (not (game))
    (test (>= ?n 4))
    (test (= (mod ?n 2) 0))
    =>

    (retract ?req)

    (assert (game (size ?n) (turn -1) (status playing)))

    (assert (player (color -1) (pieces 2)))
    (assert (player (color 1) (pieces 2)))

    (loop-for-count (?r 1 ?n)
        ; Bucle para las columnas
        (loop-for-count (?c 1 ?n)
            ; Creamos cada casilla con estado 0
            (assert (cell (row ?r) (col ?c) (piece 0)))
        )
    )
    (modify (cell (row (/ ?n 2)) (col (/ ?n 2)) (piece 1)))
    (modify (cell (row (+(/ ?n 2)) 1) (col (/ ?n 2)) (piece -1)))
    (modify (cell (row (/ ?n 2)) (col (+(/ ?n 2)) 1) (piece -1)))
    (modify (cell (row (+(/ ?n 2)) 1) (col (+(/ ?n 2)) 1) (piece 1)))
    

)
