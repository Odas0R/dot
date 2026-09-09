import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readdir } from "node:fs/promises";
import { join } from "node:path";

const run = promisify(execFile);
const OPTIONS = { timeout: 120000, maxBuffer: 2 * 1024 * 1024 };
const HARDENED_RUNTIME = 0x10000;
const REQUIRE_LIBRARY_VALIDATION = 0x2000;
export const SIGNING_PROFILE = "adhoc-no-runtime-v1";
export const SIGNING_NOTICE =
	"Enabling desktop CDP replaces Figma's vendor signatures with local ad-hoc signatures and disables hardened runtime for the patched app. macOS system protections are not changed. The complete original app is backed up. If the newly patched app fails to start and is no longer running, Figpie attempts to restore that matching backup. Continue?";

export async function inspectSigning(path, architecture) {
	const { stderr } = await run(
		"/usr/bin/codesign",
		["--display", "--verbose=4", ...(architecture ? ["--architecture", architecture] : []), path],
		OPTIONS,
	);
	const flags = stderr.match(/\bflags=(0x[0-9a-f]+)/i);
	const architectures = stderr.match(/^Format=.*Mach-O (?:thin|universal) \(([^)]+)\)$/m)?.[1].split(/\s+/);
	if (!flags || !architectures?.length || architectures.some((name) => !/^[a-z0-9_]+$/i.test(name)))
		throw new Error(`Could not read signing flags/architectures: ${path}`);
	return {
		architectures,
		adHoc: /^Signature=adhoc$/m.test(stderr),
		hardenedRuntime: Boolean(Number(flags[1]) & HARDENED_RUNTIME),
		libraryValidation: Boolean(Number(flags[1]) & REQUIRE_LIBRARY_VALIDATION),
		teamIdentifier: stderr.match(/^TeamIdentifier=(.+)$/m)?.[1] || null,
	};
}

export async function verifySignature(path) {
	await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", path], OPTIONS);
}

export async function verifyPatchedSignature(appPath) {
	await verifySignature(appPath);
	const frameworks = join(appPath, "Contents/Frameworks");
	const bundles = (await readdir(frameworks, { withFileTypes: true }))
		.filter((entry) => entry.isDirectory() && /\.(app|framework)$/.test(entry.name))
		.map((entry) => join(frameworks, entry.name));
	// A valid signature alone does not prove that dyld will accept its libraries.
	// Check the main app, Electron, and helper bundles for the exact failure we hit.
	if (!bundles.includes(join(frameworks, "Electron Framework.framework")))
		throw new Error("Electron framework was not found in the staged app");
	for (const path of [appPath, ...bundles]) {
		const native = await inspectSigning(path);
		const signatures =
			native.architectures.length === 1
				? [native]
				: await Promise.all(native.architectures.map((architecture) => inspectSigning(path, architecture)));
		if (signatures.some((signature) => !signature.adHoc || signature.hardenedRuntime || signature.libraryValidation)) {
			throw new Error(
				`Unsupported patched-app signature at ${path}: expected ad-hoc signing without hardened-runtime or library-validation flags in every architecture. Restore the original app before reconnecting.`,
			);
		}
	}
}

export async function signPatchedBundle(appPath) {
	// Ad-hoc signatures have no Figma Team ID. Retaining runtime/flags from the
	// vendor signature makes library validation reject Electron at launch.
	// Preserve entitlements (including JIT), but explicitly clear option flags.
	await run(
		"/usr/bin/codesign",
		["--force", "--deep", "--sign", "-", "--options", "0", "--preserve-metadata=identifier,entitlements", appPath],
		OPTIONS,
	);
	await verifyPatchedSignature(appPath);
}
