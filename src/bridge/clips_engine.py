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

    def facts_as_text(self) -> list[str]:
        return [str(fact) for fact in self.env.facts()]
