export function humanKittyError(message) {
	if (message.includes("Remote control is disabled")) {
		return "Kitty remote control is disabled. Set `allow_remote_control yes` in kitty.conf and restart Kitty.";
	}
	if (message.includes("i/o timeout")) {
		return "Kitty remote control timed out. Unset stale KITTY_LISTEN_ON/PI_KITTY_LISTEN_ON, or set PI_KITTY_LISTEN_ON to a live socket from `kitty --listen-on`.";
	}
	if (/env: .*kitty.*(?:No such file|not found)/i.test(message)) {
		return "Could not find `kitty`. Install Kitty and ensure it is on PATH.";
	}
	return message;
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export async function launchKitty(pi, {
	type = "window",
	cwd,
	title,
	copyEnv = false,
	env = {},
	command = [],
}) {
	const args = ["launch", "--no-response", "--type", type];
	if (cwd) args.push("--cwd", cwd);
	if (title) args.push("--title", title);
	if (copyEnv) args.push("--copy-env");
	if (process.env.KITTY_WINDOW_ID) args.push("--self");
	for (const [key, value] of Object.entries(env)) {
		if (value != null) args.push("--env", `${key}=${value}`);
	}
	args.push(...command);

	const { PI_KITTY_LISTEN_ON, KITTY_LISTEN_ON } = process.env;
	const targets = PI_KITTY_LISTEN_ON ? [PI_KITTY_LISTEN_ON] : [undefined];
	if (!PI_KITTY_LISTEN_ON && KITTY_LISTEN_ON) targets.push(KITTY_LISTEN_ON);

	const errors = [];
	for (const target of targets) {
		// Try the controlling TTY before the inherited socket unless explicitly overridden.
		const result = await pi.exec("env", [
			"-u", "KITTY_LISTEN_ON", "kitty", "@",
			...(target ? ["--to", target] : []),
			...args,
		]);
		if (result.code === 0 && !result.killed) return;
		const detail = result.stderr.trim() || result.stdout.trim() || (
			result.killed ? "kitty was killed" : `kitty exited with ${result.code}`
		);
		errors.push(`${target || "controlling terminal"}: ${detail}`);
	}
	throw new Error(errors.join("\n"));
}
