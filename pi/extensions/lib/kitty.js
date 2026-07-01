import { errorMessage, exec } from "./shell.js";

export function cleanKittyRemoteEnv(env = process.env) {
	const cleanEnv = { ...env };
	delete cleanEnv.KITTY_LISTEN_ON;
	return cleanEnv;
}

export function humanKittyError(message) {
	if (message.includes("Remote control is disabled")) {
		return "Kitty remote control is disabled. Add `allow_remote_control yes` to kitty.conf, then fully restart kitty. If Pi is not running in a kitty-controlled TTY, set PI_KITTY_LISTEN_ON to a socket started with kitty --listen-on.";
	}
	if (message.includes("i/o timeout")) {
		return "Kitty remote control timed out. Pi tried to contact Kitty but no Kitty instance answered. If you are inside Kitty, this is usually a stale KITTY_LISTEN_ON/PI_KITTY_LISTEN_ON from tmux or an old shell; unset it or set PI_KITTY_LISTEN_ON to a live socket from `kitty --listen-on`.";
	}
	if (message.includes("ENOENT") || message.includes("spawn kitty")) {
		return "Could not find `kitty`. Install Kitty or run the printed command manually.";
	}
	return message;
}

function pushEnvArgs(args, env) {
	for (const [key, value] of Object.entries(env ?? {})) {
		if (value === undefined || value === null) continue;
		args.push("--env", `${key}=${value}`);
	}
}

export function buildKittyLaunchArgs(options, listenOn) {
	const processEnv = options.processEnv ?? process.env;
	const {
		type = "window",
		cwd,
		title,
		tabTitle,
		copyEnv = false,
		env = {},
		self = "auto",
		command = [],
		extraArgs = [],
		noResponse = true,
	} = options;

	const args = ["@"];
	if (listenOn) args.push("--to", listenOn);

	args.push("launch");
	if (noResponse) args.push("--no-response");
	args.push("--type", type);
	if (cwd) args.push("--cwd", cwd);
	if (copyEnv) args.push("--copy-env");
	pushEnvArgs(args, env);
	if (title) args.push("--title", title);
	if (tabTitle) args.push("--tab-title", tabTitle);
	if (self === true || (self === "auto" && processEnv.KITTY_WINDOW_ID)) {
		args.push("--self");
	}
	args.push(...extraArgs);
	args.push(...command);
	return args;
}

async function execKittyLaunch(options, listenOn) {
	await exec("kitty", buildKittyLaunchArgs(options, listenOn), {
		env: cleanKittyRemoteEnv(options.processEnv ?? process.env),
	});
}

export async function launchKitty(options) {
	const processEnv = options.processEnv ?? process.env;
	const explicitListenOn = processEnv.PI_KITTY_LISTEN_ON;
	if (explicitListenOn) {
		await execKittyLaunch(options, explicitListenOn);
		return;
	}

	const errors = [];
	try {
		await execKittyLaunch(options, undefined);
		return;
	} catch (error) {
		errors.push(`controlling terminal: ${errorMessage(error)}`);
	}

	if (processEnv.KITTY_LISTEN_ON) {
		try {
			await execKittyLaunch(options, processEnv.KITTY_LISTEN_ON);
			return;
		} catch (error) {
			errors.push(`KITTY_LISTEN_ON: ${errorMessage(error)}`);
		}
	}

	throw new Error(errors.join("\n"));
}
