figma.showUI(__html__, { width: 300, height: 96, themeColors: true });

const NODE_TYPES = new Set([
	"DOCUMENT", "PAGE", "SLICE", "FRAME", "GROUP", "SECTION", "COMPONENT_SET", "COMPONENT",
	"INSTANCE", "BOOLEAN_OPERATION", "VECTOR", "STAR", "LINE", "ELLIPSE", "POLYGON", "RECTANGLE",
	"TEXT", "TEXT_PATH", "STAMP", "HIGHLIGHT", "WASHI_TAPE", "SHAPE_WITH_TEXT", "CODE_BLOCK",
	"CONNECTOR", "WIDGET", "EMBED", "LINK_UNFURL", "MEDIA", "STICKY", "TABLE", "TABLE_CELL",
	"SLIDE", "SLIDE_ROW", "SLIDE_GRID", "INTERACTIVE_SLIDE_ELEMENT", "TRANSFORM_GROUP",
]);

function serialize(value) {
	if (value === undefined) return "undefined";
	if (typeof value === "string") return value;
	try {
		const seen = new Set();
		return JSON.stringify(
			value,
			(_key, item) => {
				if (typeof item === "bigint") return `${item}n`;
				if (typeof item === "object" && item !== null) {
					if (seen.has(item)) return "[Circular]";
					seen.add(item);
				}
				return item;
			},
			2,
		);
	} catch (_error) {
		return String(value);
	}
}

function bytesToBase64(bytes) {
	const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	let output = "";
	for (let index = 0; index < bytes.length; index += 3) {
		const first = bytes[index];
		const second = index + 1 < bytes.length ? bytes[index + 1] : 0;
		const third = index + 2 < bytes.length ? bytes[index + 2] : 0;
		const value = (first << 16) | (second << 8) | third;
		output += alphabet[(value >> 18) & 63];
		output += alphabet[(value >> 12) & 63];
		output += index + 1 < bytes.length ? alphabet[(value >> 6) & 63] : "=";
		output += index + 2 < bytes.length ? alphabet[value & 63] : "=";
	}
	return output;
}

function splitTopLevel(input, delimiter) {
	const parts = [];
	let buffer = "";
	let squareDepth = 0;
	let roundDepth = 0;
	let quote;
	for (let index = 0; index < input.length; index += 1) {
		const character = input[index];
		if (quote) {
			buffer += character;
			if (character === quote && input[index - 1] !== "\\") quote = undefined;
			continue;
		}
		if (character === '"' || character === "'") {
			quote = character;
			buffer += character;
			continue;
		}
		if (character === "[") squareDepth += 1;
		if (character === "]") squareDepth -= 1;
		if (character === "(") roundDepth += 1;
		if (character === ")") roundDepth -= 1;
		if (character === delimiter && squareDepth === 0 && roundDepth === 0) {
			if (buffer.trim()) parts.push(buffer.trim());
			buffer = "";
		} else {
			buffer += character;
		}
	}
	if (buffer.trim()) parts.push(buffer.trim());
	return parts;
}

function parseComplexSelector(selector) {
	const parts = [];
	let buffer = "";
	let pendingCombinator = null;
	let squareDepth = 0;
	let roundDepth = 0;
	let quote;

	function pushBuffer() {
		const simple = buffer.trim();
		if (!simple) return false;
		parts.push({ simple, combinator: parts.length === 0 ? null : pendingCombinator || " " });
		buffer = "";
		pendingCombinator = null;
		return true;
	}

	for (let index = 0; index < selector.length; index += 1) {
		const character = selector[index];
		if (quote) {
			buffer += character;
			if (character === quote && selector[index - 1] !== "\\") quote = undefined;
			continue;
		}
		if (character === '"' || character === "'") {
			quote = character;
			buffer += character;
			continue;
		}
		if (character === "[") squareDepth += 1;
		if (character === "]") squareDepth -= 1;
		if (character === "(") roundDepth += 1;
		if (character === ")") roundDepth -= 1;
		if (squareDepth === 0 && roundDepth === 0 && [">", "+", "~"].includes(character)) {
			pushBuffer();
			pendingCombinator = character;
			continue;
		}
		if (squareDepth === 0 && roundDepth === 0 && /\s/.test(character)) {
			const pushed = pushBuffer();
			let nextIndex = index + 1;
			while (nextIndex < selector.length && /\s/.test(selector[nextIndex])) nextIndex += 1;
			if (pushed && ![">", "+", "~"].includes(selector[nextIndex])) pendingCombinator = " ";
			index = nextIndex - 1;
			continue;
		}
		buffer += character;
	}
	pushBuffer();
	if (parts.length === 0) throw new Error(`Invalid selector: ${selector}`);
	return parts;
}

