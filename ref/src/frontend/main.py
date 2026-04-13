import argparse
from typing import Optional

import pygame

from src.bridge.clips_engine import ClipsEngine


WINDOW_WIDTH = 920
WINDOW_HEIGHT = 820
BOARD_MARGIN = 40
PANEL_X = 760

GREEN_DARK = (20, 88, 52)
GREEN_LIGHT = (34, 122, 70)
GRID_COLOR = (16, 58, 36)
HINT_COLOR = (230, 200, 80)
BLACK_DISC = (24, 24, 24)
WHITE_DISC = (240, 240, 240)
BG_COLOR = (238, 232, 216)
TEXT_COLOR = (35, 35, 35)
ACCENT_COLOR = (184, 112, 55)
ACCENT_DARK = (116, 70, 34)
PANEL_BG = (246, 241, 230)
PANEL_BORDER = (205, 191, 170)
BUTTON_BG = (224, 214, 198)
BUTTON_ACTIVE = (196, 180, 156)
BUTTON_TEXT = (52, 42, 34)
FLIP_ANIMATION_MS = 420

BOARD_SIZES = [4, 6, 8, 10]


def board_geometry(size: int) -> tuple[int, int, int]:
    board_px = 680
    cell = board_px // size
    board_px = cell * size
    origin_x = BOARD_MARGIN
    origin_y = (WINDOW_HEIGHT - board_px) // 2
    return origin_x, origin_y, cell


