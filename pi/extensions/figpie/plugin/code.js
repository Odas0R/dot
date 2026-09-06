figma.showUI(__html__, { width: 340, height: 240, themeColors: true });

// Wire constants are checked against protocol.js by the test suite.
const PROTOCOL_VERSION = 2;
const MAX_MESSAGE_BYTES = 16 * 1024 * 1024;
const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const MAX_IMAGES = 10;
const NODE_TYPES = new Set([
	"DOCUMENT", "PAGE", "SLICE", "FRAME", "GROUP", "SECTION", "COMPONENT_SET", "COMPONENT",
	"INSTANCE", "BOOLEAN_OPERATION", "VECTOR", "STAR", "LINE", "ELLIPSE", "POLYGON", "RECTANGLE",
	"TEXT", "TEXT_PATH", "STAMP", "HIGHLIGHT", "WASHI_TAPE", "SHAPE_WITH_TEXT", "CODE_BLOCK",
	"CONNECTOR", "WIDGET", "EMBED", "LINK_UNFURL", "MEDIA", "STICKY", "TABLE", "TABLE_CELL",
	"SLIDE", "SLIDE_ROW", "SLIDE_GRID", "INTERACTIVE_SLIDE_ELEMENT", "TRANSFORM_GROUP",
]);
const isRecord = value => value !== null && typeof value === "object" && !Array.isArray(value);
const isId = value => typeof value === "string" && value.length > 0 && value.length <= 128;
let activeRun = null;

function isNode(value) {
	if (!isRecord(value)) return false;
	try { return typeof value.id === "string" && NODE_TYPES.has(value.type); } catch { return false; }
}
function serialize(value) {
	if (value === undefined) return "undefined";
	if (typeof value === "string") return value;
	const ancestors = [];
	return JSON.stringify(value, function (_key, item) {
		if (typeof item === "bigint") return `${item}n`;
		if (isNode(item)) return { id: item.id, type: item.type, name: item.name };
		if (typeof item !== "object" || item === null) return item;
		while (ancestors.length && ancestors[ancestors.length - 1] !== this) ancestors.pop();
		if (ancestors.includes(item)) return "[Circular]";
		ancestors.push(item);
		return item;
	}) ?? "undefined";
}
function utf8Length(text) {
	let bytes = 0;
	for (const character of text) {
		const point = character.codePointAt(0);
		bytes += point <= 0x7f ? 1 : point <= 0x7ff ? 2 : point <= 0xffff ? 3 : 4;
	}
	return bytes;
}
function bytesToBase64(bytes) {
	const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	const chunks = [];
	let output = "";
	for (let i = 0; i < bytes.length; i += 3) {
		const value = (bytes[i] << 16) | ((bytes[i + 1] || 0) << 8) | (bytes[i + 2] || 0);
		output += alphabet[(value >> 18) & 63] + alphabet[(value >> 12) & 63] + (i + 1 < bytes.length ? alphabet[(value >> 6) & 63] : "=") + (i + 2 < bytes.length ? alphabet[value & 63] : "=");
		if (output.length >= 8192) { chunks.push(output); output = ""; }
	}
	chunks.push(output);
	return chunks.join("");
}

