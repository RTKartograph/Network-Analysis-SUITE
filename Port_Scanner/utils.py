import json
from multiprocessing.pool import ThreadPool
import os

from rich.console import Console
from rich.jupyter import display

console = Console()

def display_progress(iteration, total, prefix=""):
    bar_max_width = 45
    bar_current_width = bar_max_width * iteration // total
    bar = "█" * bar_current_width + "-" * (bar_max_width - bar_current_width)
    progress = "%.1f" % (iteration / total * 100)
    console.print(f"{prefix} |{bar}| {progress} %", end="\r", style="bold green")
    if iteration == total:
        print()

def extract_json_data(filename):
    with open(filename, 'r') as file:
        data = json.load(file)
    return data

def threadpool_executer(function, iterable, iterable_len, prefix=""):
    number_of_workers = os.cpu_count() or 4
    console.print(f"Running using {number_of_workers} workers.\n", style="bold yellow")
    with ThreadPool(number_of_workers) as pool:
        for loop_index, _ in enumerate(pool.imap(function, iterable), 1):
            display_progress(loop_index, iterable_len, prefix=prefix)