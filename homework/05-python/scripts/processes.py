import subprocess

def get_running_processes():
    result = subprocess.run(['ps', '-eo', 'pid,comm'], capture_output=True, text=True)
    lines = result.stdout.strip().split('\n')[1:]
    processes = []
    for line in lines:
        parts = line.split()
        if len(parts) >= 2:
            pid = parts[0]
            cmd = ' '.join(parts[1:])
            processes.append({"pid": pid, "cmd": cmd})
    return processes

if __name__ == '__main__':
    processes = get_running_processes()
    print(processes)