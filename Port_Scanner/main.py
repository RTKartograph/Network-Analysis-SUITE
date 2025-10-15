import socket
import threading
import json

import pyfiglet
from rich.console import Console
from rich.table import Table

import sys

from utils import extract_json_data, threadpool_executer

console = Console()

class Pscan:

    PORTS_DATA_FILE = ".\common_ports.json"

    def __init__(self):
        self.ports_info = {}
        self.targets = []
        self.open_ports = {}
        self.remote_host = ""
    
    @staticmethod
    def show_startup_message():
        ascii_art = pyfiglet.figlet_format("-PortScanner-")
        console.print(f"[bold green4]{ascii_art}[/bold green4]")
        console.print("#" * 55, style="bold green")
        console.print("#" * 21, "Version 2.0!", "#" * 20, style="bold bright_green")
        console.print("#" * 8, "A simple Multithread TCP Port Scanner", "#" * 8, style="bold green")
        console.print("#" * 55, style="bold green")
        print()
    
    @staticmethod
    def get_host_ip(target):
        try:
            ip = socket.gethostbyname(target)
        except socket.gaierror as e:
            console.print(f"{e}. Exiting.", style="bold red")
            sys.exit()
        console.print(f"\nIP Address acquired: [bold blue]{ip}")
        return ip

    def get_ports_info(self):
        data = extract_json_data(Pscan.PORTS_DATA_FILE)
        self.ports_info = {int(k): v for (k, v) in data.items()}
    
    def scan_port(self, port):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        conn_status = sock.connect_ex((self.current_target, port))
        if conn_status == 0:
            self.open_ports[self.current_target].append(port)
        sock.close()
    
    def show_completion_message(self):
        print()
        for target, ports in self.open_ports.items():
            console.print(f"\nResults for target: [bold blue]{target}[/bold blue]", style="bold blue")
            if ports:
                table = Table(show_header=True, header_style="bold green")
                table.add_column("PORT", style="blue")
                table.add_column("STATE", justify="center", style="blue")
                table.add_column("SERVICE", style="blue")
                for port in ports:
                    # Check if there is at least one service description in the list.
                    if self.ports_info.get(port):
                        service_description = self.ports_info[port][0].get("description", "N/A")
                    else:
                        service_description = "N/A"
                    table.add_row(str(port), "OPEN", service_description)
                console.print(table)
            else:
                console.print("No Open Ports found on target", style="bold magenta")

    def initialize(self):
        self.show_startup_message()
        self.get_ports_info()
        try:
            target = console.input("[bold blue]Target(s): ")
        except KeyboardInterrupt:
            console.print(f"\nExiting the program.", style="bold red")
            sys.exit()

        if "," in target:
            self.targets = [t.strip() for t in target.split(",") if t.strip()]
        else:
            self.targets = [target]
        try:
            input("Port Scanner is primed. Press ENTER to activate.")
        except KeyboardInterrupt:
            console.print(f"\nExiting the program.", style="bold red")
            sys.exit()
        else:
            self.run()
    
    def run(self):
        total_targets = len(self.targets)
        for i, target in enumerate(self.targets, start=1):
            resolved_ip = self.get_host_ip(target)
            self.current_target = resolved_ip
            self.open_ports[resolved_ip] = []
            prefix = f"IP: {i}/{total_targets}"
            console.print(f"\nScanning target: [bold cyan]{resolved_ip}[/bold cyan]")
            threadpool_executer(
                self.scan_port,
                list(self.ports_info.keys()),
                len(self.ports_info.keys()),
                prefix=prefix
            )
        self.show_completion_message()

if __name__ == "__main__":
    pscan = Pscan()
    pscan.initialize()

    if getattr(sys, 'frozen', False):
        input("\nPress Enter to exit...")