function parseLiteral(raw) {
	const value = raw.trim();
	if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
		return value.slice(1, -1);
	}
	if (value === "true") return true;
	if (value === "false") return false;
	if (value === "null") return null;
	if (value !== "" && Number.isFinite(Number(value))) return Number(value);
	return value;
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
				continue;
			}
			try {
				next.push(current[segment]);
			} catch (_error) {}
		}
		values = next;
	}
	return values;
}

function comparableValue(value) {
	if (value && typeof value === "object" && typeof value.id === "string") return value.id;
	return value;
}

function matchAttribute(node, expression) {
	const match = expression.match(/^\s*([^\s~|^$*!=]+)\s*(\*=|\^=|\$=|=)\s*(.*?)\s*$/);
	if (!match) return readPathValues(node, expression.trim()).some((value) => value !== undefined);
	const [, path, operator, rawExpected] = match;
	const expected = parseLiteral(rawExpected);
	return readPathValues(node, path).some((rawActual) => {
		const actual = comparableValue(rawActual);
		if (operator === "=") return actual === expected || String(actual) === String(expected);
		const actualText = String(actual);
		const expectedText = String(expected);
		if (operator === "*=") return actualText.includes(expectedText);
		if (operator === "^=") return actualText.startsWith(expectedText);
		if (operator === "$=") return actualText.endsWith(expectedText);
		return false;
	});
}

function previousSiblings(node) {
	const parent = node.parent;
	if (!parent || !("children" in parent)) return [];
	const index = parent.children.indexOf(node);
	return index > 0 ? parent.children.slice(0, index) : [];
}

function matchesSimple(node, selector) {
	let index = 0;
	const typeMatch = selector.slice(index).match(/^(\*|[A-Za-z_][A-Za-z0-9_]*)/);
	if (typeMatch) {
		index += typeMatch[0].length;
		if (typeMatch[0] !== "*" && node.type.toUpperCase() !== typeMatch[0].toUpperCase()) return false;
	}

	while (index < selector.length) {
		const character = selector[index];
		if (character === "#") {
			index += 1;
			const idMatch = selector.slice(index).match(/^[^\[\]:\s]+(?::[^\[\]:\s]+)?/);
			if (!idMatch || node.id !== idMatch[0].replace(/-/g, ":")) return false;
			index += idMatch ? idMatch[0].length : 0;
			continue;
		}
		if (character === "[") {
			let end = index + 1;
			let quote;
			for (; end < selector.length; end += 1) {
				const current = selector[end];
				if (quote) {
					if (current === quote && selector[end - 1] !== "\\") quote = undefined;
				} else if (current === '"' || current === "'") quote = current;
				else if (current === "]") break;
			}
			if (end >= selector.length) throw new Error(`Unclosed attribute selector: ${selector}`);
			if (!matchAttribute(node, selector.slice(index + 1, end))) return false;
			index = end + 1;
			continue;
		}
		if (character === ":") {
			const nameMatch = selector.slice(index + 1).match(/^[A-Za-z-]+/);
			if (!nameMatch) throw new Error(`Invalid pseudo-class: ${selector.slice(index)}`);
			const name = nameMatch[0].toLowerCase();
			index += name.length + 1;
			let argument;
			if (selector[index] === "(") {
				let depth = 1;
				let end = index + 1;
				for (; end < selector.length && depth > 0; end += 1) {
					if (selector[end] === "(") depth += 1;
					if (selector[end] === ")") depth -= 1;
				}
				if (depth !== 0) throw new Error(`Unclosed pseudo-class: ${selector}`);
				argument = selector.slice(index + 1, end - 1).trim();
				index = end;
			}
			const siblings = node.parent && "children" in node.parent ? node.parent.children : [];
			const siblingIndex = siblings.indexOf(node);
			if (name === "first-child" && siblingIndex !== 0) return false;
			else if (name === "last-child" && siblingIndex !== siblings.length - 1) return false;
			else if (name === "nth-child" && siblingIndex !== Number(argument) - 1) return false;
			else if (name === "not" && matchesSelector(node, argument)) return false;
			else if (["is", "where"].includes(name) && !matchesSelector(node, argument)) return false;
			else if (!["first-child", "last-child", "nth-child", "not", "is", "where"].includes(name)) {
				throw new Error(`Unsupported pseudo-class: ${name}`);
			}
			continue;
		}
		const bareId = selector.slice(index).trim();
		if (bareId && /^[0-9]+[:-][0-9]+$/.test(bareId)) return node.id === bareId.replace("-", ":");
		throw new Error(`Unsupported selector syntax near: ${selector.slice(index)}`);
	}
	return true;
}

