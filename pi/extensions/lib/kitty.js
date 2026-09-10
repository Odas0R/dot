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

export function kittySocketAddress(savedAddress) {
	// A live Kitty window is authoritative for new work. A global override can
	// point at another Kitty process when several instances are running.
	const currentAddress = process.env.KITTY_WINDOW_ID
		? process.env.KITTY_LISTEN_ON
		: undefined;
	const address =
		savedAddress ||
		currentAddress ||
		process.env.PI_KITTY_LISTEN_ON ||
		process.env.KITTY_LISTEN_ON;
	if (!address) {
		throw new Error(
			"Kitty requires a remote-control socket. Add `listen_on unix:kitty-{kitty_pid}` to kitty.conf and fully restart Kitty, or set PI_KITTY_LISTEN_ON to a live socket.",
		);
	}
	return address;
}

export function currentKittyWindowId() {
	const value = process.env.KITTY_WINDOW_ID;
	if (value === undefined) return undefined;
	const id = Number(value);
	if (!Number.isSafeInteger(id) || id < 1)
		throw new Error(`Invalid KITTY_WINDOW_ID: ${value}`);
	return id;
}

export function kittyArgs(address, ...args) {
	// Replies over the controlling TTY can be consumed by Pi as keyboard input.
	if (!address)
		throw new Error("Refusing Kitty remote control without a socket address.");
	return ["-u", "KITTY_LISTEN_ON", "kitty", "@", "--to", address, ...args];
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export async function checkKittyConnection(
	pi,
	address,
	sourceWindowId,
	signal,
	{ timeout = 5_000 } = {},
) {
	signal?.throwIfAborted();
	const result = await pi.exec(
		"env",
		kittyArgs(
			address,
			"ls",
			...(sourceWindowId ? ["--match", `id:${sourceWindowId}`] : []),
		),
		{ signal, timeout },
	);
	if (result.code !== 0 || result.killed) {
		throw new Error(
			humanKittyError(
				`${address}: ${result.stderr.trim() || "Could not contact Kitty."}`,
			),
		);
	}
	if (!sourceWindowId) return;

	let windows;
	try {
		windows = JSON.parse(result.stdout).flatMap((osWindow) =>
			osWindow.tabs.flatMap((tab) => tab.windows),
		);
	} catch {
		throw new Error("Kitty returned an invalid window inventory.");
	}
	const source = windows.find((window) => window.id === sourceWindowId);
	if (!source)
		throw new Error(
			`The current Kitty window ${sourceWindowId} does not belong to ${address}.`,
		);
	if (
		process.env.KITTY_PID &&
		String(source.env?.KITTY_PID) !== process.env.KITTY_PID
	)
		throw new Error(
			`The remote-control socket belongs to Kitty ${source.env?.KITTY_PID || "unknown"}, not the current Kitty ${process.env.KITTY_PID}.`,
		);
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export async function launchKitty(pi, {
	type = "window",
	cwd,
	title,
	tabTitle,
	copyEnv = false,
	env = {},
	vars = {},
	command = [],
	address,
	sourceWindowId,
	keepFocus = false,
	hold = false,
	response = false,
	signal,
	timeout,
}) {
	const args = ["launch"];
	if (!response) args.push("--no-response");
	args.push("--type", type);
	if (sourceWindowId) {
		args.push("--match", `window_id:${sourceWindowId}`);
		args.push("--source-window", `id:${sourceWindowId}`);
	} else if (process.env.KITTY_WINDOW_ID) args.push("--self");
	if (keepFocus) args.push("--dont-take-focus");
	if (hold) args.push("--hold");
	if (cwd) args.push("--cwd", cwd);
	if (title) args.push("--title", title);
	if (tabTitle) args.push("--tab-title", tabTitle);
	if (copyEnv) args.push("--copy-env");
	for (const [key, value] of Object.entries(env)) {
		if (value != null) args.push("--env", `${key}=${value}`);
	}
	for (const [key, value] of Object.entries(vars)) {
		if (value != null) args.push("--var", `${key}=${value}`);
	}
	args.push(...command);

	const { PI_KITTY_LISTEN_ON, KITTY_LISTEN_ON } = process.env;
	const targets = address
		? [address]
		: PI_KITTY_LISTEN_ON
			? [PI_KITTY_LISTEN_ON]
			: [undefined, ...(KITTY_LISTEN_ON ? [KITTY_LISTEN_ON] : [])];

	const errors = [];
	for (const target of targets) {
		// Try the controlling TTY before the inherited socket unless explicitly overridden.
		const result = await pi.exec(
			"env",
			[
				"-u",
				"KITTY_LISTEN_ON",
				"kitty",
				"@",
				...(target ? ["--to", target] : []),
				...args,
			],
			{ signal, timeout },
		);
		if (result.code === 0 && !result.killed) return result;
		const detail =
			result.stderr.trim() ||
			result.stdout.trim() ||
			(result.killed ? "kitty was killed" : `kitty exited with ${result.code}`);
		errors.push(`${target || "controlling terminal"}: ${detail}`);
	}
	throw new Error(errors.join("\n"));
}
