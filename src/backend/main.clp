; ==========================================================
; main.clp
; Punto de arranque en CLIPS puro.
; Incluye un menu interactivo para jugar por terminal.
;
; Uso recomendado desde el prompt de CLIPS:
;   (load "backend/templates.clp")
;   (load "backend/functions.clp")
;   (load "backend/rules.clp")
;   (load "backend/main.clp")
;   (terminal-menu)
;


;   (load "src/backend/templates.clp")
;   (load "src/backend/functions.clp")
;   (load "src/backend/rules.clp")
;   (load "src/backend/main.clp")
;   (terminal-menu)
; Si prefieres, puedes cargar primero todo y luego llamar a
; (start-game 6) o (start-game 10).
; ==========================================================

(deffunction game-status ()
	; Devuelve el estado actual de la partida.
	(bind ?status setup)
	(do-for-fact ((?g game)) TRUE
		(bind ?status ?g:status))
	(return ?status))

(deffunction game-turn ()
	; Devuelve de quien es el turno actual.
	(bind ?turn black)
	(do-for-fact ((?g game)) TRUE
		(bind ?turn ?g:turn))
	(return ?turn))

(deffunction menu-option-to-size (?opt)
	; Convierte una opcion numerica de menu al tamano de tablero.
	(if (= ?opt 1) then (return 4))
	(if (= ?opt 2) then (return 6))
	(if (= ?opt 3) then (return 8))
	(if (= ?opt 4) then (return 10))
	(return 0))

(deffunction ask-board-size ()
	; Pregunta al usuario el tamano del tablero con opciones numericas.
	(bind ?size 0)
	(while (= ?size 0) do
		(printout t crlf "===== MENU PRINCIPAL =====" crlf)
		(printout t "Elige tamano de tablero:" crlf)
		(printout t "  1) 4x4" crlf)
		(printout t "  2) 6x6" crlf)
		(printout t "  3) 8x8" crlf)
		(printout t "  4) 10x10" crlf)
		(printout t "Opcion: ")
		(bind ?opt (read))
		(bind ?size (menu-option-to-size ?opt))

		(if (= ?size 0) then
			(printout t "Opcion invalida. Escribe 1, 2, 3 o 4." crlf)))

	(return ?size))

(deffunction start-game (?size)
	; Arranca una partida nueva por consola.
	(if (or (< ?size 4) (neq (mod ?size 2) 0)) then
		(printout t "El tamano debe ser par y mayor o igual que 4." crlf)
		(return FALSE))

	(reset)
	(assert (init-request (size ?size)))
	(run)
	(return TRUE))
;Este atajo se ha reemplazado por el menu interactivo completo 

(deffunction play-human (?row ?col)
	; Atajo para jugar una ficha desde el prompt de CLIPS.
	(assert (move-request (row ?row) (col ?col)))
	(run))

(deffunction play-ai (?color)
	; Atajo para pedir una jugada a la IA.
	(assert (ai-request (color ?color)))
	(run))

(deffunction parse-row-col (?line)
	; Convierte un texto "fila,columna" en dos enteros.
	; Si el formato no es valido devuelve 0,0.
	(bind ?comma-pos (str-index "," ?line))
	(if (eq ?comma-pos FALSE) then
		(return (create$ 0 0)))

	(bind ?len (str-length ?line))
	(if (or (<= ?comma-pos 1) (>= ?comma-pos ?len)) then
		(return (create$ 0 0)))

	(bind ?row-text (sub-string 1 (- ?comma-pos 1) ?line))
	(bind ?col-text (sub-string (+ ?comma-pos 1) ?len ?line))

	(bind ?row (string-to-field ?row-text))
	(bind ?col (string-to-field ?col-text))

	(if (or (not (integerp ?row)) (not (integerp ?col))) then
		(return (create$ 0 0)))

	(if (or (<= ?row 0) (<= ?col 0)) then
		(return (create$ 0 0)))

	(return (create$ ?row ?col)))

(deffunction play-human-from-line (?line)
	; Lee una jugada del formato "fila,columna" y la juega.
	(bind ?coords (parse-row-col ?line))
	(bind ?row (nth$ 1 ?coords))
	(bind ?col (nth$ 2 ?coords))

	(if (or (= ?row 0) (= ?col 0)) then
		(printout t "Formato invalido. Usa: fila,columna  (ejemplo: 3,4)" crlf)
	 else
		(play-human ?row ?col)))

(deffunction show-command-help ()
	; Ayuda rapida de comandos del modo interactivo.
	(printout t crlf "Comandos disponibles:" crlf)
	(printout t "  fila,columna  -> jugar en esa casilla (ej: 3,4)" crlf)
	(printout t "  help          -> mostrar ayuda" crlf)
	(printout t "  quit          -> salir al prompt de CLIPS" crlf))

(deffunction terminal-menu ()
	; Modo principal de juego por terminal.
	(bind ?size (ask-board-size))
	(start-game ?size)
	(show-command-help)
	;(render-board)

	(while (neq (game-status) finished) do
		(if (eq (game-turn) black) then
			(printout t crlf "Turno humano (black). Escribe fila,columna: ")
			(bind ?line (readline))

			(if (eq ?line "quit") then
				(printout t "Saliendo del modo interactivo." crlf)
				(return TRUE))

			(if (eq ?line "help") then
				(show-command-help)
			 else
				(play-human-from-line ?line))
		 else
			(printout t crlf "Turno de la IA (white)..." crlf)
			(play-ai white)))

	(printout t crlf "Partida finalizada." crlf)
	(return TRUE))