function matchesComplex(node, parts, boundary) {
	function matchAt(candidate, partIndex) {
		if (!candidate || !matchesSimple(candidate, parts[partIndex].simple)) return false;
		if (partIndex === 0) return true;
		const combinator = parts[partIndex].combinator;
		if (combinator === ">") return matchAt(candidate.parent, partIndex - 1);
		if (combinator === "+") {
			const siblings = previousSiblings(candidate);
			return siblings.length > 0 && matchAt(siblings[siblings.length - 1], partIndex - 1);
		}
		if (combinator === "~") {
			return previousSiblings(candidate).some((sibling) => matchAt(sibling, partIndex - 1));
		}
		let ancestor = candidate.parent;
		while (ancestor) {
			if (matchAt(ancestor, partIndex - 1)) return true;
			if (ancestor === boundary) break;
			ancestor = ancestor.parent;
		}
		return false;
	}
	return matchAt(node, parts.length - 1);
}

function matchesSelector(node, selector, boundary) {
	return splitTopLevel(selector, ",").some((item) => matchesComplex(node, parseComplexSelector(item), boundary));
}

function descendants(root) {
	const result = [];
	function walk(node) {
		if (!("children" in node)) return;
		for (const child of node.children) {
			result.push(child);
			walk(child);
		}
	}
	walk(root);
	return result;
}

function sendTarget() {
	figma.ui.postMessage({
		type: "target",
		fileKey: figma.fileKey,
		fileName: figma.root.name,
		pageName: figma.currentPage.name,
		editorType: figma.editorType,
	});
}

figma.on("currentpagechange", sendTarget);