// Parse the complete selector before evaluating any node, including empty subtrees.
function compileSelector(selector) {
	if (typeof selector !== "string" || !selector.trim() || selector.length > 8192) throw new Error("Selector must be a non-empty string of at most 8192 characters");
	let index = 0;
	function error() { throw new Error(`Invalid selector near: ${selector.slice(index) || "<end>"}`); }
	function whitespace() { const start = index; while (/\s/.test(selector[index] || "") && index < selector.length) index++; return index > start; }
	function enclosed(open, close) {
		if (selector[index++] !== open) error();
		const start = index;
		let depth = 1;
		let quote;
		let escaped = false;
		for (; index < selector.length; index++) {
			const char = selector[index];
			if (escaped) { escaped = false; continue; }
			if (quote) {
				if (char === "\\") escaped = true;
				else if (char === quote) quote = undefined;
				continue;
			}
			if (char === '"' || char === "'") { quote = char; continue; }
			if (char === open) depth++;
			if (char === close) {
				depth--;
				if (depth === 0) { const content = selector.slice(start, index); index++; return content; }
			}
		}
		error();
	}
	function simple() {
		const predicates = [];
		const type = /^I?\d+[:-]\d+/.test(selector.slice(index)) ? null : selector.slice(index).match(/^(\*|[A-Za-z_][A-Za-z0-9_]*)/);
		if (type) { index += type[0].length; predicates.push(node => type[0] === "*" || node.type.toUpperCase() === type[0].toUpperCase()); }
		while (index < selector.length && !/[\s,>+~]/.test(selector[index])) {
			const char = selector[index];
			if (char === "#" || (!predicates.length && /[0-9I]/.test(char))) {
				if (char === "#") index++;
				// Figma IDs can include instance descendant segments separated by semicolons.
				const id = selector.slice(index).match(/^I?\d+[:-]\d+(?:;\d+[:-]\d+)*/);
				if (!id) error();
				index += id[0].length;
				predicates.push(node => node.id === id[0].replace(/-/g, ":"));
			} else if (char === "[") {
				const expression = enclosed("[", "]");
				const match = expression.match(/^\s*([A-Za-z_$][\w$]*(?:\.(?:[\w$]+|\*))*)\s*(?:(\*=|\^=|\$=|=)\s*(.+?))?\s*$/);
				if (!match) error();
				const [, path, operator, raw] = match;
				if (path.split(".").includes("mainComponent")) throw new Error("mainComponent selectors are unavailable with dynamic pages; use getMainComponentAsync() on discovered instances");
				const expected = operator ? parseLiteral(raw) : undefined;
				predicates.push(node => readPathValues(node, path).some(value => {
					if (!operator) return value !== undefined;
					if (value === undefined) return false;
					const actual = value && typeof value === "object" && typeof value.id === "string" ? value.id : value;
					if (operator === "=") return actual === expected || String(actual) === String(expected);
					if (operator === "*=") return String(actual).includes(String(expected));
					if (operator === "^=") return String(actual).startsWith(String(expected));
					return String(actual).endsWith(String(expected));
				}));
			} else if (char === ":") {
				index++;
				const match = selector.slice(index).match(/^[a-zA-Z-]+/);
				if (!match) error();
				const name = match[0].toLowerCase();
				index += match[0].length;
				const argument = selector[index] === "(" ? enclosed("(", ")") : undefined;
				if (["not", "is", "where"].includes(name)) {
					const nested = compileSelector(argument);
					predicates.push((node, boundary) => name === "not" ? !nested(node, boundary) : nested(node, boundary));
				} else if (["first-child", "last-child", "nth-child"].includes(name)) {
					if (name === "nth-child" ? !/^[1-9]\d*$/.test(argument || "") : argument !== undefined) error();
					predicates.push(node => {
						const siblings = node.parent && "children" in node.parent ? node.parent.children : [];
						const position = siblings.indexOf(node);
						return position >= 0 && position === (name === "first-child" ? 0 : name === "last-child" ? siblings.length - 1 : Number(argument) - 1);
					});
				} else throw new Error(`Unsupported pseudo-class: ${name}`);
			} else error();
		}
		if (!predicates.length) error();
		return (node, boundary) => predicates.every(predicate => predicate(node, boundary));
	}
	const groups = [];
	whitespace();
	while (index < selector.length) {
		const parts = [{ match: simple(), combinator: null }];
		while (index < selector.length) {
			const spaced = whitespace();
			if (index === selector.length || selector[index] === ",") break;
			let combinator = " ";
			if (/[>+~]/.test(selector[index])) { combinator = selector[index++]; whitespace(); }
			else if (!spaced) error();
			parts.push({ match: simple(), combinator });
		}
		groups.push(parts);
		if (index === selector.length) break;
		if (selector[index++] !== ",") error();
		whitespace();
		if (index === selector.length) error();
	}
	return (node, boundary) => groups.some(parts => {
		function at(candidate, part) {
			if (!candidate || !parts[part].match(candidate, boundary)) return false;
			if (!part) return true;
			if (candidate === boundary) return false;
			const combinator = parts[part].combinator;
			if (combinator === ">") return at(candidate.parent, part - 1);
			if (combinator === "+" || combinator === "~") {
				const siblings = candidate.parent && "children" in candidate.parent ? candidate.parent.children : [];
				const position = siblings.indexOf(candidate);
				return combinator === "+" ? at(siblings[position - 1], part - 1) : siblings.slice(0, Math.max(0, position)).some(sibling => at(sibling, part - 1));
			}
			for (let ancestor = candidate.parent; ancestor; ancestor = ancestor.parent) {
				if (at(ancestor, part - 1)) return true;
				if (ancestor === boundary) break;
			}
			return false;
		}
		return at(node, parts.length - 1);
	});
}
function parseLiteral(raw) {
	const value = raw.trim();
	if (value[0] === '"' || value[0] === "'") {
		if (value[value.length - 1] !== value[0]) throw new Error("Unclosed selector string");
		let decoded = "";
		for (let index = 1; index < value.length - 1; index++) {
			if (value[index] === value[0]) throw new Error("Unexpected quote in selector value");
			if (value[index] === "\\") {
				index++;
				if (index >= value.length - 1) throw new Error("Unclosed selector escape");
			}
			decoded += value[index];
		}
		return decoded;
	}
	if (/[\s\[\]'"()]/.test(value)) throw new Error("Quote selector attribute values containing spaces or punctuation");
	if (value === "true") return true;
	if (value === "false") return false;
	if (value === "null") return null;
	return value !== "" && Number.isFinite(Number(value)) ? Number(value) : value;
}
function readPathValues(value, path) {
	let values = [value];
	for (const segment of path.split(".")) {
		const next = [];
		for (const current of values) {
			if (current == null) continue;
			if (segment === "*") {
				if (Array.isArray(current)) next.push(...current);
				else if (typeof current === "object") next.push(...Object.values(current));
			} else next.push(current[segment]); // Getter errors must not silently hide matching nodes.
		}
		values = next;
	}
	return values;
}
function descendants(root) {
	const result = [];
	const stack = "children" in root ? [...root.children].reverse() : [];
	while (stack.length) {
		const node = stack.pop();
		result.push(node);
		if ("children" in node) for (let i = node.children.length - 1; i >= 0; i--) stack.push(node.children[i]);
	}
	return result;
}
function sendTarget(requestId) {
	figma.ui.postMessage({ type: "target", version: PROTOCOL_VERSION, requestId: isId(requestId) ? requestId : undefined, fileKey: figma.fileKey, fileName: figma.root.name, pageName: figma.currentPage.name, editorType: figma.editorType, busyId: activeRun?.id || null });
}
function postError(id, error) {
	figma.ui.postMessage({ type: "error", id, message: String(error?.message || error).slice(0, 8192), stack: typeof error?.stack === "string" ? error.stack.slice(0, 32768) : undefined });
}
figma.on("currentpagechange", sendTarget);

figma.ui.onmessage = async (message) => {
	if (!isRecord(message)) return;
	if (message.type === "ready") { sendTarget(message.requestId); return; }
	if (message.type === "load-pairing" || message.type === "save-pairing") {
		try {
			if (message.type === "load-pairing") {
				const token = await figma.clientStorage.getAsync("figpie-pairing-v2");
				figma.ui.postMessage({ type: "pairing", token: typeof token === "string" ? token : "" });
			} else if (typeof message.token === "string" && /^(?:[a-f0-9]{64})?$/.test(message.token)) {
				await figma.clientStorage.setAsync("figpie-pairing-v2", message.token);
			}
		} catch {
			figma.ui.postMessage({ type: "pairing-error", message: "Figma could not load/save pairing. Pair again; storage may be unavailable." });
		}
		return;
	}
	if (message.type === "transport-lost" || (message.type === "cancel" && message.id === activeRun?.id)) {
		if (activeRun) activeRun.cancelled = true;
		sendTarget();
		return;
	}
	if (message.type !== "execute" || !isId(message.id) || typeof message.code !== "string" || !Number.isSafeInteger(message.deadline)) return;
	if (activeRun) { postError(message.id, "Figma is still running a previous request. Restart the plugin if it stays busy; inspect changes before retrying."); return; }
	if (message.deadline <= Date.now()) { postError(message.id, "Request expired before execution; it was not started."); return; }
	const run = { id: message.id, deadline: message.deadline, cancelled: false, finished: false };
	activeRun = run;
	sendTarget();
	const screenshots = [];
	let imageBytes = 0;
	const nativeToProxy = new WeakMap();
	const proxyToNative = new WeakMap();
	const callbacks = new WeakMap();
	const subscriptions = [];
	function guard() {
		if (run.finished || run.cancelled || Date.now() >= run.deadline) throw new Error("Execution cancelled or expired. Changes may remain; inspect before retrying.");
	}
	function unwrap(value, seen = new WeakMap()) {
		if (proxyToNative.has(value)) return proxyToNative.get(value);
		if (typeof value === "function") {
			if (!callbacks.has(value)) callbacks.set(value, function (...args) { guard(); return unwrap(value.apply(this, args.map(wrap))); });
			return callbacks.get(value);
		}
		if (!value || typeof value !== "object" || ArrayBuffer.isView(value)) return value;
		if (seen.has(value)) return seen.get(value);
		if (Array.isArray(value) || Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null) {
			const copy = Array.isArray(value) ? [] : {};
			seen.set(value, copy);
			for (const key of Object.keys(value)) Object.defineProperty(copy, key, { value: unwrap(value[key], seen), enumerable: true, writable: true, configurable: true });
			return copy;
		}
		return value;
	}
	function wrap(value) {
		if (value instanceof Promise) return value.then(wrap);
		if (Array.isArray(value)) return value.map(wrap);
		if (!value || typeof value !== "object" || ArrayBuffer.isView(value) || value instanceof ArrayBuffer) return value;
		return wrapObject(value);
	}
	function setNodeProperties(node, properties) {
		guard();
		if (!isRecord(properties)) throw new Error("node.set() requires a properties object");
		const props = { ...properties };
		if (Object.prototype.hasOwnProperty.call(props, "layoutMode")) { node.layoutMode = props.layoutMode; delete props.layoutMode; }
		if (Object.prototype.hasOwnProperty.call(props, "width") || Object.prototype.hasOwnProperty.call(props, "height")) {
			if (typeof node.resize !== "function") throw new Error(`${node.type} does not support width or height`);
			node.resize(props.width === undefined ? node.width : props.width, props.height === undefined ? node.height : props.height);
			delete props.width;
			delete props.height;
		}
		for (const [key, value] of Object.entries(props)) node[key] = unwrap(value);
		return wrap(node);
	}
	function queryNodes(root, selector) {
		guard();
		const match = compileSelector(selector);
		return descendants(root).filter(node => match(node, root));
	}
	function createQueryResult(nativeNodes) {
		const nodes = [...new Map(nativeNodes.map(node => [node.id, node])).values()];
		const result = {
			get length() { return nodes.length; },
			first() { return nodes.length ? wrap(nodes[0]) : null; },
			last() { return nodes.length ? wrap(nodes[nodes.length - 1]) : null; },
			toArray() { return nodes.map(wrap); },
			each(callback) { nodes.forEach((node, index) => callback(wrap(node), index)); return result; },
			map(callback) { return nodes.map((node, index) => callback(wrap(node), index)); },
			filter(callback) { return createQueryResult(nodes.filter((node, index) => callback(wrap(node), index))); },
			values(keys) { guard(); return nodes.map(node => Object.fromEntries(keys.map(key => [key, readPathValues(node, key)[0]]))); },
			set(properties) { nodes.forEach(node => setNodeProperties(node, properties)); return result; },
			query(selector) { compileSelector(selector); return createQueryResult(nodes.flatMap(node => queryNodes(node, selector))); },
			[Symbol.iterator]() { return nodes.map(wrap)[Symbol.iterator](); },
		};
		return result;
	}
	async function screenshotNode(node, options = {}) {
		guard();
		if (typeof node.exportAsync !== "function") throw new Error(`${node.type} cannot be exported`);
		const scale = options.scale == null ? Math.min(0.5, 1024 / Math.max(node.width || 1, node.height || 1)) : options.scale;
		if (!Number.isFinite(scale) || scale <= 0) throw new Error("Screenshot scale must be greater than zero");
		const bytes = await node.exportAsync({ format: "PNG", contentsOnly: options.contentsOnly !== false, constraint: { type: "SCALE", value: scale } });
		guard();
		const size = Math.ceil(bytes.length / 3) * 4;
		if (screenshots.length >= MAX_IMAGES || imageBytes + size > MAX_IMAGE_BYTES) throw new Error("Screenshot budget exceeded (10 images / 8 MiB base64). Use fewer screenshots or a smaller scale; changes may remain.");
		imageBytes += size;
		screenshots.push({ data: bytesToBase64(bytes), mimeType: "image/png", name: `${String(node.name || node.type).slice(0, 1800)} (${Math.round(node.width || 0)}x${Math.round(node.height || 0)}).png` });
	}
	function createAutoLayout(directionOrProperties = "HORIZONTAL", maybeProperties = {}) {
		guard();
		const direction = typeof directionOrProperties === "string" ? directionOrProperties : "HORIZONTAL";
		const properties = typeof directionOrProperties === "object" ? directionOrProperties : maybeProperties;
		if (!["HORIZONTAL", "VERTICAL"].includes(direction)) throw new Error("Auto-layout direction must be HORIZONTAL or VERTICAL");
		const frame = figma.createFrame();
		frame.layoutMode = direction;
		frame.primaryAxisSizingMode = "AUTO";
		frame.counterAxisSizingMode = "AUTO";
		return setNodeProperties(frame, properties || {});
	}
	function wrapObject(object) {
		if (nativeToProxy.has(object)) return nativeToProxy.get(object);
		const node = isNode(object);
		const methodCache = new Map();
		const helpers = node ? { set: props => setNodeProperties(object, props), query: selector => createQueryResult(queryNodes(object, selector)), matches: selector => compileSelector(selector)(object), screenshot: options => screenshotNode(object, options), toJSON: () => ({ id: object.id, type: object.type, name: object.name }) } : object === figma ? { createAutoLayout } : {};
		const proxy = new Proxy({}, {
			get(_facade, property) {
				guard();
				if (Object.prototype.hasOwnProperty.call(helpers, property)) return helpers[property];
				const value = Reflect.get(object, property, object);
				if (typeof value !== "function") return wrap(value);
				if (!methodCache.has(property)) methodCache.set(property, (...args) => {
					guard();
					if (object === figma && ["closePlugin", "showUI", "triggerUndo"].includes(property)) throw new Error(`${property} is reserved by Figpie; return data instead`);
					const nativeArgs = args.map(arg => unwrap(arg));
					const result = value.apply(object, nativeArgs);
					if (["on", "once"].includes(property) && typeof object.off === "function" && typeof nativeArgs[1] === "function") subscriptions.push([object, nativeArgs[0], nativeArgs[1]]);
					return wrap(result);
				});
				return methodCache.get(property);
			},
			set(_facade, property, value) { guard(); if (object === figma.ui) throw new Error("Figpie owns the plugin UI"); return Reflect.set(object, property, unwrap(value), object); },
			has(_facade, property) { return Object.prototype.hasOwnProperty.call(helpers, property) || property in object; },
			ownKeys() { return Reflect.ownKeys(object); },
			getOwnPropertyDescriptor(_facade, property) { const descriptor = Reflect.getOwnPropertyDescriptor(object, property); return descriptor ? { configurable: true, enumerable: descriptor.enumerable, writable: true, value: wrap(Reflect.get(object, property, object)) } : undefined; },
			getPrototypeOf() { return Reflect.getPrototypeOf(object); },
		});
		nativeToProxy.set(object, proxy);
		proxyToNative.set(proxy, object);
		return proxy;
	}
	try {
		const execute = new Function("figma", `return (async () => {\n${message.code}\n})();`);
		const result = await execute(wrapObject(figma));
		guard();
		const response = { type: "result", id: message.id, text: serialize(result), images: screenshots };
		if (utf8Length(JSON.stringify(response)) > MAX_MESSAGE_BYTES - 1024) throw new Error("Result exceeds the 16 MiB message budget. Return less data or fewer screenshots; changes may remain.");
		figma.ui.postMessage(response);
	} catch (error) { postError(message.id, error); }
	finally {
		for (const [object, event, callback] of subscriptions) { try { object.off(event, callback); } catch {} }
		// Separate calls in this long-lived plugin's undo history, including partial failures.
		try { figma.commitUndo(); } catch {}
		run.finished = true;
		activeRun = null;
		sendTarget();
	}
};
sendTarget();
