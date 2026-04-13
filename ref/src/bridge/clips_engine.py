from pathlib import Path

import clips


class ClipsEngine:
    def __init__(self) -> None:
        self.env = clips.Environment()
        self.knowledge_file = Path(__file__).resolve().parent.parent / "backend" / "othello.clp"

    def load(self) -> None:
        self.env.clear()
        self.env.load(str(self.knowledge_file))

    def initialize_game(self, size: int = 8) -> None:
        self.env.assert_string(f"(init-request (size {size}))")
        self.env.run()

    def play_move(self, row: int, col: int) -> None:
        self.env.assert_string(f"(move-request (row {row}) (col {col}))")
        self.env.run()

    def play_ai_turn(self, color: str = "white") -> None:
        self.env.assert_string(f"(ai-request (color {color}))")
        self.env.run()

    def facts_as_text(self) -> list[str]:
        return [str(fact) for fact in self.env.facts()]

    def get_state(self) -> dict:
        state = {
            "size": 8,
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

        for fact in self.env.facts():
            template = fact.template.name

            if template == "game":
                state["size"] = int(fact["size"])
                state["turn"] = str(fact["turn"])
                state["status"] = str(fact["status"])

            elif template == "cell":
                row = int(fact["row"])
                col = int(fact["col"])
                state["board"][(row, col)] = str(fact["piece"])

            elif template == "valid-move":
                row = int(fact["row"])
                col = int(fact["col"])
                state["valid_moves"].add((row, col))

            elif template == "player":
                color = str(fact["color"])
                state["players"][color] = {
                    "on_board": int(fact["on-board"]),
                    "reserve": int(fact["reserve"]),
                }

            elif template == "move-result":
                state["last_move"] = {
                    "row": int(fact["row"]),
                    "col": int(fact["col"]),
                    "color": str(fact["color"]),
                    "status": str(fact["status"]),
                    "flipped": int(fact["flipped"]),
                }

            elif template == "turn-event":
                state["event"] = {
                    "type": str(fact["type"]),
                    "color": str(fact["color"]),
                    "row": int(fact["row"]),
                    "col": int(fact["col"]),
                    "info": str(fact["info"]),
                }

            elif template == "game-result":
                state["result"] = {
                    "winner": str(fact["winner"]),
                    "black_count": int(fact["black-count"]),
                    "white_count": int(fact["white-count"]),
                }

        return state
