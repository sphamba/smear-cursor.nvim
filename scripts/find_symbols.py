from functools import cache
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from pprint import pprint


WIDTH = 9
HEIGHT = 19
FONT_SIZE = 16
UNICODE_RANGE = 0x10000
N_MATCHES = 20

font_directory = os.environ.get("FONT_DIRECTORY", "")
font = ImageFont.truetype(os.path.join(font_directory, "CascadiaCode.ttf"), FONT_SIZE)


@cache
def get_character_matrix(character: str, show: bool = False) -> np.ndarray:
    image = Image.new("L", (WIDTH, HEIGHT), color=0)  # "L" mode is grayscale
    context = ImageDraw.Draw(image)
    context.text((0, 0), character, fill=255, font=font)
    if show:
        image.show()

    numpy_array = np.array(image, dtype=np.float32) / 255.0
    return numpy_array


def show_matrix(matrix: np.ndarray):
    image = Image.fromarray((matrix * 255).astype(np.uint8))
    image.show()


def compute_difference(matrix1: np.ndarray, matrix2: np.ndarray) -> float:
    return float(np.sum(np.abs(matrix1 - matrix2)))
    # return float(np.sum((matrix1 - matrix2) ** 2))


def get_best_matches(target_matrix: np.ndarray) -> list[tuple[str, float]]:
    scores = {}

    for i in range(UNICODE_RANGE):
        character = chr(i)
        matrix = get_character_matrix(character)
        if np.sum(matrix) == 0:
            continue
        score = compute_difference(matrix, target_matrix)
        scores[character] = score

    sorted_scores = sorted(scores.items(), key=lambda x: x[1])
    return sorted_scores[:N_MATCHES]


def get_top_block_matrix(ratio: float) -> np.ndarray:
    matrix = np.zeros((HEIGHT, WIDTH), dtype=np.float32)
    matrix[:int(HEIGHT * ratio), :] = 1.0
    if ratio < 1.0:
        matrix[int(HEIGHT * ratio), :] = (HEIGHT * ratio) % 1
    return matrix


def get_right_block_matrix(ratio: float) -> np.ndarray:
    matrix = np.zeros((HEIGHT, WIDTH), dtype=np.float32)
    matrix[:, WIDTH - 1 - int(WIDTH * ratio):] = 1.0
    if ratio < 1.0:
        matrix[:, WIDTH - 1 - int(WIDTH * ratio)] = (WIDTH * ratio) % 1
    return matrix


if __name__ == "__main__":
    # To check render size
    matrix = get_character_matrix("█", show=True)


    for ratio in np.linspace(1/8, 7/8, 7):
        target_matrix = get_top_block_matrix(ratio)
        show_matrix(target_matrix)
        print(f"Top block ratio: {ratio}")
        best_matches = get_best_matches(target_matrix)
        pprint(best_matches)
        print()


    for ratio in np.linspace(1/8, 7/8, 7):
        target_matrix = get_right_block_matrix(ratio)
        show_matrix(target_matrix)
        print(f"Right block ratio: {ratio}")
        best_matches = get_best_matches(target_matrix)
        pprint(best_matches)
        print()
