import { spawn } from "node:child_process";

export function errorMessage(error) {
	return error instanceof Error ? error.message : String(error);
}

export function shellQuote(value) {
	return `'${String(value).replace(/'/g, `'"'"'`)}'`;
}

export function exec(command, args = [], options = {}) {
	return new Promise((resolve, reject) => {
		const child = spawn(command, args, {
			cwd: options.cwd,
			env: options.env,
			shell: false,
			stdio: [options.input === undefined ? "ignore" : "pipe", "pipe", "pipe"],
			signal: options.signal,
		});

		let stdout = "";
		let stderr = "";
		let settled = false;

		child.stdout.on("data", (chunk) => {
			stdout += String(chunk);
		});
		child.stderr.on("data", (chunk) => {
			stderr += String(chunk);
		});
		child.on("error", (error) => {
			if (settled) return;
			settled = true;
			reject(error);
		});
		child.on("close", (code, signal) => {
			if (settled) return;
			settled = true;

			const result = { code: code ?? 1, signal, stdout, stderr };
			if (result.code === 0 || options.allowFailure) {
				resolve(result);
				return;
			}

			const detail = (stderr || stdout || `${command} exited with ${result.code}`).trim();
			reject(new Error(detail));
		});

		if (options.input !== undefined) {
			child.stdin.end(options.input);
		}
	});
}