figma.ui.onmessage = async (message) => {
	if (message.type === "ready") {
		sendTarget();
		return;
	}
	if (message.type !== "execute") return;

	const screenshots = [];
	const nativeToProxy = new WeakMap();
	const proxyToNative = new WeakMap();

	function isNode(value) {
		if (!value || typeof value !== "object") return false;
		try {
			return typeof value.id === "string" && NODE_TYPES.has(value.type);
		} catch (_error) {
			return false;
		}
	}

	function unwrap(value) {
		if (proxyToNative.has(value)) return proxyToNative.get(value);
		if (Array.isArray(value)) return value.map(unwrap);
		if (typeof value === "function") {
			return (...args) => value(...args.map(wrap));
		}
		return value;
	}

	function wrap(value) {
		if (isNode(value)) return wrapNode(value);
		if (Array.isArray(value)) return value.map(wrap);
		if (value instanceof Promise) return value.then(wrap);
		return value;
	}

	function setNodeProperties(node, properties) {
		const native = unwrap(node);
		const props = { ...properties };
		if (Object.prototype.hasOwnProperty.call(props, "layoutMode")) {
			native.layoutMode = props.layoutMode;
			delete props.layoutMode;
		}
		if (Object.prototype.hasOwnProperty.call(props, "width") || Object.prototype.hasOwnProperty.call(props, "height")) {
			const width = Object.prototype.hasOwnProperty.call(props, "width") ? props.width : native.width;
			const height = Object.prototype.hasOwnProperty.call(props, "height") ? props.height : native.height;
			if (typeof native.resize !== "function") throw new Error(`${native.type} does not support width or height`);
			native.resize(width, height);
			delete props.width;
			delete props.height;
		}
		for (const [key, rawValue] of Object.entries(props)) native[key] = unwrap(rawValue);
		return wrapNode(native);
	}

	function createQueryResult(nativeNodes) {
		const nodes = [];
		const seen = new Set();
		for (const node of nativeNodes) {
			const native = unwrap(node);
			if (!native || seen.has(native.id)) continue;
			seen.add(native.id);
			nodes.push(native);
		}
		const result = {
			get length() { return nodes.length; },
			first() { return nodes.length ? wrapNode(nodes[0]) : null; },
			last() { return nodes.length ? wrapNode(nodes[nodes.length - 1]) : null; },
			toArray() { return nodes.map(wrapNode); },
			each(callback) { nodes.forEach((node, index) => callback(wrapNode(node), index)); return result; },
			map(callback) { return nodes.map((node, index) => callback(wrapNode(node), index)); },
			filter(callback) { return createQueryResult(nodes.filter((node, index) => callback(wrapNode(node), index))); },
			values(keys) {
				return nodes.map((node) => Object.fromEntries(keys.map((key) => [key, readPathValues(node, key)[0]])));
			},
			set(properties) { nodes.forEach((node) => setNodeProperties(node, properties)); return result; },
			query(selector) {
				return createQueryResult(nodes.flatMap((node) => queryNodes(node, selector)));
			},
			[Symbol.iterator]() { return nodes.map(wrapNode)[Symbol.iterator](); },
		};
		return result;
	}

	function queryNodes(root, selector) {
		const nativeRoot = unwrap(root);
		return descendants(nativeRoot).filter((node) => matchesSelector(node, selector, nativeRoot));
	}

	async function screenshotNode(node, options = {}) {
		const native = unwrap(node);
		if (typeof native.exportAsync !== "function") throw new Error(`${native.type} cannot be exported`);
		const maxDimension = Math.max(native.width || 1, native.height || 1);
		const scale = options.scale == null ? Math.min(0.5, 1024 / maxDimension) : options.scale;
		if (!Number.isFinite(scale) || scale <= 0) throw new Error("Screenshot scale must be greater than zero");
		const bytes = await native.exportAsync({
			format: "PNG",
			contentsOnly: options.contentsOnly !== false,
			constraint: { type: "SCALE", value: scale },
		});
		screenshots.push({
			data: bytesToBase64(bytes),
			mimeType: "image/png",
			name: `${native.name || native.type} (${Math.round(native.width || 0)}x${Math.round(native.height || 0)} at ${Math.round(native.x || 0)},${Math.round(native.y || 0)}).png`,
		});
	}

	function wrapNode(node) {
		if (nativeToProxy.has(node)) return nativeToProxy.get(node);
		const proxy = new Proxy({}, {
			get(_facade, property) {
				if (property === "set") return (properties) => setNodeProperties(node, properties);
				if (property === "query") return (selector) => createQueryResult(queryNodes(node, selector));
				if (property === "matches") return (selector) => matchesSelector(node, selector);
				if (property === "screenshot") return (options) => screenshotNode(node, options);
				const value = Reflect.get(node, property, node);
				if (typeof value === "function") {
					return (...args) => wrap(value.apply(node, args.map(unwrap)));
				}
				return wrap(value);
			},
			set(_facade, property, value) {
				return Reflect.set(node, property, unwrap(value), node);
			},
			has(_facade, property) {
				return ["set", "query", "matches", "screenshot"].includes(property) || property in node;
			},
			getPrototypeOf() {
				return Reflect.getPrototypeOf(node);
			},
		});
		nativeToProxy.set(node, proxy);
		proxyToNative.set(proxy, node);
		return proxy;
	}

	function createAutoLayout(directionOrProperties = "HORIZONTAL", maybeProperties = {}) {
		const direction = typeof directionOrProperties === "string" ? directionOrProperties : "HORIZONTAL";
		const properties = typeof directionOrProperties === "object" ? directionOrProperties : maybeProperties;
		if (!["HORIZONTAL", "VERTICAL"].includes(direction)) throw new Error("Auto-layout direction must be HORIZONTAL or VERTICAL");
		const frame = figma.createFrame();
		frame.layoutMode = direction;
		frame.primaryAxisSizingMode = "AUTO";
		frame.counterAxisSizingMode = "AUTO";
		return setNodeProperties(frame, properties || {});
	}

	const enhancedFigma = new Proxy({}, {
		get(_facade, property) {
			if (property === "createAutoLayout") return createAutoLayout;
			const value = Reflect.get(figma, property, figma);
			if (typeof value === "function") return (...args) => wrap(value.apply(figma, args.map(unwrap)));
			return wrap(value);
		},
		set(_facade, property, value) {
			return Reflect.set(figma, property, unwrap(value), figma);
		},
		has(_facade, property) {
			return property === "createAutoLayout" || property in figma;
		},
		getPrototypeOf() {
			return Reflect.getPrototypeOf(figma);
		},
	});

	try {
		const run = new Function(
			"figma",
			`return (async () => {\n${message.code}\n})();`,
		);
		const result = await run(enhancedFigma);
		figma.ui.postMessage({
			type: "result",
			id: message.id,
			text: serialize(result),
			images: screenshots,
		});
		sendTarget();
	} catch (error) {
		figma.ui.postMessage({
			type: "error",
			id: message.id,
			message: error instanceof Error ? error.message : String(error),
			stack: error instanceof Error ? error.stack : undefined,
		});
	}
};

sendTarget();