def pixel_to_cell(mx: int, my: int, size: int) -> Optional[tuple[int, int]]:
    ox, oy, cell = board_geometry(size)
    bx = mx - ox
    by = my - oy
    if bx < 0 or by < 0:
        return None
    col = (bx // cell) + 1
    row = (by // cell) + 1
    if row < 1 or row > size or col < 1 or col > size:
        return None
    return int(row), int(col)


def point_in_rect(point: tuple[int, int], rect: pygame.Rect) -> bool:
    return rect.collidepoint(point)


def board_snapshot(state: dict) -> dict[tuple[int, int], str]:
    return dict(state["board"])


def diff_cells(before: dict[tuple[int, int], str], after: dict[tuple[int, int], str]) -> set[tuple[int, int]]:
    keys = set(before) | set(after)
    return {cell for cell in keys if before.get(cell, "empty") != after.get(cell, "empty")}


def draw_disc(
    screen: pygame.Surface,
    center: tuple[int, int],
    radius: int,
    piece: str,
    progress: float = 1.0,
    flipped: bool = False,
) -> None:
    if piece == "empty":
        return

    color = BLACK_DISC if piece == "black" else WHITE_DISC
    cx, cy = center

    if flipped:
        phase = max(0.0, min(1.0, progress))
        visible_piece = piece if phase >= 0.5 else ("white" if piece == "black" else "black")
        color = BLACK_DISC if visible_piece == "black" else WHITE_DISC
        squash = abs(1.0 - 2.0 * phase)
        width = max(3, int(radius * 2 * squash))
        height = max(3, int(radius * 2))
        rect = pygame.Rect(0, 0, width, height)
        rect.center = center
        pygame.draw.ellipse(screen, color, rect)
        pygame.draw.ellipse(screen, GRID_COLOR, rect, width=1)
        return

    scale = max(0.15, min(1.0, progress))
    width = max(3, int(radius * 2 * scale))
    height = max(3, int(radius * 2 * scale))
    rect = pygame.Rect(0, 0, width, height)
    rect.center = center
    pygame.draw.ellipse(screen, color, rect)
    pygame.draw.ellipse(screen, GRID_COLOR, rect, width=1)


def draw_button(
    screen: pygame.Surface,
    rect: pygame.Rect,
    label: str,
    font: pygame.font.Font,
    active: bool = False,
    disabled: bool = False,
) -> None:
    fill = BUTTON_ACTIVE if active else BUTTON_BG
    if disabled:
        fill = (214, 207, 196)

    pygame.draw.rect(screen, fill, rect, border_radius=14)
    pygame.draw.rect(screen, ACCENT_DARK, rect, width=2, border_radius=14)
    text_color = (140, 130, 120) if disabled else BUTTON_TEXT
    text = font.render(label, True, text_color)
    text_rect = text.get_rect(center=rect.center)
    screen.blit(text, text_rect)


def draw_panel_background(screen: pygame.Surface) -> None:
    panel_rect = pygame.Rect(PANEL_X - 18, 16, 138, WINDOW_HEIGHT - 32)
    pygame.draw.rect(screen, PANEL_BG, panel_rect, border_radius=18)
    pygame.draw.rect(screen, PANEL_BORDER, panel_rect, width=2, border_radius=18)


def draw_size_selector(
    screen: pygame.Surface,
    font: pygame.font.Font,
    selected_size: int,
    disabled: bool = False,
) -> dict[int, pygame.Rect]:
    buttons: dict[int, pygame.Rect] = {}
    x = PANEL_X
    y = 420
    title = font.render("Tamano", True, TEXT_COLOR)
    screen.blit(title, (x, y))
    y += 42
    for size in BOARD_SIZES:
        rect = pygame.Rect(x, y, 112, 42)
        buttons[size] = rect
        draw_button(screen, rect, f"{size} x {size}", font, active=(size == selected_size), disabled=disabled)
        y += 52
    return buttons


def draw_board(
    screen: pygame.Surface,
    state: dict,
    font: pygame.font.Font,
    small: pygame.font.Font,
    animation: Optional[dict] = None,
) -> None:
    size = state["size"]
    ox, oy, cell = board_geometry(size)
    board_px = cell * size
    radius = int(cell * 0.38)

    screen.fill(BG_COLOR)
    pygame.draw.rect(screen, GREEN_DARK, (ox, oy, board_px, board_px), border_radius=6)

    if animation is not None:
        before_board = animation["before_board"]
        after_board = animation["after_board"]
        changed = animation["changed_cells"]
        progress = animation["progress"]
    else:
        before_board = state["board"]
        after_board = state["board"]
        changed = set()
        progress = 1.0

    for r in range(size):
        for c in range(size):
            x = ox + c * cell
            y = oy + r * cell
            tone = GREEN_LIGHT if (r + c) % 2 == 0 else GREEN_DARK
            pygame.draw.rect(screen, tone, (x, y, cell, cell))
            pygame.draw.rect(screen, GRID_COLOR, (x, y, cell, cell), width=1)

            cell_key = (r + 1, c + 1)
            piece_before = before_board.get(cell_key, "empty")
            piece_after = after_board.get(cell_key, "empty")

            if cell_key in changed and animation is not None:
                if piece_before == "empty" and piece_after != "empty":
                    draw_disc(screen, (x + cell // 2, y + cell // 2), radius, piece_after, progress, flipped=False)
                elif piece_before != "empty" and piece_after != "empty":
                    draw_disc(screen, (x + cell // 2, y + cell // 2), radius, piece_after, progress, flipped=True)
            else:
                if piece_after != "empty":
                    draw_disc(screen, (x + cell // 2, y + cell // 2), radius, piece_after, 1.0, flipped=False)

    for row, col in state["valid_moves"]:
        cx = ox + (col - 1) * cell + cell // 2
        cy = oy + (row - 1) * cell + cell // 2
        pygame.draw.circle(screen, HINT_COLOR, (cx, cy), max(4, int(cell * 0.08)))

    draw_panel_background(screen)

    title = font.render("Othello", True, TEXT_COLOR)
    subtitle = small.render("Reversi con CLIPS", True, ACCENT_DARK)
    screen.blit(title, (PANEL_X, 28))
    screen.blit(subtitle, (PANEL_X, 62))

    turn_text = f"Turno: {state['turn']}"
    status_text = f"Estado: {state['status']}"
    b = state["players"]["black"]
    w = state["players"]["white"]
    stats = [
        turn_text,
        status_text,
        f"Negras tablero: {b['on_board']}",
        f"Blancas tablero: {w['on_board']}",
        f"Reserva negra: {b['reserve']}",
        f"Reserva blanca: {w['reserve']}",
        f"Mov. validos: {len(state['valid_moves'])}",
    ]

    y = 108
    for line in stats:
        txt = small.render(line, True, TEXT_COLOR)
        screen.blit(txt, (PANEL_X, y))
        y += 30

    if state["last_move"]:
        mv = state["last_move"]
        line = f"Ult: ({mv['row']},{mv['col']}) {mv['color']} {mv['status']}"
        txt = small.render(line, True, TEXT_COLOR)
        screen.blit(txt, (PANEL_X, y + 8))
        y += 36

    if state["event"]:
        ev = state["event"]
        line = f"Evento: {ev['type']} {ev['info']}"
        txt = small.render(line, True, TEXT_COLOR)
        screen.blit(txt, (PANEL_X, y + 8))
        y += 36

    if state["result"]:
        res = state["result"]
        line1 = f"Ganador: {res['winner']}"
        line2 = f"B:{res['black_count']} W:{res['white_count']}"
        screen.blit(small.render(line1, True, TEXT_COLOR), (PANEL_X, y + 8))
        screen.blit(small.render(line2, True, TEXT_COLOR), (PANEL_X, y + 34))


def draw_start_screen(
    screen: pygame.Surface,
    title_font: pygame.font.Font,
    font: pygame.font.Font,
    small: pygame.font.Font,
    selected_size: int,
) -> dict[str, object]:
    screen.fill(BG_COLOR)
    draw_panel_background(screen)

    title = title_font.render("Othello", True, TEXT_COLOR)
    subtitle = font.render("Selecciona tamano y empieza", True, ACCENT_DARK)
    desc_lines = [
        "Humano: negras",
        "IA: blancas",
        "CLIPS decide todas las reglas",
    ]

    screen.blit(title, (BOARD_MARGIN, 40))
    screen.blit(subtitle, (BOARD_MARGIN, 92))

    x = BOARD_MARGIN
    y = 170
    for line in desc_lines:
        screen.blit(small.render(line, True, TEXT_COLOR), (x, y))
        y += 28

    btns: dict[str, pygame.Rect] = {}
    btns["start"] = pygame.Rect(BOARD_MARGIN, 270, 220, 54)
    draw_button(screen, btns["start"], "Empezar partida", font, active=True)

    screen.blit(font.render("Tamano del tablero", True, TEXT_COLOR), (BOARD_MARGIN, 356))
    size_buttons: dict[int, pygame.Rect] = {}
    y = 406
    for size in BOARD_SIZES:
        rect = pygame.Rect(BOARD_MARGIN, y, 220, 44)
        size_buttons[size] = rect
        draw_button(screen, rect, f"{size} x {size}", font, active=(size == selected_size))
        y += 56

    screen.blit(small.render("Consejo: 8x8 es el modo clasico", True, ACCENT_DARK), (BOARD_MARGIN, 650))

    return {"start": btns["start"], "sizes": size_buttons}


def main() -> None:
    parser = argparse.ArgumentParser(description="Othello con CLIPS")
    parser.add_argument("--size", type=int, default=8, help="Dimension par del tablero")
    args = parser.parse_args()

    pygame.init()
    screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
    pygame.display.set_caption("Othello IA + CLIPS")
    font = pygame.font.SysFont("dejavuserif", 34)
    small = pygame.font.SysFont("dejavusansmono", 21)
    title_font = pygame.font.SysFont("dejavuserif", 58)

    engine = ClipsEngine()
    engine.load()
    selected_size = args.size if args.size in BOARD_SIZES else 8
    game_started = False
    pending_restart = False

    def start_game(size: int) -> None:
        nonlocal engine, animation, last_state, game_started, pending_restart
        engine = ClipsEngine()
        engine.load()
        engine.initialize_game(size=size)
        game_started = True
        pending_restart = False
        animation = None
        last_state = engine.get_state()

    human_color = "black"
    ai_color = "white"

    running = True
    clock = pygame.time.Clock()

    last_state = {"board": {}}
    animation: Optional[dict] = None

    while running:
        state = engine.get_state() if game_started else {
            "size": selected_size,
            "turn": "black",
            "status": "setup",
            "board": {},
            "valid_moves": set(),
            "players": {
                "black": {"on_board": 0, "reserve": 0},
                "white": {"on_board": 0, "reserve": 0},
            },
            "last_move": None,
            "event": None,
            "result": None,
        }

        if animation is not None:
            elapsed = pygame.time.get_ticks() - animation["start_ms"]
            progress = min(1.0, elapsed / FLIP_ANIMATION_MS)
            animation["progress"] = progress
            if progress >= 1.0:
                animation = None
                last_state = engine.get_state()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            if animation is not None:
                continue

            if not game_started:
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    ui = draw_start_screen(screen, title_font, font, small, selected_size)
                    size_buttons = ui["sizes"]
                    if ui["start"].collidepoint(event.pos):
                        start_game(selected_size)
                    else:
                        for size, rect in size_buttons.items():
                            if rect.collidepoint(event.pos):
                                selected_size = size
                                break
                continue

            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                if state["status"] != "playing" or state["turn"] != human_color:
                    continue

                restart_rect = pygame.Rect(PANEL_X, 700, 112, 40)
                if restart_rect.collidepoint(event.pos):
                    pending_restart = True
                    start_game(selected_size)
                    continue

                pos = pixel_to_cell(event.pos[0], event.pos[1], state["size"])
                if pos is not None:
                    before_board = board_snapshot(state)
                    row, col = pos
                    engine.play_move(row, col)
                    new_state = engine.get_state()
                    changed = diff_cells(before_board, new_state["board"])
                    if changed:
                        animation = {
                            "start_ms": pygame.time.get_ticks(),
                            "progress": 0.0,
                            "before_board": before_board,
                            "after_board": new_state["board"],
                            "changed_cells": changed,
                        }
                    last_state = new_state

        state = engine.get_state() if game_started else state
        if game_started and animation is None and state["status"] == "playing" and state["turn"] == ai_color:
            before_board = board_snapshot(state)
            engine.play_ai_turn(color=ai_color)
            new_state = engine.get_state()
            changed = diff_cells(before_board, new_state["board"])
            if changed:
                animation = {
                    "start_ms": pygame.time.get_ticks(),
                    "progress": 0.0,
                    "before_board": before_board,
                    "after_board": new_state["board"],
                    "changed_cells": changed,
                }
            last_state = new_state
            state = new_state

        if not game_started:
            ui = draw_start_screen(screen, title_font, font, small, selected_size)
            size_buttons = ui["sizes"]
            mx, my = pygame.mouse.get_pos()
            hover = ui["start"].collidepoint((mx, my))
            draw_button(screen, ui["start"], "Empezar partida", font, active=hover)
            for size, rect in size_buttons.items():
                draw_button(screen, rect, f"{size} x {size}", font, active=(size == selected_size))
        else:
            draw_board(screen, state, font, small, animation=animation)
            restart_rect = pygame.Rect(PANEL_X, 700, 112, 40)
            mx, my = pygame.mouse.get_pos()
            draw_button(screen, restart_rect, "Reiniciar", small, active=restart_rect.collidepoint((mx, my)))
        pygame.display.flip()
        clock.tick(60)

    pygame.quit()


if __name__ == "__main__":
    main()
