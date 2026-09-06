// Keep plugin/code.js and plugin/ui.html wire constants in sync (covered by tests).
export const PROTOCOL_VERSION = 2;
export const PORT = 3846;
export const HOST = "127.0.0.1";
export const PATH = "/figma-use";
export const BRIDGE_URL = `ws://${HOST}:${PORT}${PATH}`;
export const MAX_PAYLOAD_BYTES = 20 * 1024 * 1024;
export const MAX_MESSAGE_BYTES = 16 * 1024 * 1024;
export const MAX_CODE_BYTES = 1024 * 1024;
export const MAX_IMAGE_BYTES = 8 * 1024 * 1024; // Aggregate base64 bytes, not decoded bytes.
export const MAX_IMAGES = 10;
export const CONNECTION_ID = /^[A-Z2-9]{4}-[A-Z2-9]{4}$/;
export const isConnectionId = value => typeof value === "string" && CONNECTION_ID.test(value);
export const isRecord = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
export const isId = (value) => typeof value === "string" && value.length > 0 && value.length <= 128;
export const isText = (value, max = 2048) => typeof value === "string" && value.length <= max;
export const isDeadline = (value) => Number.isSafeInteger(value) && value > 0;

export function parseMessage(data) {
	const message = JSON.parse(typeof data === "string" ? data : data.toString("utf8"));
	if (!isRecord(message) || !isText(message.type, 40)) throw new Error("Invalid message envelope");
	return message;
}

export function encodeMessage(message, limit = MAX_MESSAGE_BYTES) {
	const encoded = JSON.stringify(message);
	if (Buffer.byteLength(encoded, "utf8") > limit) throw new Error(`Figpie message exceeds ${limit} bytes; return less data or fewer screenshots`);
	return encoded;
}

export function validTarget(message) {
	return ["fileKey", "fileName", "pageName", "editorType"].every((key) => message[key] === undefined || isText(message[key])) &&
		(message.busyId === null || isId(message.busyId));
}

export function validResult(message) {
	if (!isId(message.id)) return false;
	if (message.type === "error") return isText(message.message, 8192) && (message.stack === undefined || isText(message.stack, 32768));
	if (message.type !== "result" || !isText(message.text, MAX_MESSAGE_BYTES) || !Array.isArray(message.images) || message.images.length > MAX_IMAGES) return false;
	let bytes = 0;
	return message.images.every((image) => {
		if (!isRecord(image) || !["image/png", "image/jpeg", "image/webp"].includes(image.mimeType) || typeof image.data !== "string" || (image.name !== undefined && !isText(image.name))) return false;
		bytes += image.data.length;
		return bytes <= MAX_IMAGE_BYTES && /^[A-Za-z0-9+/]*={0,2}$/.test(image.data);
	});
}

export function validatePortEnvironment(env = process.env) {
	for (const key of ["PI_FIGPIE_PORT", "PI_FIGMA_USE_PORT"]) {
		if (env[key] && env[key] !== String(PORT)) throw new Error(`${key} is no longer supported. Figpie and its Figma manifest use fixed port ${PORT}; remove this override.`);
	}
}
