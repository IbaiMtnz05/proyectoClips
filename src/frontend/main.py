import pygame

from src.bridge.clips_engine import ClipsEngine


def main() -> None:
    pygame.init()

    width, height = 800, 800
    screen = pygame.display.set_mode((width, height))
    pygame.display.set_caption("Othello IA + CLIPS")

    engine = ClipsEngine()
    engine.load()
    engine.initialize_game(size=8)

    running = True
    clock = pygame.time.Clock()

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

        screen.fill((35, 120, 60))
        pygame.display.flip()
        clock.tick(60)

    pygame.quit()


if __name__ == "__main__":
    main()
